/*
 Copyright (C) OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   - Permitted for internal use within your own business or organization only.
   - Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../dao/dao_base.dart';

/// Mixin that provides transaction support to service classes.
///
/// Services that perform multi-DAO write operations should use this mixin
/// to ensure atomicity. The [transactionDao] must be set to any DAO instance
/// (used solely to access the shared database connection).
///
/// Usage:
/// ```dart
/// class MyService with TransactionMixin {
///   MyService() {
///     transactionDao = _someDaoInstance;
///   }
///   ...
///   Future<void> doMultiWrite() => withTransaction((txn) async {
///     await _daoA.update(entity, txn);
///     await _daoB.insert(other, txn);
///   });
/// }
/// ```
mixin TransactionMixin {
  /// Any DAO instance — used only to access the shared [Database].
  late final DaoBase transactionDao;

  /// Executes [action] inside a single SQLite transaction.
  ///
  /// If any operation within [action] throws, the entire transaction is
  /// rolled back, preventing partial writes across tables.
  Future<R> withTransaction<R>(
    Future<R> Function(Transaction txn) action,
  ) =>
      transactionDao.withTransaction(action);
}
