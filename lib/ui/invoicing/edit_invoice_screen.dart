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

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:strings/strings.dart';

import '../../api/accounting/accounting_adaptor.dart';
import '../../api/external_accounting.dart';
import '../../dao/dao_contact.dart';
import '../../dao/dao_invoice.dart';
import '../../dao/dao_invoice_line.dart';
import '../../dao/dao_invoice_line_group.dart';
import '../../dao/dao_task_item.dart';
import '../../dao/dao_time_entry.dart';
import '../../design_system/atoms/status_badge.dart';
import '../../design_system/molecules/grouped_list_section.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/spacing.dart';
import '../../design_system/tokens/typography.dart';
import '../../entity/invoice_line.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../dialog/hmb_comfirm_delete_dialog.dart';
import '../widgets/blocking_ui.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/hmb_delete_icon.dart';
import '../widgets/icons/hmb_edit_icon.dart';
import 'edit_invoice_line_dialog.dart';
import 'invoice_details.dart';
import 'invoice_send_button.dart';

class InvoiceEditScreen extends StatefulWidget {
  final InvoiceDetails invoiceDetails;

  const InvoiceEditScreen({required this.invoiceDetails, super.key});

  @override
  State<InvoiceEditScreen> createState() =>
      _InvoiceEditScreenState();
}

