/*
 Copyright (C) OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General
 Public License, with the following exceptions:
   - Permitted for internal use within your own business
     or organization only.
   - Any external distribution, resale, or incorporation
     into products for third parties is strictly
     prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../../design_system/atoms/status_badge.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/spacing.dart';
import '../../design_system/tokens/typography.dart';
import '../../util/dart/format.dart';
import '../crud/job/full_page_list_job_card.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';
import 'invoice_details.dart';

class ListInvoiceCard extends StatelessWidget {
  final InvoiceDetails invoiceDetails;

  final bool showJobDetails;

  const ListInvoiceCard({
    required this.invoiceDetails,
    required this.showJobDetails,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = HmbTypography.of(context);
    final colors = HmbColors.of(context);
    final invoice = invoiceDetails.invoice;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.sm,
        vertical: HmbSpacing.xs,
      ),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: invoice number + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invoice #${invoice.bestNumber}',
                  style: typography.headline,
                ),
              ),
              StatusBadge(
                label: _badgeLabel,
                type: _badgeType,
              ),
            ],
          ),
          const SizedBox(height: HmbSpacing.xs),
          // Customer name
          Text(
            'Customer: '
            '${invoiceDetails.customer?.name ?? 'N/A'}',
            style: typography.subheadline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Job link (if showing)
          if (showJobDetails)
            HMBLinkInternal(
              label: 'Job: #${invoiceDetails.job.id}'
                  ' - ${invoiceDetails.job.summary}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              navigateTo: () async =>
                  FullPageListJobCard(invoiceDetails.job),
            ),
          const SizedBox(height: HmbSpacing.xs),
          // Date + total row
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issued: ${formatDate(
                  invoice.createdDate,
                )}',
                style: typography.footnote.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
              Text(
                invoice.totalAmount.toString(),
                style: typography.headline,
              ),
            ],
          ),
          const SizedBox(height: HmbSpacing.sm),
          // Xero / integration chip
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildXeroChip(),
              if (invoice.paid &&
                  invoice.paidDate != null)
                HMBChip(
                  label: 'Paid ${formatDate(
                    invoice.paidDate!,
                  )}',
                  tone: HMBChipTone.accent,
                  icon: Icons.check_circle,
                ),
            ],
          ),
        ],
      ),
    );
  }

  StatusBadgeType get _badgeType {
    if (invoiceDetails.invoice.paid) {
      return StatusBadgeType.success;
    }
    if (invoiceDetails.invoice.sent) {
      final now = DateTime.now();
      final due =
          invoiceDetails.invoice.dueDate.toDateTime();
      if (due.isBefore(now)) {
        return StatusBadgeType.error;
      }
      return StatusBadgeType.info;
    }
    return StatusBadgeType.neutral;
  }

  String get _badgeLabel {
    if (invoiceDetails.invoice.paid) {
      return 'Paid';
    }
    if (invoiceDetails.invoice.sent) {
      final now = DateTime.now();
      final due =
          invoiceDetails.invoice.dueDate.toDateTime();
      if (due.isBefore(now)) {
        return 'Overdue';
      }
      return 'Sent';
    }
    return 'Draft';
  }

  Widget _buildXeroChip() {
    final invoiceNum =
        invoiceDetails.invoice.invoiceNum;
    if (invoiceNum == null || invoiceNum.isEmpty) {
      return const HMBChip(
        label: 'Not uploaded',
        tone: HMBChipTone.warning,
        icon: Icons.cloud_off,
      );
    }

    return HMBChip(
      label: 'Xero #$invoiceNum',
      icon: Icons.cloud_done,
    );
  }
}
