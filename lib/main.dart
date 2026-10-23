// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

import 'providers/auth_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/gold_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/release_provider.dart';
import 'providers/report_provider.dart';
import 'providers/user_provider.dart';

// ============================================================================
// AUTHENTICATION
// ============================================================================

import 'screens/auth/admin_registration_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/startup_screen.dart';

// ============================================================================
// DASHBOARD
// ============================================================================

import 'screens/dashboard/dashboard_screen.dart';

// ============================================================================
// CUSTOMERS
// ============================================================================

import 'screens/customers/customer_list_screen.dart';
import 'screens/customers/new_customer_screen.dart';

// ============================================================================
// GOLD
// ============================================================================

import 'screens/gold/gold_inventory_screen.dart';

// ============================================================================
// LOANS
// ============================================================================

import 'screens/loans/close_loan_screen.dart';
import 'screens/loans/create_additional_loan_screen.dart';
import 'screens/loans/create_new_loan_screen.dart';
import 'screens/loans/loan_list_screen.dart';

// ============================================================================
// PAYMENTS
// ============================================================================

import 'screens/payments/payment_history_screen.dart';
import 'screens/payments/payment_screen.dart';

// ============================================================================
// RECEIPTS
// ============================================================================

import 'screens/receipts/receipt_view_screen.dart';

// ============================================================================
// RELEASES
// ============================================================================

import 'screens/releases/partial_release_screen.dart';
import 'screens/releases/release_history_screen.dart';

// ============================================================================
// REPORTS
// ============================================================================

import 'screens/reports/reports_screen.dart';

// ============================================================================
// SETTINGS
// ============================================================================

import 'screens/settings/settings_screen.dart';
import 'screens/settings/user_management_screen.dart';

// ============================================================================
// RESPONSIVE LAYOUT
// ============================================================================

import 'widgets/responsive_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const GoldPawnERPApp(),
  );
}

// ============================================================================
// APPLICATION
// ============================================================================