class _InvoiceEditScreenState
    extends DeferredState<InvoiceEditScreen> {
  late final int invoiceId;
  late Future<InvoiceDetails> _invoiceDetails;

  @override
  Future<void> asyncInitState() async {
    invoiceId = widget.invoiceDetails.invoice.id;
    await _reloadInvoice();
  }

  Future<void> _reloadInvoice() async {
    _invoiceDetails = InvoiceDetails.load(invoiceId);
  }

  // -- Status badge helpers ----------------------------------------

  StatusBadgeType _badgeType(InvoiceDetails details) {
    if (details.invoice.paid) {
      return StatusBadgeType.success;
    }
    if (details.invoice.sent) {
      final now = DateTime.now();
      final due = details.invoice.dueDate.toDateTime();
      if (due.isBefore(now)) {
        return StatusBadgeType.error;
      }
      return StatusBadgeType.info;
    }
    return StatusBadgeType.neutral; // Draft
  }

  String _badgeLabel(InvoiceDetails details) {
    if (details.invoice.paid) {
      return 'Paid';
    }
    if (details.invoice.sent) {
      final now = DateTime.now();
      final due = details.invoice.dueDate.toDateTime();
      if (due.isBefore(now)) {
        return 'Overdue';
      }
      return 'Sent';
    }
    return 'Draft';
  }

  // -- Build -------------------------------------------------------

  @override
  Widget build(BuildContext context) =>
      FutureBuilderEx<InvoiceDetails>(
        future: _invoiceDetails,
        waitingBuilder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
        builder: (context, details) {
          if (details == null) {
            return const Center(
              child: Text('No invoice details found.'),
            );
          }

          final invoice = details.invoice;
          final lineGroups = details.lineGroups;
          final typography = HmbTypography.of(context);
          final colors = HmbColors.of(context);

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Invoice #${invoice.bestNumber}',
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: HmbSpacing.lg),

                  // Document header
                  _buildDocumentHeader(
                    details,
                    typography,
                    colors,
                  ),

                  // Line items table per group
                  for (final group in lineGroups)
                    _buildLineGroupSection(
                      group,
                      colors,
                      typography,
                    ),

                  // Totals section
                  _buildTotalsSection(
                    details,
                    typography,
                    colors,
                  ),

                  // Action buttons
                  _buildActionButtons(
                    context,
                    details,
                    colors,
                  ),

                  const SizedBox(height: HmbSpacing.xxl),
                ],
              ),
            ),
          );
        },
      );

  // -- Document header ---------------------------------------------

  Widget _buildDocumentHeader(
    InvoiceDetails details,
    HmbTypography typography,
    HmbColors colors,
  ) {
    final invoice = details.invoice;
    final customer = details.customer;

    return GroupedListSection(
      header: 'Invoice',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large invoice number + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invoice #${invoice.bestNumber}',
                      style: typography.title1,
                    ),
                  ),
                  StatusBadge(
                    label: _badgeLabel(details),
                    type: _badgeType(details),
                  ),
                ],
              ),
              const SizedBox(height: HmbSpacing.sm),
              // Customer name
              Text(
                customer?.name ?? 'No customer',
                style: typography.headline,
              ),
              const SizedBox(height: HmbSpacing.xs),
              // Dates
              Text(
                'Issued: ${formatDate(
                  invoice.createdDate,
                )}',
                style: typography.subheadline.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
              Text(
                'Due: ${formatLocalDate(
                  invoice.dueDate,
                  'yyyy MMM dd',
                )}',
                style: typography.subheadline.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
              // Job reference
              Text(
                'Job: #${details.job.id}'
                ' - ${details.job.summary}',
                style: typography.footnote.copyWith(
                  color: colors.tertiaryLabel,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -- Line items table per group ----------------------------------

  Widget _buildLineGroupSection(
    InvoiceLineGroupDetails group,
    HmbColors colors,
    HmbTypography typography,
  ) {
    final visibleLines = group.lines
        .where(
          (l) =>
              l.status !=
              LineChargeableStatus.noChargeHidden,
        )
        .toList();

    if (visibleLines.isEmpty) {
      return const SizedBox.shrink();
    }

    return GroupedListSection(
      header: group.group.name,
      children: [
        // Column header row
        _buildTableHeaderRow(typography, colors),
        // Line item rows
        for (final line in visibleLines)
          _buildLineItemRow(line, typography, colors),
      ],
    );
  }

  Widget _buildTableHeaderRow(
    HmbTypography typography,
    HmbColors colors,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'Description',
                style: typography.caption1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Qty',
                style: typography.caption1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryLabel,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Rate',
                style: typography.caption1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryLabel,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Amount',
                style: typography.caption1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.secondaryLabel,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // Space for action icons
            const SizedBox(width: 56),
          ],
        ),
      );

  Widget _buildLineItemRow(
    InvoiceLine line,
    HmbTypography typography,
    HmbColors colors,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                line.description,
                style: typography.subheadline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                line.quantity.toString(),
                style: typography.subheadline,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                line.unitPrice.toString(),
                style: typography.subheadline,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                line.lineTotal.toString(),
                style: typography.subheadline.copyWith(
                  fontWeight:
                      line.status ==
                              LineChargeableStatus.noCharge
                          ? FontWeight.w300
                          : FontWeight.w400,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // Edit / Delete icons
            SizedBox(
              width: 56,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  HMBEditIcon(
                    onPressed: () =>
                        _editInvoiceLine(context, line),
                    hint: 'Edit Invoice Line',
                  ),
                  HMBDeleteIcon(
                    onPressed: () =>
                        _deleteInvoiceLine(line),
                    hint: 'Delete Invoice Line',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // -- Totals section ----------------------------------------------

  Widget _buildTotalsSection(
    InvoiceDetails details,
    HmbTypography typography,
    HmbColors colors,
  ) {
    final allLines =
        details.lineGroups.expand((g) => g.lines).toList();
    final subtotal = allLines
        .where(
          (l) =>
              l.status == LineChargeableStatus.normal,
        )
        .fold(
          MoneyEx.zero,
          (sum, l) => sum + l.lineTotal,
        );

    return GroupedListSection(
      header: 'Totals',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.md,
          ),
          child: Column(
            children: [
              // Subtotal
              _buildTotalRow(
                'Subtotal',
                subtotal.toString(),
                typography.subheadline,
                colors.secondaryLabel,
              ),
              const SizedBox(height: HmbSpacing.xs),
              // Divider before total
              Divider(
                color: colors.separator,
                height: 1,
              ),
              const SizedBox(height: HmbSpacing.sm),
              // Total (bold, larger)
              _buildTotalRow(
                'Total',
                details.invoice.totalAmount.toString(),
                typography.headline.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                colors.label,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(
    String label,
    String amount,
    TextStyle style,
    Color labelColor,
  ) =>
      Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style.copyWith(color: labelColor),
          ),
          Text(amount, style: style),
        ],
      );

  // -- Action buttons ----------------------------------------------

  Widget _buildActionButtons(
    BuildContext context,
    InvoiceDetails details,
    HmbColors colors,
  ) {
    final invoice = details.invoice;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary action row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Send',
                  icon: Icons.send_outlined,
                  color: colors.systemBlue,
                  onPressed: () {
                    // Delegate to existing send flow
                    BuildSendButton(
                      context: context,
                      mounted: mounted,
                      invoice: invoice,
                    ).build(context);
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: invoice.paid
                      ? 'Paid'
                      : 'Mark Paid',
                  icon: invoice.paid
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: colors.systemGreen,
                  enabled: !invoice.paid,
                  onPressed: () async {
                    await DaoInvoice().markPaid(
                      invoice.id,
                    );
                    await _reloadInvoice();
                    if (!mounted) {
                      return;
                    }
                    setState(() {});
                    HMBToast.info(
                      'Invoice marked as paid',
                    );
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Download',
                  icon: Icons.picture_as_pdf_outlined,
                  color: colors.systemOrange,
                  onPressed: () {
                    // Trigger PDF via send button flow
                    BuildSendButton(
                      context: context,
                      mounted: mounted,
                      invoice: invoice,
                    ).build(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: HmbSpacing.sm),
          // Secondary actions row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Upload to Xero',
                  icon: Icons.cloud_upload_outlined,
                  color: colors.systemIndigo,
                  onPressed: () {
                    BlockingUI().run(
                      () async {
                        await _uploadInvoiceToXero();
                      },
                      label: 'Uploading Invoice',
                    );
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Add Discount',
                  icon: Icons.discount_outlined,
                  color: colors.systemTeal,
                  onPressed: () async {
                    await _promptAddDiscount();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Existing business logic (preserved) -------------------------

  Future<void> _uploadInvoiceToXero() async {
    if (!(await ExternalAccounting().isEnabled())) {
      HMBToast.info(
        'You must first enable the Xero Integration'
        ' via System | Integration',
      );
      return;
    }
    try {
      final invoice = (await _invoiceDetails).invoice;
      final contact = await DaoContact().getById(
        invoice.billingContactId,
      );
      if (contact == null) {
        HMBToast.error(
          'You must first add a Contact to the Customer',
        );
        return;
      }

      if (Strings.isBlank(contact.emailAddress)) {
        HMBToast.error(
          "The customer's billing contact"
          ' must have an email.',
        );
        return;
      }

      final adaptor = AccountingAdaptor.get();

      await adaptor.login();
      await adaptor.uploadInvoice(invoice);
      if (!mounted) {
        return;
      }
      HMBToast.info(
        'Invoice uploaded to Xero successfully',
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e, st) {
      if (!e.toString().contains(
        'You must provide an email address for',
      )) {
        unawaited(
          Sentry.captureException(
            e,
            stackTrace: st,
            hint: Hint.withMap(
              {'hint': 'UploadInvoiceToXero'},
            ),
          ),
        );
      }
      HMBToast.error(
        'Failed to upload invoice: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _editInvoiceLine(
    BuildContext context,
    InvoiceLine line,
  ) async {
    final editedLine = await showDialog<InvoiceLine>(
      context: context,
      builder: (context) =>
          EditInvoiceLineDialog(line: line),
    );

    if (editedLine != null) {
      await DaoInvoiceLine().update(editedLine);
      await DaoInvoice().recalculateTotal(
        editedLine.invoiceId,
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  Future<void> _deleteInvoiceLine(
    InvoiceLine line,
  ) async {
    await showConfirmDeleteDialog(
      nameSingular: 'Invoice line',
      context: context,
      child: Text(
        'Are you sure you want to delete'
        ' this invoice line?\n\n'
        'Details:\n'
        'Description: ${line.description}\n'
        'Quantity: ${line.quantity}\n'
        'Total: ${line.lineTotal}',
      ),
      onConfirmed: () => _doDeleteInvoiceLine(line),
    );
  }

  Future<void> _doDeleteInvoiceLine(
    InvoiceLine line,
  ) async {
    try {
      await DaoTaskItem().markNotBilled(line.id);
      await DaoTimeEntry().markAsNotbilled(line.id);

      await DaoInvoiceLine().delete(line.id);

      final remainingLines = await DaoInvoiceLine()
          .getByInvoiceLineGroupId(
        line.invoiceLineGroupId,
      );

      if (remainingLines.isEmpty) {
        await DaoInvoiceLineGroup().delete(
          line.invoiceLineGroupId,
        );
      }

      await DaoInvoice().recalculateTotal(
        line.invoiceId,
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to delete invoice line: $e',
        acknowledgmentRequired: true,
      );
    }
  }

  Future<void> _promptAddDiscount() async {
    final descriptionController = TextEditingController(
      text: 'Discount',
    );
    final amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final amount = MoneyEx.tryParse(
      amountController.text,
    );
    if (!amount.isPositive) {
      HMBToast.error(
        'Discount amount must be greater than zero.',
      );
      return;
    }

    try {
      final details = await _invoiceDetails;
      await DaoInvoice().addDiscountLine(
        invoice: details.invoice,
        amount: amount,
        description: descriptionController.text
                .trim()
                .isEmpty
            ? 'Discount'
            : descriptionController.text.trim(),
      );
      await _reloadInvoice();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (e) {
      HMBToast.error(
        'Failed to add discount: $e',
        acknowledgmentRequired: true,
      );
    }
  }
}

/// A styled action button for the invoice action bar.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool enabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled
        ? color
        : color.withValues(alpha: 0.4);

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        size: 18,
        color: effectiveColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: effectiveColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: effectiveColor.withValues(
            alpha: 0.3,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.md,
          vertical: HmbSpacing.sm,
        ),
      ),
    );
  }
}
