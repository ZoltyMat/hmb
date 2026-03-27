/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:money2/money2.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:strings/strings.dart';

import '../entity/customer.dart';
import '../entity/job.dart';
import '../entity/job_status.dart';
import '../entity/task.dart';
import '../services/job_service.dart';
import '../util/dart/exceptions.dart';
import 'dao.dart';
import 'dao_invoice.dart';
import 'dao_quote.dart';
import 'dao_task.dart';
import 'dao_todo.dart';

enum JobOrder {
  active('Most Recently Accessed'),
  created('Oldest Jobs first'),
  recent('Newest Jobs First');

  const JobOrder(this.description);
  final String description;
}

class DaoJob extends Dao<Job> {
  static const tableName = 'job';

  DaoJob() : super(tableName);

  @override
  Future<int> delete(int id, [Transaction? transaction]) async {
    if (await isStockJobId(id, transaction: transaction)) {
      throw HMBException('The Stock job cannot be deleted.');
    }

    final db = withinTransaction(transaction);
    final invoiceCount = await DaoInvoice().count(
      where: 'job_id = ?',
      whereArgs: [id],
    );
    if (invoiceCount > 0) {
      throw HMBException(
        'Job cannot be deleted because it has related invoices.',
      );
    }

    await DaoTask().deleteByJob(id, transaction: transaction);
    await DaoQuote().deleteByJob(id, transaction: transaction);

    // Delete the job itself
    return db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Job fromMap(Map<String, dynamic> map) => Job.fromMap(map);

  @override
  Future<int> update(Job entity, [Transaction? transaction]) async {
    final existing = await getById(entity.id, transaction);
    final isRejectingJob =
        existing != null &&
        existing.status != entity.status &&
        entity.status == JobStatus.rejected;
    final isCompletingJob =
        existing != null &&
        existing.status != entity.status &&
        entity.status == JobStatus.completed;

    if (!isRejectingJob && !isCompletingJob) {
      return super.update(entity, transaction);
    }

    if (transaction != null) {
      if (isRejectingJob) {
        await DaoQuote().rejectByJob(entity.id, transaction: transaction);
      }
      if (isCompletingJob) {
        await DaoToDo().markDoneByJob(entity.id, transaction: transaction);
      }
      return super.update(entity, transaction);
    }

    return db.transaction((txn) async {
      if (isRejectingJob) {
        await DaoQuote().rejectByJob(entity.id, transaction: txn);
      }
      if (isCompletingJob) {
        await DaoToDo().markDoneByJob(entity.id, transaction: txn);
      }
      return super.update(entity, txn);
    });
  }

  /// getAll - sort by modified date descending
  @override
  Future<List<Job>> getAll({
    String? orderByClause,
    Transaction? transaction,
  }) async {
    final db = withinTransaction(transaction);
    return toList(
      await db.query(tableName, orderBy: 'is_stock DESC, modified_date DESC'),
    );
  }

  Future<Job?> getStockJob({Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    final rows = await db.query(
      tableName,
      where: 'is_stock = 1',
      limit: 1,
      orderBy: 'id ASC',
    );
    return getFirstOrNull(rows);
  }

  Future<bool> isStockJobId(int jobId, {Transaction? transaction}) async {
    final db = withinTransaction(transaction);
    final rows = await db.query(
      tableName,
      columns: ['id'],
      where: 'id = ? AND is_stock = 1',
      whereArgs: [jobId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Job?> getLastActiveJob() async {
    final db = withoutTransaction();
    final data = await db.query(
      tableName,
      where: 'last_active = ?',
      whereArgs: [1],
      orderBy: 'modified_date desc',
      limit: 1,
    );
    return getFirstOrNull(data);
  }

  /// Use [JobService.markActive] instead.
  @Deprecated('Use JobService().markActive() instead')
  Future<Job> markActive(int jobId) =>
      JobService(daoJob: this).markActive(jobId);

  /// Use [JobService.markLastActive] instead.
  @Deprecated('Use JobService().markLastActive() instead')
  Future<void> markLastActive(int jobId) =>
      JobService(daoJob: this).markLastActive(jobId);

  /// Use [JobService.markQuoting] instead.
  @Deprecated('Use JobService().markQuoting() instead')
  Future<Job> markQuoting(int jobId) =>
      JobService(daoJob: this).markQuoting(jobId);

  /// search for jobs given a user supplied filter string.
  Future<List<Job>> getByFilter(
    String? filter, {
    JobOrder order = JobOrder.active,
  }) async {
    final db = withoutTransaction();

    final args = <String>[];
    var whereClause = '';
    if (Strings.isNotBlank(filter)) {
      final likeArg = '''%$filter%''';
      whereClause = '''
where j.summary like ?
or j.description like ?
or coalesce(c.name, '') like ?''';

      args.addAll([likeArg, likeArg, likeArg]);
    }

    final String orderByColumn;
    var sort = 'desc';

    switch (order) {
      case JobOrder.active:
        orderByColumn = 'j.modified_date';
      case JobOrder.created:
        orderByColumn = 'j.created_date';
        sort = 'asc';
      case JobOrder.recent:
        orderByColumn = 'j.created_date';
        sort = 'desc';
    }

    return toList(
      await db.rawQuery('''
select j.*
from job j
left join customer c
  on c.id = j.customer_id
$whereClause
order by j.is_stock desc, $orderByColumn $sort
''', args),
    );
  }

  Future<Job?> getJobForTask(int? taskId) async {
    final db = withoutTransaction();

    if (taskId == null) {
      return null;
    }

    final data = await db.rawQuery(
      '''
select j.* 
from task t
join job j
  on t.job_id = j.id
where t.id =?
''',
      [taskId],
    );

    return getFirstOrNull(data);
  }

  /// Only Jobs that we consider to be active, filtered by
  /// (summary | description | customer.name), case-insensitive.
  Future<List<Job>> getActiveJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = (filter != null && filter.isNotEmpty) ? '%$filter%' : '%%';

    return toList(
      await db.rawQuery(
        '''
      SELECT j.*
      FROM job j
      LEFT JOIN customer c
        ON c.id = j.customer_id
      WHERE j.status_id NOT IN (
        '${JobStatus.rejected.id}',
        '${JobStatus.onHold.id}',
        '${JobStatus.awaitingPayment.id}',
        '${JobStatus.completed.id}',
        '${JobStatus.toBeBilled.id}'
      )
      AND (
        j.summary LIKE ? COLLATE NOCASE
        OR j.description LIKE ? COLLATE NOCASE
        OR COALESCE(c.name, '') LIKE ? COLLATE NOCASE
      )
      ORDER BY j.is_stock DESC, j.modified_date DESC
      ''',
        [likeArg, likeArg, likeArg],
      ),
    );
  }

  Future<List<Job>> getSchedulableJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '''%$filter%''' : '%%';

    final canBeScheduled = JobStatus.canBeScheduled().map(
      (status) => status.id,
    );

    final canBeScheduledPlaceHolders = List.filled(
      canBeScheduled.length,
      '?',
    ).join(',');

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    WHERE j.status_id IN ( $canBeScheduledPlaceHolders )
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
    ''',
        [...canBeScheduled, likeArg, likeArg],
      ),
    );
  }

  /// Use [JobService.markAwaitingApproval] instead.
  @Deprecated('Use JobService().markAwaitingApproval() instead')
  Future<void> markAwaitingApproval(Job job) =>
      JobService(daoJob: this).markAwaitingApproval(job);

  /// Use [JobService.markScheduled] instead.
  @Deprecated('Use JobService().markScheduled() instead')
  Future<void> markScheduled(Job job) =>
      JobService(daoJob: this).markScheduled(job);

  /// Get Quotable Jobs - now filtered by `preStart` status
  Future<List<Job>> getQuotableJobs(String? filter) async {
    final db = withoutTransaction();
    final likeArg = filter != null ? '%$filter%' : '%%';

    final preStartList =
        ''' '${JobStatus.preStart().map((status) => status.id).join("', '")}' ''';

    return toList(
      await db.rawQuery(
        '''
    SELECT j.*
    FROM job j
    WHERE j.status_id in ($preStartList)
    AND (j.summary LIKE ? OR j.description LIKE ?)
    ORDER BY j.modified_date DESC
  ''',
        [likeArg, likeArg],
      ),
    );
  }

  /// Get all jobs with any of the given [statuses].
  Future<List<Job>> getByStatuses(List<JobStatus> statuses) async {
    if (statuses.isEmpty) {
      return [];
    }

    final db = withoutTransaction();
    final placeholders = List.filled(statuses.length, '?').join(',');

    return toList(
      await db.query(
        tableName,
        where: 'status_id IN ($placeholders)',
        whereArgs: statuses.map((s) => s.id).toList(),
        orderBy: 'modified_date DESC',
      ),
    );
  }

  /// Use [JobService.getJobStatistics] instead.
  @Deprecated('Use JobService().getJobStatistics() instead')
  Future<JobStatistics> getJobStatistics(Job job) =>
      JobService(daoJob: this).getJobStatistics(job);

  /// Use [JobService.getBookingFee] instead.
  @Deprecated('Use JobService().getBookingFee() instead')
  Future<Money> getBookingFee(Job job) =>
      JobService(daoJob: this).getBookingFee(job);

  /// Get all the jobs for the given customer.
  Future<List<Job>> getByCustomer(Customer? customer) async {
    if (customer == null) {
      return [];
    }
    final db = withoutTransaction();

    return toList(
      await db.rawQuery(
        '''
select j.* 
from job j
join customer c
  on j.customer_id = c.id
where c.id =?
''',
        [customer.id],
      ),
    );
  }

  Future<Job?> getByQuoteId(int quoteId) async {
    final db = withoutTransaction();

    return getFirstOrNull(
      await db.rawQuery(
        '''
select j.* 
from quote q
join job j
  on q.job_id = j.id
where q.id=?
''',
        [quoteId],
      ),
    );
  }

  /// Use [JobService.hasBillableTasks] instead.
  @Deprecated('Use JobService().hasBillableTasks() instead')
  Future<bool> hasBillableTasks(Job job) =>
      JobService(daoJob: this).hasBillableTasks(job);

  /// Use [JobService.getBestPhoneNumber] instead.
  @Deprecated('Use JobService().getBestPhoneNumber() instead')
  Future<String?> getBestPhoneNumber(Job job) =>
      JobService(daoJob: this).getBestPhoneNumber(job);

  /// Use [JobService.getBestEmail] instead.
  @Deprecated('Use JobService().getBestEmail() instead')
  Future<String?> getBestEmail(Job job) =>
      JobService(daoJob: this).getBestEmail(job);

  /// Use [JobService.getEmailsByJob] instead.
  @Deprecated('Use JobService().getEmailsByJob() instead')
  Future<List<String>> getEmailsByJob(int jobId) =>
      JobService(daoJob: this).getEmailsByJob(jobId);

  /// Use [JobService.hasQuoteableItems] instead.
  @Deprecated('Use JobService().hasQuoteableItems() instead')
  Future<bool> hasQuoteableItems(Job job) =>
      JobService(daoJob: this).hasQuoteableItems(job);

  /// Use [JobService.getHourlyRate] instead.
  @Deprecated('Use JobService().getHourlyRate() instead')
  Future<Money> getHourlyRate(int jobId) =>
      JobService(daoJob: this).getHourlyRate(jobId);

  /// Use [JobService.getFixedPriceTotal] instead.
  @Deprecated('Use JobService().getFixedPriceTotal() instead')
  Future<Money> getFixedPriceTotal(Job job) =>
      JobService(daoJob: this).getFixedPriceTotal(job);

  /// Use [JobService.hasBillableBookingFee] instead.
  @Deprecated('Use JobService().hasBillableBookingFee() instead')
  Future<bool> hasBillableBookingFee(Job job) =>
      JobService(daoJob: this).hasBillableBookingFee(job);

  /// Use [JobService.markBookingFeeNotBilled] instead.
  @Deprecated('Use JobService().markBookingFeeNotBilled() instead')
  Future<void> markBookingFeeNotBilled(Job job) =>
      JobService(daoJob: this).markBookingFeeNotBilled(job);

  /// Use [JobService.getJobForInvoice] instead.
  @Deprecated('Use JobService().getJobForInvoice() instead')
  Future<Job> getJobForInvoice(int invoiceId) =>
      JobService(daoJob: this).getJobForInvoice(invoiceId);

  /// Use [JobService.getJobForQuote] instead.
  @Deprecated('Use JobService().getJobForQuote() instead')
  Future<Job> getJobForQuote(int quoteId) =>
      JobService(daoJob: this).getJobForQuote(quoteId);

  /// Use [JobService.readyToBeInvoiced] instead.
  @Deprecated('Use JobService().readyToBeInvoiced() instead')
  Future<List<Job>> readyToBeInvoiced(String? filter) =>
      JobService(daoJob: this).readyToBeInvoiced(filter);

  /// Use [JobService.copyJobAndMoveTasks] instead.
  @Deprecated('Use JobService().copyJobAndMoveTasks() instead')
  Future<Job> copyJobAndMoveTasks({
    required Job job,
    required List<Task> tasksToMove,
    required String summary,
    JobStatus? newJobStatus,
    Transaction? transaction,
  }) =>
      JobService(daoJob: this).copyJobAndMoveTasks(
        job: job,
        tasksToMove: tasksToMove,
        summary: summary,
        newJobStatus: newJobStatus,
      );
}

class JobStatistics {
  final int totalTasks;
  final int completedTasks;
  final Fixed expectedLabourHours;
  final Fixed completedLabourHours;
  final Money totalMaterialCost;
  final Money completedMaterialCost;
  final Money worked;
  final Fixed workedHours;

  JobStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.expectedLabourHours,
    required this.completedLabourHours,
    required this.totalMaterialCost,
    required this.completedMaterialCost,
    required this.worked,
    required this.workedHours,
  });
}
