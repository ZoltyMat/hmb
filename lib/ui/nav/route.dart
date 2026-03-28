/*
 Copyright (c) OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   - Permitted for internal use within your own business or organization only.
   - Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../database/management/backup_providers/google_drive/google_drive_backup_screen.dart';
import '../../database/management/backup_providers/local/local_backup_screen.dart';
import '../../util/flutter/flutter_types.dart';
import '../about.dart';
import '../crud/customer/list_customer_screen.dart';
import '../crud/job/estimator/list_job_estimates_screen.dart';
import '../crud/job/list_job_screen.dart';
import '../crud/manufacturer/list_manufacturer_screen.dart';
import '../crud/message_template/list_message_template.dart';
import '../crud/milestone/list_milestone_screen.dart';
import '../crud/receipt/list_receipt_screen.dart';
import '../crud/supplier/list_supplier_screen.dart';
import '../crud/system/ai_settings_screen.dart';
import '../crud/system/appearance_screen.dart';
import '../crud/system/chatgpt_integration_screen.dart';
import '../crud/system/ihserver_integration_screen.dart';
import '../crud/system/system_billing_screen.dart';
import '../crud/system/system_business_screen.dart';
import '../crud/system/system_contact_screen.dart';
import '../crud/system/system_storage_screen.dart';
import '../crud/system/xero_integration_screen.dart';
import '../crud/todo/list_todo_screen.dart';
import '../crud/tool/list_tool_screen.dart';
import '../error.dart';
import '../integrations/booking_request_list_screen.dart';
import '../invoicing/list_invoice_screen.dart';
import '../invoicing/yet_to_be_invoice.dart';
import '../quoting/list_quote_screen.dart';
import '../scheduling/schedule_page.dart';
import '../scheduling/today/today_page.dart';
import '../task_items/list_packing_screen.dart';
import '../task_items/list_shopping_screen.dart';
import '../tools/plasterboard/plaster_project_list_screen.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/media/full_screen_photo_view.dart';
import '../widgets/splash_screen.dart';
import '../wizard/setup_wizard.dart';
import 'dashboards/accounting/accounting_dashboard.dart';
import 'dashboards/backup/backup_dashboard.dart';
import 'dashboards/help/help_dashboard.dart';
import 'dashboards/integration/integration_dashboard.dart';
import 'dashboards/main/home_dashboard.dart';
import 'dashboards/settings/settings_dashboard.dart';
import 'dashboards/tools/tools_dashboard.dart';
import 'tab_shell.dart';

GoRouter createGoRouter(
  GlobalKey<NavigatorState> navigatorKey,
  AsyncContextCallback bootstrap,
) => GoRouter(
  navigatorKey: navigatorKey,
  observers: [routeObserver], // so we can refresh the dashboard when
  // we pop back to it.
  debugLogDiagnostics: true,
  onException: (context, state, router) {
    if (state.uri.path == '/xero/auth_complete') {
      return;
    }
    HMBToast.error('Route Error: ${state.error}');
  },
  redirect: (context, state) {
    // If the deep link is the Xero OAuth callback, do not change
    // the current route.
    if (state.uri.path == '/xero/auth_complete') {
      // GoRouter may receive the app link before the auth handler consumes it.
      // Send the app back to the normal entry route and let XeroAuth finish
      // the code exchange from the deep-link stream.
      return '/';
    }

    // No other redirection.
    return null;
  },
  routes: [
    // '/' is used on startup and for deeplinking
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(bootstrap: bootstrap),
    ),

    // 2) Error screen route
    GoRoute(
      path: '/error',
      builder: (context, state) {
        final errorMessage = state.extra as String? ?? 'Unknown Error';
        return ErrorScreen(errorMessage: errorMessage);
      },
    ),

    // Tabbed navigation shell for the 5 main tabs.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          TabShell(navigationShell: navigationShell),
      branches: [
        // Tab 0: Jobs
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home/jobs',
              builder: (_, _) => const JobListScreen(),
            ),
          ],
        ),
        // Tab 1: Customers
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home/customers',
              builder: (_, _) => const CustomerListScreen(),
            ),
          ],
        ),
        // Tab 2: Dashboard (center, default)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const MainDashboardPage(),
              routes: _nonTabRoutes(),
            ),
          ],
        ),
        // Tab 3: Invoices
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home/accounting/invoices',
              builder: (_, _) => const InvoiceListScreen(),
            ),
          ],
        ),
        // Tab 4: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home/settings',
              builder: (_, _) => const SettingsDashboardPage(),
              routes: settingRoutes(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/photo_viewer',
      builder: (context, state) {
        final args = state.extra! as Map<String, String>;
        final imagePath = args['imagePath']!;
        final taskName = args['taskName']!;
        final comment = args['comment']!;
        return FullScreenPhotoViewer(
          imagePath: imagePath,
          title: taskName,
          comment: comment,
        );
      },
    ),
  ],
);

/// Routes that appear under the /home branch but are NOT primary tabs.
/// These render inside the Dashboard tab's navigator.
List<GoRoute> _nonTabRoutes() => [
  GoRoute(
    path: 'todo',
    builder: (_, _) => const ToDoListScreen(),
  ),
  GoRoute(
    path: 'today',
    builder: (_, _) => const TodayPage(),
  ),
  GoRoute(
    path: 'booking_requests',
    builder: (_, _) => const BookingRequestListScreen(),
  ),
  GoRoute(
    path: 'help',
    builder: (_, _) => const HelpDashboardPage(),
    routes: helpRoutes(),
  ),
  GoRoute(
    path: 'schedule',
    builder: (_, _) => const SchedulePage(dialogMode: false),
  ),
  GoRoute(
    path: 'shopping',
    builder: (_, _) => const ShoppingScreen(),
  ),
  GoRoute(
    path: 'packing',
    builder: (_, _) => const PackingScreen(),
  ),
  GoRoute(
    path: 'accounting',
    builder: (_, _) => const AccountingDashboardPage(),
    routes: accountingRoutes(),
  ),
  GoRoute(
    path: 'suppliers',
    builder: (_, _) => const SupplierListScreen(),
  ),
  GoRoute(
    path: 'tools',
    builder: (_, _) => const ToolsDashboardPage(),
  ),
  GoRoute(
    path: 'tools/inventory',
    builder: (_, _) => const ToolListScreen(),
  ),
  GoRoute(
    path: 'tools/plasterboard',
    builder: (_, _) => const PlasterProjectListScreen(),
  ),
  GoRoute(
    path: 'manufacturers',
    builder: (_, _) => const ManufacturerListScreen(),
  ),
  GoRoute(
    path: 'backup',
    builder: (_, _) => const BackupDashboardPage(),
    routes: backupRoutes(),
  ),
];

// 4) All other routes directly from the top level:
List<GoRoute> accountingRoutes() => [
  GoRoute(
    path: 'quotes',
    builder: (_, _) => const QuoteListScreen(),
  ),
  GoRoute(
    path: 'invoices',
    builder: (_, _) => const InvoiceListScreen(),
  ),
  GoRoute(
    path: 'to_be_invoiced',
    builder: (_, _) => YetToBeInvoicedScreen(),
  ),
  GoRoute(
    path: 'estimator',
    builder: (_, _) => const JobEstimatesListScreen(),
  ),
  GoRoute(
    path: 'milestones',
    builder: (_, _) => const ListMilestoneScreen(),
  ),
  GoRoute(
    path: 'receipts',
    builder: (_, _) => const ReceiptListScreen(),
  ),
];

/// Setting Dashboard Route
List<GoRoute> settingRoutes() => [
  GoRoute(
    path: 'ai',
    builder: (_, _) => const AiSettingsScreen(),
  ),
  GoRoute(
    path: 'appearance',
    builder: (_, _) => const AppearanceScreen(),
  ),
  GoRoute(
    path: 'sms_templates',
    builder: (_, _) => const MessageTemplateListScreen(),
  ),
  GoRoute(
    path: 'business',
    builder: (_, _) => const SystemBusinessScreen(),
  ),
  GoRoute(
    path: 'billing',
    builder: (_, _) => const SystemBillingScreen(),
  ),
  GoRoute(
    path: 'storage',
    builder: (_, _) => const SystemStorageScreen(),
  ),
  GoRoute(
    path: 'contact',
    builder: (_, _) => const SystemContactInformationScreen(),
  ),
  GoRoute(
    path: 'integrations',
    builder: (_, _) => const IntegrationDashboardPage(),
    routes: [
      GoRoute(
        path: 'ihserver',
        builder: (_, _) => const IhServerIntegrationScreen(),
      ),
      GoRoute(
        path: 'chatgpt',
        builder: (_, _) => const ChatGptIntegrationScreen(),
      ),
      GoRoute(
        path: 'xero',
        builder: (_, _) => const XeroIntegrationScreen(),
      ),
    ],
  ),
  GoRoute(
    path: 'wizard',
    builder: (context, state) {
      final fromSettings = state.extra as bool? ?? false;
      return SetupWizard(launchedFromSettings: fromSettings);
    },
  ),
];

List<GoRoute> helpRoutes() => [
  GoRoute(
    path: 'about',
    builder: (_, _) => const AboutScreen(),
  ),
];

List<GoRoute> backupRoutes() => [
  GoRoute(
    path: 'google/backup',
    builder: (_, _) => const GoogleDriveBackupScreen(),
  ),
  GoRoute(
    path: 'google/restore',
    builder: (_, _) => const GoogleDriveBackupScreen(restoreOnly: true),
  ),
  GoRoute(
    path: 'local/backup',
    builder: (_, _) => const LocalBackupScreen(),
  ),
];

/// A global RouteObserver that you can attach to GoRouter
final routeObserver = RouteObserver<ModalRoute<void>>();