class GoldPawnERPApp extends StatelessWidget {
  const GoldPawnERPApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        // ================================================================
        // AUTH
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),

        // ================================================================
        // DASHBOARD
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
        ),

        // ================================================================
        // CUSTOMER
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => CustomerProvider(),
        ),

        // ================================================================
        // GOLD
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => GoldProvider(),
        ),

        // ================================================================
        // LOAN
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => LoanProvider(),
        ),

        // ================================================================
        // PAYMENT
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => PaymentProvider(),
        ),

        // ================================================================
        // RELEASE
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => ReleaseProvider(),
        ),

        // ================================================================
        // REPORT
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => ReportProvider(),
        ),

        // ================================================================
        // USER MANAGEMENT
        // ================================================================

        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
      ],

      child: MaterialApp(
        title: 'Gold & Silver Pawn Loan ERP',

        debugShowCheckedModeBanner: false,

        theme: AppTheme.lightTheme,

        // ============================================================
        // FIRST SCREEN
        // ============================================================
        //
        // Opens the Animated 5-second SplashScreen on app launch.
        //
        // ============================================================

        home: const SplashScreen(),

        // ============================================================
        // APPLICATION ROUTES
        // ============================================================

        routes: {
          '/splash': (context) => const SplashScreen(),
          '/main': (context) => const MainScreen(),
          '/login': (context) => const LoginScreen(),
          '/startup': (context) => const StartupScreen(),
          '/admin_registration': (context) => const AdminRegistrationScreen(),
        },
      ),
    );
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
  });

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  // ==========================================================================
  // CURRENT TAB
  // ==========================================================================

  int _currentTabIndex = 0;

  // ==========================================================================
  // PAGE TITLES
  // ==========================================================================

  final List<String> _titles = [
    'ERP Dashboard & KPIs',
    'Customer Management',
    'Pawn Loan Management',
    'Payment & Collection Ledger',
    'Gold Collateral Inventory',
    'Gold Release Operations',
    'Official A4 Receipts',
    'Financial Reports & Analytics',
    'ERP Settings & DB Config',
    'User Management',
  ];

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  bool _canAccessTab(int tab) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return false;
    if (user['role'] == 'ADMIN' || user['role'] == 'SUPER_ADMIN') return true;

    switch (tab) {
      case 0:
        return auth.hasPermission('dashboard.view');
      case 1:
        return auth.hasPermission('customer.view');
      case 2:
        return auth.hasPermission('loan.view');
      case 3:
        return auth.hasPermission('payment.view');
      case 4:
        return auth.hasPermission('gold.view');
      case 5:
        return auth.hasPermission('release.view');
      case 6:
        return auth.hasPermission('receipt.view');
      case 7:
        return auth.hasPermission('report.view');
      case 8:
        return auth.hasPermission('settings.view');
      case 9:
        return auth.hasPermission('user.view') || auth.hasPermission('user.manage_permissions');
      default:
        return false;
    }
  }

  void _handleNavigation(
    int targetTab, {
    Map<String, dynamic>? initialParams,
  }) {
    if (targetTab < 0 || targetTab >= _titles.length) {
      return;
    }

    if (!_canAccessTab(targetTab)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: You do not have permission to view this module. Please contact the administrator.',
          ),
          backgroundColor: AppTheme.statusDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _currentTabIndex = targetTab;
    });

    if (initialParams == null) {
      return;
    }

    if (!initialParams.containsKey('action')) {
      return;
    }

    final action =
        initialParams['action'];

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        // ================================================================
        // NEW CUSTOMER
        // ================================================================

        if (action == 'new_customer') {
          showResponsiveDialog(context: context, child: const NewCustomerScreen());
        } else if (action == 'new_loan') {
          showResponsiveDialog(context: context, child: const CreateNewLoanScreen());
        } else if (action == 'additional_loan') {
          showResponsiveDialog(context: context, child: const CreateAdditionalLoanScreen());
        } else if (action == 'new_payment') {
          showResponsiveDialog(context: context, child: const PaymentScreen());
        } else if (action == 'partial_release') {
          showResponsiveDialog(context: context, child: const PartialReleaseScreen());
        } else if (action == 'close_loan' && initialParams.containsKey('loan_id')) {
          final loanId = initialParams['loan_id'];
          showResponsiveDialog(context: context, child: CloseLoanScreen(loanId: loanId));
        } else if (action == 'user_management') {
          setState(() {
            _currentTabIndex = 9;
          });
        }
      },
    );
  }

  // ==========================================================================
  // BODY
  // ==========================================================================

  Widget _buildBody() {
    if (!_canAccessTab(_currentTabIndex)) {
      for (int i = 0; i < _titles.length; i++) {
        if (_canAccessTab(i)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentTabIndex = i;
              });
            }
          });
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.goldPrimary),
          );
        }
      }
      return _buildAccessDeniedScreen();
    }

    switch (_currentTabIndex) {
      case 0:
        return DashboardScreen(onNavigate: _handleNavigation);
      case 1:
        return CustomerListScreen(onNavigate: _handleNavigation);
      case 2:
        return LoanListScreen(onNavigate: _handleNavigation);
      case 3:
        return PaymentHistoryScreen(onNavigate: _handleNavigation);
      case 4:
        return GoldInventoryScreen(onNavigate: _handleNavigation);
      case 5:
        return ReleaseHistoryScreen(onNavigate: _handleNavigation);
      case 6:
        return const ReceiptViewScreen();
      case 7:
        return ReportsScreen(onNavigate: _handleNavigation);
      case 8:
        return const SettingsScreen();
      case 9:
        return const UserManagementScreen();
      default:
        return DashboardScreen(onNavigate: _handleNavigation);
    }
  }

  Widget _buildAccessDeniedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppTheme.statusDanger),
            const SizedBox(height: 16),
            const Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to access any ERP modules.\nPlease contact the administrator to grant access to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.silverDark),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen(targetRoute: '/login')),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldPrimary,
                foregroundColor: AppTheme.darkNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('LOGOUT & SWITCH ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      selectedIndex:
          _currentTabIndex,

      onIndexChanged: (idx) {
        if (idx < 0 ||
            idx >= _titles.length) {
          return;
        }

        setState(() {
          _currentTabIndex = idx;
        });
      },

      title:
          _titles[_currentTabIndex],

      child: _buildBody(),
    );
  }
}