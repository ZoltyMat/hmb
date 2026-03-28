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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import '../../dao/dao.g.dart';
import '../../design_system/atoms/status_badge.dart';
import '../../design_system/molecules/grouped_list_section.dart';
import '../../design_system/tokens/colors.dart';
import '../../design_system/tokens/spacing.dart';
import '../../design_system/tokens/typography.dart';
import '../../entity/invoice_line.dart';
import '../../entity/quote.dart';
import '../../entity/quote_line.dart';
import '../../util/dart/format.dart';
import 'job_and_customer.dart';
import 'quote_details.dart';

class QuoteDetailsScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailsScreen({required this.quoteId, super.key});

  @override
  _QuoteDetailsScreenState createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends DeferredState<QuoteDetailsScreen> {
  late Quote _quote;
  late JobAndCustomer _jc;

  @override
  Future<void> asyncInitState() async {
    _quote = (await DaoQuote().getById(widget.quoteId))!;
    _jc = await JobAndCustomer.fromQuote(_quote);
  }

  Future<void> _reloadQuote() async {
    _quote = (await DaoQuote().getById(widget.quoteId))!;
    _jc = await JobAndCustomer.fromQuote(_quote);
  }

  // -- Status badge helpers ----------------------------------------

  StatusBadgeType _badgeType() {
    switch (_quote.state) {
      case QuoteState.reviewing:
        return StatusBadgeType.neutral;
      case QuoteState.sent:
        return StatusBadgeType.info;
      case QuoteState.approved:
      case QuoteState.invoiced:
        return StatusBadgeType.success;
      case QuoteState.rejected:
        return StatusBadgeType.error;
      case QuoteState.withdrawn:
        return StatusBadgeType.warning;
    }
  }

  String _badgeLabel() {
    switch (_quote.state) {
      case QuoteState.reviewing:
        return 'Draft';
      case QuoteState.sent:
        return 'Sent';
      case QuoteState.approved:
        return 'Approved';
      case QuoteState.invoiced:
        return 'Invoiced';
      case QuoteState.rejected:
        return 'Rejected';
      case QuoteState.withdrawn:
        return 'Withdrawn';
    }
  }

  // -- Build -------------------------------------------------------

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) {
      final typography = HmbTypography.of(context);
      final colors = HmbColors.of(context);

      return Scaffold(
        appBar: AppBar(
          title: Text('Quote #${_quote.bestNumber}'),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: HmbSpacing.lg),

              // Document header
              _buildDocumentHeader(typography, colors),

              // Line items per group
              FutureBuilderEx<QuoteDetails>(
                future: QuoteDetails.fromQuoteId(
                  _quote.id,
                  excludeHidden: false,
                ),
                debugLabel: 'QuoteDetailsScreen:lineItems',
                builder: (context, details) {
                  if (details == null || details.groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(HmbSpacing.lg),
                      child: Text(
                        'No quote lines found.',
                        style: typography.subheadline.copyWith(
                          color: colors.secondaryLabel,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final group in details.groups)
                        _buildLineGroupSection(group, colors, typography),

                      // Totals
                      _buildTotalsSection(details, typography, colors),
                    ],
                  );
                },
              ),

              // Action buttons
              _buildActionButtons(context, colors),

              const SizedBox(height: HmbSpacing.xxl),
            ],
          ),
        ),
      );
    },
  );

  // -- Document header ---------------------------------------------

  Widget _buildDocumentHeader(
    HmbTypography typography,
    HmbColors colors,
  ) => GroupedListSection(
    header: 'Quote',
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HmbSpacing.lg,
          vertical: HmbSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large quote number + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quote #${_quote.bestNumber}',
                    style: typography.title1,
                  ),
                ),
                StatusBadge(
                  label: _badgeLabel(),
                  type: _badgeType(),
                ),
              ],
            ),
            const SizedBox(height: HmbSpacing.sm),

            // Customer name
            Text(
              _jc.customer.name,
              style: typography.headline,
            ),
            const SizedBox(height: HmbSpacing.xs),

            // Summary
            if (_quote.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: HmbSpacing.xs),
                child: Text(
                  _quote.summary,
                  style: typography.subheadline,
                ),
              ),

            // Dates
            Text(
              'Created: ${formatDate(_quote.createdDate)}',
              style: typography.subheadline.copyWith(
                color: colors.secondaryLabel,
              ),
            ),
            if (_quote.dateSent != null)
              Text(
                'Sent: ${formatDate(_quote.dateSent!)}',
                style: typography.subheadline.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
            if (_quote.dateApproved != null)
              Text(
                'Approved: ${formatDate(_quote.dateApproved!)}',
                style: typography.subheadline.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),

            // Job reference
            Text(
              'Job: #${_jc.job.id} - ${_jc.job.summary}',
              style: typography.footnote.copyWith(
                color: colors.tertiaryLabel,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Contacts
            if (_jc.primaryContact != null)
              Text(
                'Contact: ${_jc.primaryContact!.fullname}',
                style: typography.footnote.copyWith(
                  color: colors.tertiaryLabel,
                ),
              ),

            // Margin
            if (!_quote.quoteMargin.isZero)
              Text(
                'Margin: ${_quote.quoteMargin}',
                style: typography.footnote.copyWith(
                  color: colors.tertiaryLabel,
                ),
              ),
          ],
        ),
      ),
    ],
  );

  // -- Line items table per group ----------------------------------

  Widget _buildLineGroupSection(
    QuoteLineGroupWithLines group,
    HmbColors colors,
    HmbTypography typography,
  ) {
    if (group.lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return GroupedListSection(
      header: group.group.name,
      children: [
        // Column header row
        _buildTableHeaderRow(typography, colors),
        // Line item rows
        for (final line in group.lines)
          _buildLineItemRow(line, typography, colors),
      ],
    );
  }

  Widget _buildTableHeaderRow(
    HmbTypography typography,
    HmbColors colors,
  ) => Padding(
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
      ],
    ),
  );

  Widget _buildLineItemRow(
    QuoteLine line,
    HmbTypography typography,
    HmbColors colors,
  ) {
    final isHidden =
        line.lineChargeableStatus == LineChargeableStatus.noChargeHidden;
    final isNoCharge =
        line.lineChargeableStatus == LineChargeableStatus.noCharge;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.sm,
      ),
      child: Opacity(
        opacity: isHidden ? 0.5 : 1.0,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.description,
                    style: typography.subheadline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isHidden || isNoCharge)
                    Text(
                      line.lineChargeableStatus.description,
                      style: typography.caption2.copyWith(
                        color: colors.systemOrange,
                      ),
                    ),
                ],
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
                line.unitCharge.toString(),
                style: typography.subheadline,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                line.lineTotal.toString(),
                style: typography.subheadline.copyWith(
                  fontWeight: isNoCharge ? FontWeight.w300 : FontWeight.w400,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Totals section ----------------------------------------------

  Widget _buildTotalsSection(
    QuoteDetails details,
    HmbTypography typography,
    HmbColors colors,
  ) {
    final subtotal = details.total;

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
              // Subtotal (sum of visible lines)
              _buildTotalRow(
                'Subtotal',
                subtotal.toString(),
                typography.subheadline,
                colors.secondaryLabel,
              ),
              const SizedBox(height: HmbSpacing.xs),
              // Divider before total
              Divider(color: colors.separator, height: 1),
              const SizedBox(height: HmbSpacing.sm),
              // Total (from quote entity)
              _buildTotalRow(
                'Total',
                _quote.totalAmount.toString(),
                typography.headline.copyWith(fontWeight: FontWeight.w700),
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
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: style.copyWith(color: labelColor)),
      Text(amount, style: style),
    ],
  );

  // -- Action buttons ----------------------------------------------

  Widget _buildActionButtons(BuildContext context, HmbColors colors) {
    final isTerminal = _quote.state == QuoteState.rejected ||
        _quote.state == QuoteState.withdrawn;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HmbSpacing.lg,
        vertical: HmbSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Send',
                  icon: Icons.send_outlined,
                  color: colors.systemBlue,
                  enabled: !isTerminal,
                  onPressed: () {
                    // Send flow handled by QuoteCard — navigate back
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: colors.systemGreen,
                  enabled: !isTerminal &&
                      _quote.state != QuoteState.approved &&
                      _quote.state != QuoteState.invoiced,
                  onPressed: () async {
                    await DaoQuote().approveQuote(_quote.id);
                    await _reloadQuote();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: HmbSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: colors.systemRed,
                  enabled: !isTerminal,
                  onPressed: () async {
                    await DaoQuote().rejectQuote(_quote.id);
                    await _reloadQuote();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -- Description / assumptions section ---------------------------

}

/// A styled action button for the quote action bar.
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
      icon: Icon(icon, size: 18, color: effectiveColor),
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
          color: effectiveColor.withValues(alpha: 0.3),
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
