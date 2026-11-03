// lib/widgets/responsive_layout.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/gold_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/release_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../screens/auth/splash_screen.dart';

Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) async {
  return await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x80000000),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    ),
  );
}

// ============================================================================
// INDIAN STANDARD TIME (IST, UTC+05:30) CLOCK & DATE WIDGET
// ============================================================================

class IndianClockWidget extends StatefulWidget {
  final bool isMobile;
  const IndianClockWidget({super.key, this.isMobile = false});

  @override
  State<IndianClockWidget> createState() => _IndianClockWidgetState();
}

class _IndianClockWidgetState extends State<IndianClockWidget> {
  Timer? _timer;
  late DateTime _istNow;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      // Calculate Indian Standard Time (UTC+05:30)
      _istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(_istNow);
    final dateStr = DateFormat('dd MMM yyyy').format(_istNow);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeStr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: widget.isMobile ? 11.5 : 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkNavy,
          ),
        ),
        Text(
          dateStr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: widget.isMobile ? 9.5 : 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.silverDark,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// RESPONSIVE LAYOUT WIDGET
// ============================================================================

class ResponsiveLayout extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget child;
  final String title;
  final List<Widget>? actions;

  const ResponsiveLayout({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.child,
    required this.title,
    this.actions,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  // ==========================================================================
  // GLOBAL SEARCH
  // ==========================================================================

  final TextEditingController _globalSearchCtrl = TextEditingController();

  // ==========================================================================
  // NAVIGATION ITEMS
  // ==========================================================================

  final List<Map<String, dynamic>> _navItems = [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard,
      'permission': 'DASHBOARD_VIEW',
    },
    {
      'title': 'Customers',
      'icon': Icons.people_alt_outlined,
      'activeIcon': Icons.people_alt,
      'permission': 'CUSTOMER_VIEW',
    },
    {
      'title': 'Pawn Loans',
      'icon': Icons.monetization_on_outlined,
      'activeIcon': Icons.monetization_on,
      'permission': 'LOAN_VIEW',
    },
    {
      'title': 'Payments',
      'icon': Icons.payments_outlined,
      'activeIcon': Icons.payments,
      'permission': 'PAYMENT_VIEW',
    },
    {
      'title': 'Gold Items',
      'icon': Icons.diamond_outlined,
      'activeIcon': Icons.diamond,
      'permission': 'GOLD_VIEW',
    },
    {
      'title': 'Releases',
      'icon': Icons.lock_open_outlined,
      'activeIcon': Icons.lock_open,
      'permission': 'RELEASE_VIEW',
    },
    {
      'title': 'Receipts',
      'icon': Icons.receipt_long_outlined,
      'activeIcon': Icons.receipt_long,
      'permission': 'RECEIPT_VIEW',
    },
    {
      'title': 'Reports',
      'icon': Icons.bar_chart_outlined,
      'activeIcon': Icons.bar_chart,
      'permission': 'REPORT_VIEW',
    },
    {
      'title': 'Settings',
      'icon': Icons.settings_outlined,
      'activeIcon': Icons.settings,
      'permission': 'SETTINGS_VIEW',
    },
    {
      'title': 'User Management',
      'icon': Icons.manage_accounts_outlined,
      'activeIcon': Icons.manage_accounts,
      'permission': null,
    },
  ];

  // ==========================================================================
  // ROLE / NAVIGATION ACCESS
  // ==========================================================================

  Map<String, dynamic>? _loggedInUser(BuildContext context) {
    final authUser = context.read<AuthProvider>().currentUser;
    if (authUser != null) {
      return Map<String, dynamic>.from(authUser);
    }
    final apiUser = ApiService.currentUser;
    if (apiUser != null) {
      return Map<String, dynamic>.from(apiUser);
    }
    return null;
  }

  String _normalizeRole(dynamic value) {
    return value
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String? _getCurrentRole(BuildContext context) {
    final user = _loggedInUser(context);
    if (user == null) return null;

    final candidates = <dynamic>[
      user['role'],
      user['role_code'],
      user['role_name'],
      user['user_role'],
      user['userRole'],
      user['type'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final role = _normalizeRole(candidate);
      if (role.isNotEmpty) return role;
    }
    return null;
  }

  bool _isAdmin(BuildContext context) {
    return _getCurrentRole(context) == 'ADMIN';
  }

  bool _isUserManagementIndex(int index) {
    return index == 9;
  }

  String _normalizePermissionCode(dynamic value) {
    return value
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll('.', '_')
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Set<String> _currentPermissionCodes(BuildContext context) {
    final user = _loggedInUser(context);
    if (user == null) return <String>{};

    final codes = <String>{};
    final rawCodes = user['permission_codes'];

    if (rawCodes is List) {
      for (final code in rawCodes) {
        final normalized = _normalizePermissionCode(code);
        if (normalized.isNotEmpty) {
          codes.add(normalized);
        }
      }
    }

    final rawPermissions = user['permissions'];
    if (rawPermissions is List) {
      for (final item in rawPermissions) {
        if (item is! Map) continue;
        final assigned = item['assigned'] == true ||
            item['allowed'] == true ||
            item['is_assigned'] == true ||
            item['selected'] == true;

        if (!assigned) continue;

        final code = item['permission_code'] ?? item['code'] ?? item['permission_key'];
        final normalized = _normalizePermissionCode(code);
        if (normalized.isNotEmpty) {
          codes.add(normalized);
        }
      }
    }
    return codes;
  }

  bool _hasPermission(BuildContext context, String? permission) {
    if (_isAdmin(context)) return true;
    if (permission == null || permission.trim().isEmpty) return false;

    final required = _normalizePermissionCode(permission);
    return _currentPermissionCodes(context).contains(required);
  }

  bool _canOpenNavItem(BuildContext context, int index, Map<String, dynamic> item) {
    if (_isUserManagementIndex(index)) {
      return _isAdmin(context);
    }
    return _hasPermission(context, item['permission']);
  }

  void _triggerGlobalSearch(String query) {
    final clean = query.trim();

    try {
      context.read<CustomerProvider>().fetchCustomers(clean.isEmpty ? null : clean);
    } catch (_) {}

    try {
      context.read<LoanProvider>().fetchLoans(search: clean.isEmpty ? null : clean);
    } catch (_) {}

    try {
      context.read<GoldProvider>().fetchGoldItems(search: clean.isEmpty ? null : clean);
    } catch (_) {}

    try {
      context.read<PaymentProvider>().fetchPayments(search: clean.isEmpty ? null : clean);
    } catch (_) {}

    try {
      context.read<ReleaseProvider>().fetchReleases(search: clean.isEmpty ? null : clean);
    } catch (_) {}

    try {
      context.read<UserProvider>().fetchUsers(search: clean.isEmpty ? null : clean);
    } catch (_) {}

    if (widget.selectedIndex == 0 && clean.isNotEmpty) {
      final isLoanQuery = clean.toUpperCase().startsWith('PL-') ||
          clean.toUpperCase().startsWith('LCK-') ||
          clean.toUpperCase().startsWith('EX-') ||
          clean.toUpperCase().startsWith('RCP-');
      widget.onIndexChanged(isLoanQuery ? 2 : 1);
    }
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index < 0 || index >= _navItems.length) return;

    final item = _navItems[index];
    if (!_canOpenNavItem(context, index, item)) {
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
    widget.onIndexChanged(index);
  }

  List<MapEntry<int, Map<String, dynamic>>> _visibleNavItems(BuildContext context) {
    return _navItems.asMap().entries.where((entry) {
      return _canOpenNavItem(context, entry.key, entry.value);
    }).toList();
  }

  int _visibleSelectedIndex(BuildContext context, List<MapEntry<int, Map<String, dynamic>>> items) {
    final position = items.indexWhere((entry) => entry.key == widget.selectedIndex);
    return position >= 0 ? position : 0;
  }

  @override
  void dispose() {
    _globalSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isDesktop = width >= AppConstants.desktopBreakpoint;
    final isLaptop = width >= AppConstants.tabletBreakpoint && width < AppConstants.desktopBreakpoint;
    final isTablet = width >= AppConstants.mobileBreakpoint && width < AppConstants.tabletBreakpoint;
    final isMobile = width < AppConstants.mobileBreakpoint;

    if (_isUserManagementIndex(widget.selectedIndex) && !_isAdmin(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onIndexChanged(0);
      });
    }

    if (isDesktop || isLaptop) {
      return _buildDesktopLayout(context);
    }
    if (isTablet) {
      return _buildTabletLayout(context);
    }
    if (isMobile) {
      return _buildMobileLayout(context);
    }
    return _buildDesktopLayout(context);
  }

  // ==========================================================================
  // DESKTOP / LAPTOP
  // ==========================================================================

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // LEFT SIDEBAR
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color(0xFF0C101B),
              border: Border(
                right: BorderSide(
                  color: Color(0xFF1E2433),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // BRAND HEADER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF1E2433),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.goldPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            '🕉️',
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JAIN GOLD & PAWN',
                              style: GoogleFonts.cinzel(
                                color: AppTheme.goldPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.0,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Jain Gold & Pawn Shop',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // NAVIGATION
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    itemCount: _visibleNavItems(context).length,
                    itemBuilder: (context, visibleIndex) {
                      final entry = _visibleNavItems(context)[visibleIndex];
                      final originalIndex = entry.key;
                      final item = entry.value;
                      final isSelected = widget.selectedIndex == originalIndex;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF262B38) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.goldPrimary.withValues(alpha: 0.50),
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handleNavigation(context, originalIndex),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item['activeIcon'] : item['icon'],
                                  color: isSelected ? AppTheme.goldPrimary : const Color(0xFF94A3B8),
                                  size: 21,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item['title'],
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // LOGOUT
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFF1E2433),
                        width: 1,
                      ),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _logout(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Color(0xFFEF4444), size: 22),
                          SizedBox(width: 14),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // MAIN WORK AREA
          Expanded(
            child: Column(
              children: [
                // TOP HEADER
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: AppTheme.silverBorder,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(width: 32),

                      // GLOBAL SEARCH
                      Expanded(
                        child: Container(
                          height: 38,
                          constraints: const BoxConstraints(maxWidth: 380),
                          decoration: BoxDecoration(
                            color: AppTheme.silverLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.silverBorder),
                          ),
                          child: TextField(
                            controller: _globalSearchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search customer, loan no, mobile...',
                              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.silverDark),
                              suffixIcon: _globalSearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.silverDark),
                                      onPressed: () {
                                        _globalSearchCtrl.clear();
                                        _triggerGlobalSearch('');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (value) {
                              _triggerGlobalSearch(value);
                              setState(() {});
                            },
                          ),
                        ),
                      ),

                      const Spacer(),

                      // REPLACED REFRESH ICON WITH LIVE IST TIME & DATE DISPLAY
                      const IndianClockWidget(),

                      const SizedBox(width: 16),

                      if (widget.actions != null) ...widget.actions!,

                      const SizedBox(width: 12),

                      // PROFILE
                      _buildProfileBadge(context),
                    ],
                  ),
                ),

                // CONTENT
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBadge(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final String role = ((user?['role']?.toString().trim().isNotEmpty == true)
        ? user!['role'].toString().trim()
        : 'ADMIN').toUpperCase();

    final String badgeLetter = role.isNotEmpty ? role[0] : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.goldPrimary.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.goldPrimary,
            child: Text(
              badgeLetter,
              style: const TextStyle(
                color: AppTheme.darkNavy,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            role,
            style: const TextStyle(
              color: AppTheme.goldPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TABLET
  // ==========================================================================

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          const Center(child: IndianClockWidget(isMobile: true)),
          const SizedBox(width: 12),
          if (widget.actions != null && widget.actions!.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actions!,
                ),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          Builder(
            builder: (navContext) {
              final visibleItems = _visibleNavItems(navContext);

              return NavigationRail(
                backgroundColor: AppTheme.darkNavy,
                selectedIndex: _visibleSelectedIndex(navContext, visibleItems),
                onDestinationSelected: (visibleIndex) {
                  final originalIndex = visibleItems[visibleIndex].key;
                  _handleNavigation(navContext, originalIndex);
                },
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: const IconThemeData(color: AppTheme.goldPrimary),
                unselectedIconTheme: const IconThemeData(color: AppTheme.silverPrimary),
                selectedLabelTextStyle: const TextStyle(
                  color: AppTheme.goldPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelTextStyle: const TextStyle(
                  color: AppTheme.silverPrimary,
                  fontSize: 10,
                ),
                destinations: visibleItems.map((entry) {
                  final item = entry.value;
                  return NavigationRailDestination(
                    icon: Icon(item['icon']),
                    selectedIcon: Icon(item['activeIcon']),
                    label: Text(item['title']),
                  );
                }).toList(),
              );
            },
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppTheme.silverBorder),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ==========================================================================
  // MOBILE
  // ==========================================================================

  Widget _buildMobileLayout(BuildContext context) {
    final bottomNavItems = _navItems.asMap().entries.where((entry) {
      const mobileIndices = <int>[0, 1, 2, 3];
      return mobileIndices.contains(entry.key) && _canOpenNavItem(context, entry.key, entry.value);
    }).toList();

    final bottomCurrentPosition = bottomNavItems.indexWhere(
      (entry) => entry.key == widget.selectedIndex,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        actions: [
          const Center(child: IndianClockWidget(isMobile: true)),
          const SizedBox(width: 8),
          if (widget.actions != null && widget.actions!.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actions!,
                ),
              ),
            ),
        ],
      ),

      // COMPACT MOBILE DRAWER (NO SCROLLING ON STANDARD SIZES)
      drawer: Drawer(
        width: 250,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryShort = constraints.maxHeight < 500;

              final drawerBody = Column(
                children: [
                  // BRAND HEADER
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: AppTheme.darkNavy,
                    child: Row(
                      children: [
                        const Text('🕉️', style: TextStyle(fontSize: 22, height: 1.0)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'JAIN GOLD & PAWN',
                                style: GoogleFonts.cinzel(
                                  color: AppTheme.goldPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Text(
                                'Jain Gold & Pawn Shop',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // USER PROFILE BADGE
                  _buildMobileProfile(context),

                  const Divider(height: 1, thickness: 1),

                  // MENU ITEMS COMPACT COLUMN
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _visibleNavItems(context).map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final isSelected = widget.selectedIndex == idx;

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            leading: Icon(
                              isSelected ? item['activeIcon'] : item['icon'],
                              color: isSelected ? AppTheme.goldDark : AppTheme.darkNavy,
                              size: 18,
                            ),
                            title: Text(
                              item['title'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppTheme.goldDark : AppTheme.darkNavy,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppTheme.goldLight.withValues(alpha: 0.3),
                            onTap: () {
                              Navigator.pop(context);
                              _handleNavigation(context, idx);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const Divider(height: 1, thickness: 1),

                  // LOGOUT
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: const Icon(Icons.logout, color: AppTheme.statusDanger, size: 18),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: AppTheme.statusDanger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => _logout(context),
                    ),
                  ),
                ],
              );

              if (isVeryShort) {
                return SingleChildScrollView(child: drawerBody);
              }

              return drawerBody;
            },
          ),
        ),
      ),

      body: widget.child,

      bottomNavigationBar: bottomNavItems.length >= 2
          ? BottomNavigationBar(
              currentIndex: (bottomCurrentPosition >= 0 && bottomCurrentPosition < bottomNavItems.length)
                  ? bottomCurrentPosition
                  : 0,
              type: BottomNavigationBarType.fixed,
              onTap: (visibleIndex) {
                if (visibleIndex < 0 || visibleIndex >= bottomNavItems.length) return;
                _handleNavigation(context, bottomNavItems[visibleIndex].key);
              },
              items: bottomNavItems.map((entry) {
                final item = entry.value;
                return BottomNavigationBarItem(
                  icon: Icon(item['icon']),
                  activeIcon: Icon(item['activeIcon']),
                  label: item['title'].toString(),
                );
              }).toList(),
            )
          : null,
    );
  }

  Widget _buildMobileProfile(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    final String role = ((user?['role']?.toString().trim().isNotEmpty == true)
        ? user!['role'].toString().trim()
        : 'ADMIN').toUpperCase();

    final String badgeLetter = role.isNotEmpty ? role[0] : 'A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.silverLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.silverBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.goldPrimary,
            child: Text(
              badgeLetter,
              style: const TextStyle(
                color: AppTheme.darkNavy,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            role,
            style: const TextStyle(
              color: AppTheme.darkNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);

    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
      navigator.pop();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!context.mounted) return;

    context.read<AuthProvider>().logout();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen(targetRoute: '/login')),
      (route) => false,
    );
  }
}
