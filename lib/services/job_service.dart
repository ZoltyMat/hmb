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

import '../dao/dao.g.dart';
import '../entity/entity.g.dart';
import '../util/dart/exceptions.dart';
import '../util/dart/money_ex.dart';
import 'transaction_mixin.dart';

/// Service layer for Job business logic.
///
/// Extracts status transitions, multi-DAO operations, financial calculations,
/// and contact lookups out of DaoJob to keep the DAO focused on data access.
///
/// Multi-DAO write operations are wrapped in SQLite transactions via
/// [TransactionMixin] to prevent partial updates on failure.
class JobService with TransactionMixin {
  JobService({
    DaoJob? daoJob,
    DaoTask? daoTask,
    DaoTaskItem? daoTaskItem,
    DaoTimeEntry? daoTimeEntry,
    DaoQuote? daoQuote,
    DaoContact? daoContact,
    DaoCustomer? daoCustomer,
    DaoSystem? daoSystem,
    DaoInvoice? daoInvoice,
    DaoWorkAssignmentTask? daoWorkAssignmentTask,
  })  : _daoJob = daoJob ?? DaoJob(),
        _daoTask = daoTask ?? DaoTask(),
        _daoTaskItem = daoTaskItem ?? DaoTaskItem(),
        _daoTimeEntry = daoTimeEntry ?? DaoTimeEntry(),
        _daoQuote = daoQuote ?? DaoQuote(),
        _daoContact = daoContact ?? DaoContact(),
        _daoCustomer = daoCustomer ?? DaoCustomer(),
        _daoSystem = daoSystem ?? DaoSystem(),
        _daoInvoice = daoInvoice ?? DaoInvoice(),
        _daoWorkAssignmentTask =
            daoWorkAssignmentTask ?? DaoWorkAssignmentTask() {
    transactionDao = _daoJob;
  }

  final DaoJob _daoJob;
  final DaoTask _daoTask;
  final DaoTaskItem _daoTaskItem;
  final DaoTimeEntry _daoTimeEntry;
  final DaoQuote _daoQuote;
  final DaoContact _daoContact;
  final DaoCustomer _daoCustomer;
  final DaoSystem _daoSystem;
  final DaoInvoice _daoInvoice;
  final DaoWorkAssignmentTask _daoWorkAssignmentTask;

  // ---------------------------------------------------------------------------
  // Status Transitions
  // ---------------------------------------------------------------------------

  /// Marks the job as 'in progress' if it is in a pre-start state.
  /// Also marks the job as the last active job.
  ///
  /// Wrapped in a transaction because it updates the previous last-active job,
  /// sets the current job as last-active, and may change the job status —
  /// up to three writes that must succeed or fail together.
  Future<Job> markActive(int jobId) => withTransaction((txn) async {
        await _markLastActiveInTxn(jobId, txn);
        final job = (await _daoJob.getById(jobId, txn))!;

        if (job.status.stage == JobStatusStage.preStart) {
          job.status = JobStatus.inProgress;
          await _daoJob.update(job, txn);
        }

        return job;
      });

  /// Marks the job as the most recently accessed job without changing status.
  ///
  /// Wrapped in a transaction because it updates both the previous last-active
  /// job and the new one — two writes that must be atomic.
  Future<void> markLastActive(int jobId) =>
      withTransaction((txn) => _markLastActiveInTxn(jobId, txn));

  /// Inner implementation of markLastActive that accepts a transaction,
  /// allowing it to be composed into larger transactional operations.
  Future<void> _markLastActiveInTxn(int jobId, Transaction txn) async {
    final lastActive = await _daoJob.getLastActiveJob();
    if (lastActive != null) {
      if (lastActive.id != jobId) {
        lastActive.lastActive = false;
        await _daoJob.update(lastActive, txn);
      }
    }
    final job = (await _daoJob.getById(jobId, txn))!;

    /// even if the job is active we want to update the last
    /// modified date so it comes up first in the job list.
    job.lastActive = true;
    job.modifiedDate = DateTime.now();
    await _daoJob.update(job, txn);
  }

