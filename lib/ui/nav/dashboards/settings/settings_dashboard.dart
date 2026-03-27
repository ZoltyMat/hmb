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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/molecules/grouped_list_section.dart';
import '../../../../design_system/theme.dart';
import '../../../../src/version/version.g.dart';
import '../../../../util/flutter/app_title.dart';

/// iOS Settings-style settings screen using GroupedListSection widgets.
///
/// Organises settings into logical groups: Account, Appearance,
/// Data, Integrations, and About.
class SettingsDashboardPage extends StatefulWidget {
  const SettingsDashboardPage({super.key});

  @override
  State<SettingsDashboardPage> createState() => _SettingsDashboardPageState();
}

class _SettingsDashboardPageState extends State<SettingsDashboardPage> {
  @override
  void initState() {
    super.initState();
    setAppTitle('Settings');
  }

  @override
  Widget build(BuildContext context) {
    final colors = HmbColors.of(context);
    final typography = HmbTypography.of(context);

    return Scaffold(
      backgroundColor: colors.groupedBackground,
      body: ListView(
        children: [
          const SizedBox(height: HmbSpacing.sm),

          // -- Account section --
          GroupedListSection(
            header: 'Account',
            footer: 'Business name, contact details, and billing settings.',
            children: [
              _SettingsTile(
                icon: Icons.business,
                iconColor: colors.systemBlue,
                title: 'Business',
                subtitle: 'Name, ABN, operating hours',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/business'),
              ),
              _SettingsTile(
                icon: Icons.contact_phone,
                iconColor: colors.systemGreen,
                title: 'Contact',
                subtitle: 'Address, phone, email',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/contact'),
              ),
              _SettingsTile(
                icon: Icons.account_balance,
                iconColor: colors.systemOrange,
                title: 'Billing',
                subtitle: 'Rates, bank details, invoice format',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/billing'),
              ),
            ],
          ),

          // -- Appearance section --
          GroupedListSection(
            header: 'Appearance',
            children: [
              _SettingsTile(
                icon: Icons.palette,
                iconColor: colors.systemPurple,
                title: 'Theme',
                subtitle: 'System, Light, or Dark',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/appearance'),
              ),
            ],
          ),

          // -- Notifications section (placeholder) --
          GroupedListSection(
            header: 'Notifications',
            footer: 'Notification preferences will appear here in a future '
                'update.',
            children: [
              _SettingsToggleTile(
                icon: Icons.notifications_outlined,
                iconColor: colors.systemRed,
                title: 'Job Reminders',
                typography: typography,
                colors: colors,
                value: false,
                onChanged: null, // disabled placeholder
              ),
              _SettingsToggleTile(
                icon: Icons.mark_email_unread_outlined,
                iconColor: colors.systemTeal,
                title: 'Booking Alerts',
                typography: typography,
                colors: colors,
                value: false,
                onChanged: null, // disabled placeholder
              ),
            ],
          ),

          // -- Data section --
          GroupedListSection(
            header: 'Data',
            footer: 'Manage backups, storage cache, and message templates.',
            children: [
              _SettingsTile(
                icon: Icons.cloud_upload_outlined,
                iconColor: colors.systemBlue,
                title: 'Backup & Restore',
                subtitle: 'Google Drive and local backups',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/backup'),
              ),
              _SettingsTile(
                icon: Icons.storage,
                iconColor: colors.systemGray,
                title: 'Storage',
                subtitle: 'Photo cache size and usage',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/storage'),
              ),
              _SettingsTile(
                icon: Icons.message_outlined,
                iconColor: colors.systemGreen,
                title: 'SMS Templates',
                subtitle: 'Quick-send text message templates',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/sms_templates'),
              ),
            ],
          ),

          // -- Integrations section --
          GroupedListSection(
            header: 'Integrations',
            children: [
              _SettingsTile(
                icon: Icons.extension,
                iconColor: colors.systemIndigo,
                title: 'Integrations',
                subtitle: 'Xero, ChatGPT, IH Server',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/settings/integrations'),
              ),
            ],
          ),

          // -- About section --
          GroupedListSection(
            header: 'About',
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                iconColor: colors.systemGray,
                title: 'About HMB',
                subtitle: 'Version $packageVersion',
                typography: typography,
                colors: colors,
                onTap: () => context.push('/home/help/about'),
              ),
              _SettingsTile(
                icon: Icons.auto_fix_high,
                iconColor: colors.systemYellow,
                title: 'Setup Wizard',
                subtitle: 'Re-run initial configuration',
                typography: typography,
                colors: colors,
                onTap: () =>
                    context.push('/home/settings/wizard', extra: true),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: colors.systemGray,
                title: 'Licenses',
                subtitle: 'Open-source licenses',
                typography: typography,
                colors: colors,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Hold My Beer',
                  applicationVersion: packageVersion,
                ),
              ),
            ],
          ),

          const SizedBox(height: HmbSpacing.xxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private row widgets
// ---------------------------------------------------------------------------

/// A navigation row that mimics CupertinoListTile with an icon, title,
/// optional subtitle, and a trailing chevron disclosure indicator.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.typography,
    required this.colors,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final HmbTypography typography;
  final HmbColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HmbSpacing.lg,
              vertical: HmbSpacing.sm,
            ),
            child: Row(
              children: [
                // Icon in a rounded rect (iOS style)
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: HmbSpacing.md),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: typography.body.copyWith(color: colors.label),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: typography.footnote
                              .copyWith(color: colors.secondaryLabel),
                        ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: colors.tertiaryLabel,
                ),
              ],
            ),
          ),
        ),
      );
}

/// A toggle row with an icon, title, and a CupertinoSwitch on the trailing
/// side. Used for boolean preferences (e.g. notifications).
class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.typography,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final HmbTypography typography;
  final HmbColors colors;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HmbSpacing.lg,
            vertical: HmbSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: HmbSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: typography.body.copyWith(
                    color: onChanged != null
                        ? colors.label
                        : colors.tertiaryLabel,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );
}