  /// Marks the job as 'in quoting' if it is
  /// in a [JobStatus.prospecting] state.
  Future<Job> markQuoting(int jobId) async {
    final job = await _daoJob.getById(jobId);

    /// even if the job is active we want to update the last
    /// modified date so it comes up first in the job list.
    job!.lastActive = true;
    job.modifiedDate = DateTime.now();

    if (job.status == JobStatus.prospecting) {
      job.status = JobStatus.quoting;
    }
    await _daoJob.update(job);

    return job;
  }

  /// Marks the job as 'awaiting approval' if it can be approved.
  Future<void> markAwaitingApproval(Job job) async {
    final canBeApproved = JobStatus.canBeAwaitingApproved(job);

    if (canBeApproved) {
      job.status = JobStatus.awaitingApproval;
      await _daoJob.update(job);
    }
  }

  /// Mark the job as scheduled if it is in a pre-start state.
  Future<void> markScheduled(Job job) async {
    final jobStatus = job.status;

    if (jobStatus.stage == JobStatusStage.preStart) {
      job.status = JobStatus.scheduled;
      await _daoJob.update(job);
    }
  }

  /// Marks the booking fee as not billed.
  Future<void> markBookingFeeNotBilled(Job job) async {
    job.bookingFeeInvoiced = false;
    await _daoJob.update(job);
  }

  // ---------------------------------------------------------------------------
  // Multi-DAO / Financial Operations
  // ---------------------------------------------------------------------------

  /// Calculates comprehensive statistics for a job including task progress,
  /// labour hours, material costs, and worked time.
  Future<JobStatistics> getJobStatistics(Job job) async {
    final tasks = await _daoTask.getTasksByJob(job.id);
    final hourlyRate = await getHourlyRate(job.id);

    final totalTasks = tasks.length;
    var completedTasks = 0;
    var expectedLabourHours = Fixed.zero;
    var completedLabourHours = Fixed.zero;
    var totalMaterialCost = MoneyEx.zero;
    var completedMaterialCost = MoneyEx.zero;
    var workedHours = Fixed.fromNum(0, decimalDigits: 2);

    for (final task in tasks) {
      final status = task.status;
      final taskItems = await _daoTaskItem.getByTask(task.id);

      for (final item in taskItems) {
        var hours = Fixed.zero;
        var materialCost = MoneyEx.zero;
        switch (item.itemType) {
          case TaskItemType.materialsBuy:
          case TaskItemType.materialsStock:
          case TaskItemType.consumablesStock:
          case TaskItemType.consumablesBuy:
            materialCost = item.estimatedMaterialUnitCost!.multiplyByFixed(
              item.estimatedMaterialQuantity!,
            );
          case TaskItemType.toolsBuy:
          case TaskItemType.toolsOwn:
            materialCost = MoneyEx.zero;
          case TaskItemType.labour:
            switch (item.labourEntryMode) {
              case LabourEntryMode.hours:
                hours = item.estimatedLabourHours!;
              case LabourEntryMode.dollars:
                hours = Fixed.fromNum(
                  item.estimatedLabourCost!.dividedBy(hourlyRate),
                );
            }
        }

        expectedLabourHours += hours;
        totalMaterialCost += materialCost;

        if ((status.isComplete()) || item.completed) {
          completedLabourHours += hours;
          completedMaterialCost += materialCost;
        }
      }

      if (status.isComplete()) {
        completedTasks++;
      }

      final timeEntries = await _daoTimeEntry.getByTask(task.id);
      for (final timeEntry in timeEntries) {
        workedHours += Fixed.fromInt(
          (timeEntry.duration.inMinutes / 60.0 * 100).toInt(),
        );
      }
    }

    return JobStatistics(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      expectedLabourHours: expectedLabourHours,
      completedLabourHours: completedLabourHours,
      totalMaterialCost: totalMaterialCost,
      completedMaterialCost: completedMaterialCost,
      workedHours: workedHours,
      worked: job.hourlyRate!.multiplyByFixed(workedHours),
    );
  }

  /// Gets the booking fee for a job, falling back to the system default.
  Future<Money> getBookingFee(Job job) async {
    if (job.bookingFee != null) {
      return job.bookingFee!;
    }

    final system = await _daoSystem.get();

    if (system.defaultBookingFee != null) {
      return system.defaultBookingFee!;
    }

    return MoneyEx.zero;
  }

  /// Gets the hourly rate for a job, falling back to the system default.
  Future<Money> getHourlyRate(int jobId) async {
    final job = await _daoJob.getById(jobId);
    return job?.hourlyRate ?? _daoSystem.getHourlyRate();
  }

  /// Checks whether any tasks on the job have billable (un-billed) value.
  Future<bool> hasBillableTasks(Job job) async {
    final tasksAccruedValue = await _daoTask.getAccruedValueForJob(
      job: job,
      includedBilled: false,
    );

    for (final task in tasksAccruedValue) {
      if ((await task.earned) > MoneyEx.zero) {
        return true;
      }
    }

    return false;
  }

  /// Checks whether any task items on the job have quotable values.
  Future<bool> hasQuoteableItems(Job job) async {
    final estimates = await _daoTask.getEstimatesForJob(job);
    return estimates.fold(false, (a, b) async => await a || b.total.isPositive);
  }

  /// Calculates the total quoted (fixed) price for the job.
  Future<Money> getFixedPriceTotal(Job job) async {
    final estimates = await _daoTask.getEstimatesForJob(job);

    var total = MoneyEx.zero;
    for (final estimate in estimates) {
      if (estimate.total > MoneyEx.zero) {
        total += estimate.total;
      }
    }
    return total;
  }

  /// Returns true when the job has a billable booking fee:
  /// must be Time & Materials, not yet invoiced, and non-zero.
  Future<bool> hasBillableBookingFee(Job job) async =>
      job.billingType == BillingType.timeAndMaterial &&
      !job.bookingFeeInvoiced &&
      job.bookingFee != null &&
      (await getBookingFee(job) != MoneyEx.zero);

  // ---------------------------------------------------------------------------
  // Contact Lookups (multi-DAO)
  // ---------------------------------------------------------------------------

  /// Gets the best phone number for a job's contact or customer.
  Future<String?> getBestPhoneNumber(Job job) async {
    String? bestPhone;
    if (job.contactId != null) {
      bestPhone = (await _daoContact.getPrimaryForJob(job.id))?.bestPhone;
    }

    if (bestPhone == null) {
      final customer = await _daoCustomer.getByJob(job.id);
      bestPhone = (await _daoContact.getPrimaryForCustomer(
        customer!.id,
      ))?.bestPhone;
    }
    return bestPhone;
  }

  /// Gets the best email address for a job's contact or customer.
  Future<String?> getBestEmail(Job job) async {
    String? bestEmail;
    if (job.contactId != null) {
      bestEmail = (await _daoContact.getPrimaryForJob(job.id))?.bestEmail;
    }

    if (bestEmail == null) {
      final customer = await _daoCustomer.getByJob(job.id);
      bestEmail = (await _daoContact.getPrimaryForCustomer(
        customer!.id,
      ))?.bestEmail;
    }
    return bestEmail;
  }

  /// Gets all unique email addresses for contacts associated with a job.
  Future<List<String>> getEmailsByJob(int jobId) async {
    final job = await _daoJob.getById(jobId);
    final customer = await _daoCustomer.getById(job!.customerId);
    final contacts = await _daoContact.getByCustomer(customer!.id);

    /// make sure we have no dups.
    final emails = <String>{};

    for (final contact in contacts) {
      if (Strings.isNotBlank(contact.emailAddress)) {
        emails.add(contact.emailAddress.trim());
      }
      if (Strings.isNotBlank(contact.alternateEmail)) {
        emails.add(contact.alternateEmail!.trim());
      }
    }

    return emails.toList();
  }

  // ---------------------------------------------------------------------------
  // Cross-entity Lookups
  // ---------------------------------------------------------------------------

  /// Gets the job associated with an invoice.
  Future<Job> getJobForInvoice(int invoiceId) async {
    final invoice = await _daoInvoice.getById(invoiceId);
    return (await _daoJob.getById(invoice!.jobId))!;
  }

  /// Gets the job associated with a quote.
  Future<Job> getJobForQuote(int quoteId) async {
    final quote = await _daoQuote.getById(quoteId);
    return (await _daoJob.getById(quote!.jobId))!;
  }

  /// Returns active jobs that have billable tasks ready to be invoiced.
  Future<List<Job>> readyToBeInvoiced(String? filter) async {
    final activeJobs = await _daoJob.getActiveJobs(filter);
    final ready = <Job>[];
    for (final job in activeJobs) {
      if (job.billingType == BillingType.nonBillable) {
        continue;
      }
      final hasBillable = await hasBillableTasks(job);
      if (hasBillable) {
        ready.add(job);
      }
    }
    return ready;
  }

  /// Copy a [Job] and move selected [Task]s to the new [Job].
  Future<Job> copyJobAndMoveTasks({
    required Job job,
    required List<Task> tasksToMove,
    required String summary,
    JobStatus? newJobStatus,
  }) async {
    final daoTask = _daoTask;
    final daoTaskItem = _daoTaskItem;
    final daoTimeEntry = _daoTimeEntry;
    final daoWAT = _daoWorkAssignmentTask;

    // Validate tasks belong to the job
    for (final task in tasksToMove) {
      if (task.jobId != job.id) {
        throw TaskMoveException(
          'Task ${task.name} does not belong to job ${job.description}.',
        );
      }
    }

    // Check business rules
    final nonMovableReasons = <Task, String>{};
    for (final t in tasksToMove) {
      final billed = await daoTask.isTaskBilled(
        task: t,
        daoTaskItem: daoTaskItem,
        daoTimeEntry: daoTimeEntry,
      );
      if (billed) {
        nonMovableReasons[t] = 'has billed items or time.';
        continue;
      }
      final hasWA = await daoTask.hasWorkAssignment(task: t, daoWAT: daoWAT);
      if (hasWA) {
        nonMovableReasons[t] = 'is linked to a work assignment.';
        continue;
      }

      if (await daoTask.isTaskLinkedToQuote(t)) {
        nonMovableReasons[t] = 'is linked to a quote.';
        continue;
      }
    }

    if (nonMovableReasons.isNotEmpty) {
      final b = StringBuffer('One or more tasks cannot be moved:\n');
      nonMovableReasons.forEach((id, why) {
        b.writeln(' - Task $id: $why');
      });
      throw TaskMoveException(b.toString());
    }

    // Use withTransaction so everything is atomic
    return withTransaction((transaction) async {
      // 1. Insert new job
      final inserted = Job.forInsert(
        customerId: job.customerId,
        summary: summary,
        description: job.description,
        assumption: job.assumption,
        siteId: job.siteId,
        contactId: job.contactId,
        status: newJobStatus ?? JobStatus.startingStatus,
        hourlyRate: job.hourlyRate,
        bookingFee: job.bookingFee,
        billingContactId: job.billingContactId,
        billingType: job.billingType,
        lastActive: true,
      );

      final newJobId = await _daoJob.insert(inserted, transaction);
      final newJob = (await _daoJob.getById(newJobId, transaction))!;

      // 2. Move tasks by updating jobId
      for (final t in tasksToMove) {
        final moved = t.copyWith(
          jobId: newJobId,
          name: t.name,
          description: t.description,
          assumption: t.assumption,
          status: t.status,
        );
        await daoTask.update(moved, transaction);
      }

      final srcTouched = job
        ..modifiedDate = DateTime.now()
        ..lastActive = false;
      await _daoJob.update(srcTouched, transaction);

      return newJob;
    });
  }
}
