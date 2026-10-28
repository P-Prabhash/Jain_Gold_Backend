import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/success_dialog.dart';

const Color kPageBackground = Color(0xFFF5F6F8);

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends State<UserManagementScreen> {

  final TextEditingController _searchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();

      if (!_isLoggedInAdmin(auth)) {
        _showMessage(
          context,
          'Only ADMIN users can access User Management.',
        );

        Navigator.of(context).pop();
        return;
      }

      final provider = context.read<UserProvider>();

      provider.fetchUsers(
        page: 1,
        limit: 25,
      );

      provider.fetchRoles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_isLoggedInAdmin(auth)) {
      return const Scaffold(
        backgroundColor: kPageBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Access denied.\n\nOnly ADMIN users can access User Management.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Consumer<UserProvider>(
      builder: (
        context,
        provider,
        child,
      ) {
        final width =
            MediaQuery.of(context).size.width;

        final bool isMobile = width < 650;

        final bool isTablet =
            width >= 650 && width < 1100;

        return Scaffold(
          backgroundColor: kPageBackground,

          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? 10
                    : isTablet
                        ? 14
                        : 20,
                vertical: isMobile
                    ? 10
                    : isTablet
                        ? 14
                        : 20,
              ),

              child: Column(
                children: [
                  _buildHeader(
                    context,
                    provider,
                    isMobile,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildStatistics(
                    provider,
                    isMobile,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Expanded(
                    child: isMobile
                        ? _buildMobileLayout(
                            context,
                            provider,
                          )
                        : _buildDesktopLayout(
                            context,
                            provider,
                            isTablet,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    BuildContext context,
    UserProvider provider,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isMobile ? 15 : 20,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: AppTheme.goldPrimary
              .withValues(alpha: 0.25),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: isMobile ? 46 : 54,
            height: isMobile ? 46 : 54,

            decoration: BoxDecoration(
              color: AppTheme.darkNavy,
              borderRadius:
                  BorderRadius.circular(13),
            ),

            child: const Icon(
              Icons
                  .admin_panel_settings_outlined,
              color:
                  AppTheme.goldPrimary,
              size: 28,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'User Management',

                  style: TextStyle(
                    fontSize:
                        isMobile ? 18 : 23,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        AppTheme.darkNavy,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'Manage users, roles and permissions',

                  style: TextStyle(
                    fontSize:
                        isMobile ? 10 : 12,
                    color:
                        AppTheme.silverDark,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (isMobile)
            IconButton(
              tooltip: 'Add User',
              onPressed: () {
                _showAddUserDialog(context);
              },
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: AppTheme.goldPrimary,
              ),
              icon: const Icon(
                Icons.person_add_alt_1,
                size: 20,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                _showAddUserDialog(context);
              },

              icon: const Icon(
                Icons.person_add_alt_1,
                size: 18,
              ),

              label: const Text(
                'ADD USER',
              ),

              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics(
    UserProvider provider,
    bool isMobile,
  ) {
    final users = provider.users;

    int active = 0;
    int inactive = 0;
    int locked = 0;

    for (final user in users) {
      final status =
          user['status']
              ?.toString()
              .toUpperCase();

      if (status == 'ACTIVE') {
        active++;
      } else if (status == 'INACTIVE') {
        inactive++;
      }

      if (status == 'LOCKED' ||
          user['locked_until'] != null) {
        locked++;
      }
    }

    final cards = [
      _statCard(
        'TOTAL USERS',
        provider.totalRecords,
        Icons.people_outline,
        AppTheme.darkNavy,
      ),

      _statCard(
        'ACTIVE',
        active,
        Icons.check_circle_outline,
        Colors.green.shade700,
      ),

      _statCard(
        'INACTIVE',
        inactive,
        Icons.pause_circle_outline,
        Colors.orange.shade700,
      ),

      _statCard(
        'LOCKED',
        locked,
        Icons.lock_outline,
        Colors.red.shade700,
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 76,
        ),
        itemBuilder: (_, index) => cards[index],
      );
    }

    return Row(
      children: cards
          .map(
            (card) => Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 8,
                ),
                child: card,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _statCard(
    String title,
    int value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(14),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color: Colors.grey
              .withValues(alpha: 0.15),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,

            decoration:
                BoxDecoration(
              color:
                  iconColor.withValues(alpha: 
                0.09,
              ),

              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              mainAxisAlignment:
                  MainAxisAlignment
                      .center,

              children: [
                Text(
                  title,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        AppTheme
                            .silverDark,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  '$value',

                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        AppTheme
                            .darkNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP / TABLET
  // ============================================================

  Widget _buildDesktopLayout(
    BuildContext context,
    UserProvider provider,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          isTablet ? 14 : 16,
        ),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.15),
        ),
      ),

      clipBehavior: Clip.antiAlias,

      child: Column(
        children: [
          _buildFilters(
            context,
            provider,
            false,
            tablet: isTablet,
          ),

          const Divider(height: 1),

          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _buildUserTable(
                    context,
                    provider,
                    isTablet,
                  ),
          ),

          _buildPagination(provider),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _buildMobileLayout(
    BuildContext context,
    UserProvider provider,
  ) {
    return ListView(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _buildFilters(
          context,
          provider,
          true,
        ),

        const SizedBox(height: 10),

        if (provider.isLoading)
          const SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.users.isEmpty)
          SizedBox(
            height: 220,
            child: _emptyUsers(),
          )
        else
          ...provider.users.map(
            (user) => _buildUserCard(
              context,
              provider,
              user,
            ),
          ),

        _buildPagination(
          provider,
          mobile: true,
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(
    BuildContext context,
    UserProvider provider,
    bool mobile, {
    bool tablet = false,
  }) {
    if (mobile) {
      return Container(
        padding:
            const EdgeInsets.all(12),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border: Border.all(
            color: Colors.grey
                .withValues(alpha: 0.15),
          ),
        ),

        child: Column(
          children: [
            _searchField(
              provider,
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _statusDropdown(
                    provider,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child:
                      _roleDropdown(
                    provider,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            SizedBox(
              width:
                  double.infinity,

              child:
                  OutlinedButton.icon(
                onPressed: () {
                  _searchController
                      .clear();

                  provider
                      .clearFilters();
                },

                icon:
                    const Icon(
                  Icons.clear_all,
                  size: 17,
                ),

                label:
                    const Text(
                  'CLEAR FILTERS',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (tablet) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchField(provider),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statusDropdown(provider),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _roleDropdown(provider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                icon: const Icon(
                  Icons.clear_all,
                  size: 17,
                ),
                label: const Text(
                  'CLEAR FILTERS',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.all(14),

      child: Row(
        children: [
          Expanded(
            child: _searchField(provider),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 145,
            child:
                _statusDropdown(
              provider,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          SizedBox(
            width: 145,
            child:
                _roleDropdown(
              provider,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          OutlinedButton.icon(
            onPressed: () {
              _searchController
                  .clear();

              provider
                  .clearFilters();
            },

            icon:
                const Icon(
              Icons.clear_all,
              size: 17,
            ),

            label:
                const Text(
              'CLEAR',
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(
    UserProvider provider,
  ) {
    return TextField(
      controller:
          _searchController,

      onSubmitted:
          provider.searchUsers,

      decoration:
          InputDecoration(
        hintText:
            'Search name, username, mobile, employee ID...',

        prefixIcon:
            const Icon(
          Icons.search,
        ),

        filled: true,

        fillColor:
            kPageBackground,

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            10,
          ),

          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  Widget _statusDropdown(
    UserProvider provider,
  ) {
    return DropdownButtonFormField<
        String>(
      isExpanded: true,
      initialValue:
          provider.selectedStatus,

      decoration:
          const InputDecoration(
        labelText:
            'Status',

        contentPadding:
            EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),

      items: const [
        DropdownMenuItem(
          value: 'ALL',
          child:
              Text(
            'All Status',
          ),
        ),

        DropdownMenuItem(
          value: 'ACTIVE',
          child:
              Text(
            'Active',
          ),
        ),

        DropdownMenuItem(
          value: 'INACTIVE',
          child:
              Text(
            'Inactive',
          ),
        ),

        DropdownMenuItem(
          value: 'LOCKED',
          child:
              Text(
            'Locked',
          ),
        ),
      ],

      onChanged:
          (value) {
        if (value !=
            null) {
          provider
              .filterByStatus(
            value,
          );
        }
      },
    );
  }

  Widget _roleDropdown(
    UserProvider provider,
  ) {
    final roles = [
      'ALL',

      ...provider.roles
          .map(
            (role) =>
                role['role_name']
                    ?.toString() ??
                role['name']
                    ?.toString() ??
                '',
          )
          .where(
            (role) =>
                role.isNotEmpty,
          ),
    ].toSet().toList();

    return DropdownButtonFormField<
        String>(
      isExpanded: true,
      initialValue:
          roles.contains(
        provider.selectedRole,
      )
              ? provider.selectedRole
              : 'ALL',

      decoration:
          const InputDecoration(
        labelText:
            'Role',

        contentPadding:
            EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),

      items:
          roles.map(
        (role) =>
            DropdownMenuItem(
          value: role,

          child: Text(
            role == 'ALL'
                ? 'All Roles'
                : role,

            overflow:
                TextOverflow
                    .ellipsis,
          ),
        ),
      ).toList(),

      onChanged:
          (value) {
        if (value !=
            null) {
          provider
              .filterByRole(
            value,
          );
        }
      },
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildUserTable(
    BuildContext context,
    UserProvider provider,
    bool isTablet,
  ) {
    if (provider.users.isEmpty) {
      return _emptyUsers();
    }

    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,

      child: ConstrainedBox(
        constraints:
            BoxConstraints(
          minWidth:
              isTablet
                  ? 1080
                  : 1250,
        ),

        child:
            SingleChildScrollView(
          child: DataTable(
            headingRowHeight:
                52,

            dataRowMinHeight:
                66,

            dataRowMaxHeight:
                76,

            horizontalMargin:
                16,

            columnSpacing:
                isTablet
                    ? 18
                    : 20,

            headingRowColor:
                WidgetStateProperty
                    .all(
              kPageBackground,
            ),

            columns:
                const [
              DataColumn(
                label:
                    Text(
                  'USER',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'EMPLOYEE ID',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'CONTACT',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'ROLE',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'STATUS',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'LAST LOGIN',
                ),
              ),

              DataColumn(
                label:
                    Text(
                  'ACTIONS',
                ),
              ),
            ],

            rows:
                provider.users
                    .map(
              (user) {
                return DataRow(
                  cells: [
                    DataCell(
                      _userIdentity(
                        user,
                      ),
                    ),

                    DataCell(
                      Text(
                        _value(
                          user,
                          [
                            'employee_id',
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _value(
                          user,
                          [
                            'mobile',
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      _roleBadge(
                        _value(
                          user,
                          [
                            'role',
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      _statusBadge(
                        _value(
                          user,
                          [
                            'status',
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        _value(
                          user,
                          [
                            'last_login_at',
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      _actions(
                        context,
                        provider,
                        user,
                      ),
                    ),
                  ],
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE USER CARD
  // ============================================================

  Widget _buildUserCard(
    BuildContext context,
    UserProvider provider,
    Map<String, dynamic> user,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border: Border.all(
          color: Colors.grey
              .withValues(alpha: 0.15),
        ),
      ),

      child: Column(
        children: [
          Row(
            children: [
              _avatar(user),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    Text(
                      _value(
                        user,
                        [
                          'full_name',
                          'name',
                        ],
                      ),

                      maxLines: 1,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .w800,

                        fontSize:
                            14,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      '@${_value(user, [
                            'username',
                          ])}',

                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            AppTheme
                                .silverDark,
                      ),
                    ),
                  ],
                ),
              ),

              _statusBadge(
                _value(
                  user,
                  [
                    'status',
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          _infoRow(
            'Employee ID',
            _value(
              user,
              [
                'employee_id',
              ],
            ),
          ),

          _infoRow(
            'Mobile',
            _value(
              user,
              [
                'mobile',
              ],
            ),
          ),

          _infoRow(
            'Role',
            _value(
              user,
              [
                'role',
              ],
            ),
          ),

          _infoRow(
            'Last Login',
            _value(
              user,
              [
                'last_login_at',
              ],
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          _actions(
            context,
            provider,
            user,
            mobile: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _actions(
    BuildContext context,
    UserProvider provider,
    Map<String, dynamic> user, {
    bool mobile = false,
  }) {
    final userId =
        int.tryParse(
              '${user['id']}',
            ) ??
            0;

    final isAdmin =
        _value(
          user,
          [
            'role',
          ],
        ).toUpperCase() ==
        'ADMIN';

    if (mobile) {
      return Column(
        children: [
          // Row 1: Edit & Password Reset
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showEditUserDialog(
                      context,
                      user,
                    );
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'EDIT',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showResetPasswordDialog(
                      context,
                      provider,
                      userId,
                    );
                  },
                  icon: const Icon(
                    Icons.key_outlined,
                    size: 16,
                  ),
                  label: const Text(
                    'PASSWORD RESET',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Delete User (Full Width)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isAdmin
                  ? null
                  : () {
                      _showDeleteUserDialog(
                        context,
                        provider,
                        user,
                        userId,
                      );
                    },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
              ),
              label: Text(
                isAdmin ? 'MAIN ADMIN (PROTECTED)' : 'DELETE USER',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isAdmin ? Colors.grey : AppTheme.statusDanger,
                side: BorderSide(
                  color: isAdmin
                      ? AppTheme.silverBorder
                      : AppTheme.statusDanger.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Row 3: Manage Permissions / Admin Status (Full Width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isAdmin
                  ? null
                  : () {
                      _openPermissions(
                        context,
                        provider,
                        userId,
                      );
                    },
              icon: const Icon(
                Icons.shield_outlined,
                size: 18,
              ),
              label: Text(
                isAdmin ? 'ADMIN — FULL ACCESS' : 'MANAGE PERMISSIONS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        _actionButton(
          icon:
              Icons.edit_outlined,

          tooltip:
              'Edit User',

          onPressed: () {
            _showEditUserDialog(
              context,
              user,
            );
          },
        ),

        _actionButton(
          icon:
              Icons.key_outlined,

          tooltip:
              'Reset Password',

          onPressed: () {
            _showResetPasswordDialog(
              context,
              provider,
              userId,
            );
          },
        ),

        _actionButton(
          icon:
              Icons
                  .power_settings_new,

          tooltip:
              isAdmin
                  ? 'ADMIN account'
                  : 'Change Status',

          onPressed:
              isAdmin
                  ? null
                  : () {
                      _showStatusDialog(
                        context,
                        provider,
                        user,
                        userId,
                      );
                    },
        ),

        _actionButton(
          icon:
              Icons
                  .shield_outlined,

          tooltip:
              isAdmin
                  ? 'ADMIN has full access'
                  : 'Manage Permissions',

          onPressed:
              isAdmin
                  ? null
                  : () {
                      _openPermissions(
                        context,
                        provider,
                        userId,
                      );
                    },
        ),

        _actionButton(
          icon:
              Icons
                  .delete_outline,

          tooltip:
              isAdmin
                  ? 'Cannot delete main ADMIN'
                  : 'Delete User',

          color:
              isAdmin
                  ? Colors.grey
                  : AppTheme.statusDanger,

          onPressed:
              isAdmin
                  ? null
                  : () {
                      _showDeleteUserDialog(
                        context,
                        provider,
                        user,
                        userId,
                      );
                    },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback?
        onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,

      child:
          IconButton(
        onPressed:
            onPressed,

        icon:
            Icon(
          icon,
          size: 19,
        ),

        color:
            color ?? AppTheme.darkNavy,
      ),
    );
  }

  // ============================================================
  // OPEN PERMISSIONS
  // ============================================================

  Future<void> _openPermissions(
    BuildContext context,
    UserProvider provider,
    int userId,
  ) async {
    // First load the selected user's profile so the dialog header
    // can display the correct name, username and role.
    final userLoaded =
        await provider
            .fetchUserDetails(
      userId,
    );

    if (!context.mounted) {
      return;
    }

    if (!userLoaded) {
      _showMessage(
        context,
        provider.errorMessage ??
            'Unable to load selected user.',
      );

      return;
    }

    // IMPORTANT:
    // fetchRoles() also writes to the provider's permission catalogue.
    // Therefore it MUST run BEFORE fetchUserPermissions().
    //
    // The previous order was:
    //   fetchUserPermissions()
    //   fetchRoles()
    //
    // fetchRoles() then replaced permissionsGroupedByModule with its
    // own response, which caused the Manage Permissions dialog to show:
    //   "No permissions available."
    //
    // Correct order:
    //   1. Load roles.
    //   2. Load the selected user's COMPLETE permission catalogue last.
    //
    // The final permission state displayed by the dialog therefore
    // always comes from users/permissions.php.
    final rolesLoaded =
        await provider.fetchRoles();

    if (!context.mounted) {
      return;
    }

    if (!rolesLoaded) {
      _showMessage(
        context,
        provider.errorMessage ??
            'Unable to load roles.',
      );

      return;
    }

    final permissionsLoaded =
        await provider.fetchUserPermissions(
      userId,
    );

    if (!context.mounted) {
      return;
    }

    if (!permissionsLoaded) {
      _showMessage(
        context,
        provider.errorMessage ??
            'Unable to load permissions.',
      );

      return;
    }

    if (!context.mounted) {
      return;
    }

    showDialog(
      context: context,

      barrierDismissible:
          false,

      builder: (_) =>
          ChangeNotifierProvider
              .value(
        value: provider,

        child:
            const _PermissionDialog(),
      ),
    );
  }

  // ============================================================
  // ADD USER
  // ============================================================

  void _showAddUserDialog(
    BuildContext context,
  ) {
    final auth = context.read<AuthProvider>();

    if (!_isLoggedInAdmin(auth)) {
      _showMessage(
        context,
        'Only ADMIN can create users.',
      );
      return;
    }

    final provider = context.read<UserProvider>();

    final username = TextEditingController();
    final fullName = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final employeeId = TextEditingController();
    final department = TextEditingController();
    final designation = TextEditingController();
    final password = TextEditingController();
    final confirmPassword = TextEditingController();

    String role = 'STAFF';
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool saving = false;

    final availableRoles = provider.roles
        .map((item) => item['role_code']?.toString() ??
            item['role_name']?.toString() ?? '')
        .map((value) => value
            .trim()
            .toUpperCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_'))
        .where((value) => value.isNotEmpty && value != 'SUPER_ADMIN')
        .toSet()
        .toList();

    if (availableRoles.isNotEmpty && !availableRoles.contains(role)) {
      role = availableRoles.first;
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: !isMobile,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final roles = availableRoles.isNotEmpty
                ? availableRoles
                : const <String>[
                    'ADMIN',
                    'MANAGER',
                    'LOAN_OFFICER',
                    'CASHIER',
                    'GOLD_APPRAISER',
                    'STAFF',
                    'VIEWER',
                  ];

            return AlertDialog(
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 0 : 16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.darkNavy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: AppTheme.goldPrimary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Create New User',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 560,
                  child: Column(
                    children: [
                      _dialogField(
                        username,
                        'Username *',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        fullName,
                        'Full Name *',
                        Icons.badge_outlined,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              employeeId,
                              'Employee ID',
                              Icons.badge,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              mobile,
                              'Mobile',
                              Icons.phone_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dialogField(
                              department,
                              'Department',
                              Icons.account_tree_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dialogField(
                              designation,
                              'Designation',
                              Icons.work_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        email,
                        'Email',
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: roles.contains(role) ? role : roles.first,
                        decoration: const InputDecoration(
                          labelText: 'Role *',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: roles.map((value) {
                          final label = value
                              .replaceAll('_', ' ')
                              .toUpperCase();
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => role = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: password,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Initial Password *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword,
                            ),
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmPassword,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppTheme.goldPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.goldPrimary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.security_outlined,
                              size: 18,
                              color: AppTheme.goldDark,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'After creating the user, ADMIN can immediately choose exactly which ERP screens the user can see.',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final usernameValue = username.text.trim();
                          final fullNameValue = fullName.text.trim();
                          final passwordValue = password.text;
                          final confirmValue = confirmPassword.text;

                          if (usernameValue.length < 3) {
                            _showMessage(
                              context,
                              'Username must contain at least 3 characters.',
                            );
                            return;
                          }

                          if (fullNameValue.length < 2) {
                            _showMessage(
                              context,
                              'Full Name is required.',
                            );
                            return;
                          }

                          if (passwordValue.length < 8) {
                            _showMessage(
                              context,
                              'Password must contain at least 8 characters.',
                            );
                            return;
                          }

                          if (passwordValue != confirmValue) {
                            _showMessage(
                              context,
                              'Passwords do not match.',
                            );
                            return;
                          }

                          setDialogState(() => saving = true);

                          final result = await provider.createUser({
                            'username': usernameValue,
                            'full_name': fullNameValue,
                            'mobile': mobile.text.trim(),
                            'email': email.text.trim(),
                            'employee_id': employeeId.text.trim(),
                            'department': department.text.trim(),
                            'designation': designation.text.trim(),
                            'password': passwordValue,
                            'role': role,
                            'status': 'ACTIVE',
                          });

                          if (!context.mounted) return;

                          if (result == null) {
                            setDialogState(() => saving = false);
                            _showMessage(
                              context,
                              provider.errorMessage ??
                                  'Unable to create user.',
                            );
                            return;
                          }

                          final rawUser = result['user'];
                          int? newUserId;
                          if (rawUser is Map) {
                            newUserId = int.tryParse('${rawUser['id'] ?? ''}');
                          }
                          newUserId ??= int.tryParse('${result['id'] ?? ''}');

                          Navigator.pop(dialogContext);

                          if (!context.mounted) return;

                          _showMessage(
                            context,
                            'User created successfully. Now configure screen permissions.',
                          );

                          if (newUserId != null && newUserId > 0) {
                            await _openPermissions(
                              context,
                              provider,
                              newUserId,
                            );
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(saving ? 'CREATING...' : 'CREATE USER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkNavy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      username.dispose();
      fullName.dispose();
      mobile.dispose();
      email.dispose();
      employeeId.dispose();
      department.dispose();
      designation.dispose();
      password.dispose();
      confirmPassword.dispose();
    });
  }

  // ============================================================
  // EDIT USER
  // ============================================================

  void _showEditUserDialog(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final auth = context.read<AuthProvider>();
    if (!_isLoggedInAdmin(auth)) {
      _showMessage(context, 'Only ADMIN can edit users.');
      return;
    }
    final fullName =
        TextEditingController(
      text: _value(
        user,
        [
          'full_name',
          'name',
        ],
      ),
    );

    final mobile =
        TextEditingController(
      text: _value(
        user,
        [
          'mobile',
        ],
      ),
    );

    final email =
        TextEditingController(
      text: _value(
        user,
        [
          'email',
        ],
      ),
    );

    showDialog(
      context: context,

      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Edit User',

            style:
                TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          content:
              SingleChildScrollView(
            child:
                SizedBox(
              width: 430,

              child:
                  Column(
                children: [
                  _dialogField(
                    fullName,
                    'Full Name',
                    Icons
                        .badge_outlined,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _dialogField(
                    mobile,
                    'Mobile',
                    Icons
                        .phone_outlined,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _dialogField(
                    email,
                    'Email',
                    Icons
                        .email_outlined,
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
                  const Text(
                'CANCEL',
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                final userId = int.tryParse('${user['id'] ?? ''}');
                if (userId == null || userId <= 0) {
                  _showMessage(context, 'Invalid user selected.');
                  return;
                }

                final adminId = int.tryParse(
                  '${ApiService.currentUser?['id'] ?? ''}',
                );
                if (adminId == null || adminId <= 0) {
                  _showMessage(
                    context,
                    'Authenticated ADMIN user not found.',
                  );
                  return;
                }

                final nameValue = fullName.text.trim();
                if (nameValue.isEmpty) {
                  _showMessage(context, 'Full Name is required.');
                  return;
                }

                final provider = context.read<UserProvider>();
                Navigator.pop(dialogContext);

                try {
                  await ApiService.updateUser({
                    'user_id': userId,
                    'full_name': nameValue,
                    'mobile': mobile.text.trim(),
                    'email': email.text.trim(),
                    'admin_id': adminId,
                  });

                  if (!mounted) return;
                  await provider.fetchUsers(
                    search: provider.search,
                    status: provider.selectedStatus,
                    role: provider.selectedRole,
                    page: provider.currentPage,
                    limit: 25,
                  );

                  if (!context.mounted) return;
                  _showMessage(
                    context,
                    'User updated successfully.',
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  _showMessage(
                    context,
                    e.toString().replaceFirst('Exception: ', ''),
                  );
                }
              },

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    AppTheme
                        .darkNavy,

                foregroundColor:
                    Colors.white,
              ),

              child:
                  const Text(
                'SAVE CHANGES',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  void _showResetPasswordDialog(
    BuildContext context,
    UserProvider provider,
    int userId,
  ) {
    final password =
        TextEditingController();

    final confirm =
        TextEditingController();

    showDialog(
      context: context,

      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Reset Password',

            style:
                TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          content:
              SizedBox(
            width: 400,

            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                _dialogField(
                  password,
                  'New Password',
                  Icons
                      .lock_outline,
                  obscure:
                      true,
                ),

                const SizedBox(
                  height: 12,
                ),

                _dialogField(
                  confirm,
                  'Confirm Password',
                  Icons
                      .lock_reset_outlined,
                  obscure:
                      true,
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
                  const Text(
                'CANCEL',
              ),
            ),

            ElevatedButton(
              onPressed:
                  () async {
                if (password
                        .text
                        .isEmpty ||
                    password.text !=
                        confirm.text) {
                  _showMessage(
                    context,
                    'Passwords do not match.',
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                final success =
                    await provider
                        .resetPassword(
                  userId:
                      userId,

                  newPassword:
                      password.text,
                );

                if (!context.mounted) {
                  return;
                }

                _showMessage(
                  context,

                  success
                      ? 'Password reset successfully.'
                      : provider
                              .errorMessage ??
                          'Password reset failed.',
                );
              },

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    AppTheme
                        .darkNavy,

                foregroundColor:
                    Colors.white,
              ),

              child:
                  const Text(
                'RESET PASSWORD',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  void _showStatusDialog(
    BuildContext context,
    UserProvider provider,
    Map<String, dynamic> user,
    int userId,
  ) {
    final auth = context.read<AuthProvider>();
    if (!_isLoggedInAdmin(auth)) {
      _showMessage(context, 'Only ADMIN can change user status.');
      return;
    }
    final current =
        _value(
          user,
          [
            'status',
          ],
        ).toUpperCase();

    final newStatus =
        current == 'ACTIVE'
            ? 'INACTIVE'
            : 'ACTIVE';

    showDialog(
      context: context,

      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              Text(
            newStatus ==
                    'ACTIVE'
                ? 'Activate User'
                : 'Deactivate User',
          ),

          content:
              Text(
            'Are you sure you want to change this user to $newStatus?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
                  const Text(
                'CANCEL',
              ),
            ),

            ElevatedButton(
              onPressed:
                  () async {
                Navigator.pop(
                  dialogContext,
                );

                final success =
                    await provider
                        .toggleUserStatus(
                  userId:
                      userId,

                  status:
                      newStatus,
                );

                if (!context.mounted) {
                  return;
                }

                _showMessage(
                  context,

                  success
                      ? 'User status updated.'
                      : provider
                              .errorMessage ??
                          'Unable to update status.',
                );
              },

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    AppTheme
                        .darkNavy,

                foregroundColor:
                    Colors.white,
              ),

              child:
                  const Text(
                'CONFIRM',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DELETE USER
  // ============================================================

  void _showDeleteUserDialog(
    BuildContext context,
    UserProvider provider,
    Map<String, dynamic> user,
    int userId,
  ) async {
    final auth = context.read<AuthProvider>();
    if (!_isLoggedInAdmin(auth)) {
      _showMessage(context, 'Only ADMIN can delete users.');
      return;
    }

    final username = _value(user, ['username']);
    final fullName = _value(user, ['full_name', 'name']);

    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      title: 'Confirm Delete User',
      message: 'Are you sure you want to delete user "$fullName" (@$username)?\n\nThis will deactivate their access to the system.',
      confirmLabel: 'DELETE USER',
    );

    if (!confirmed || !context.mounted) return;

    final success = await provider.deleteUser(userId);

    if (!context.mounted) return;

    if (success) {
      SuccessDialog.show(
        context: context,
        title: 'User Deleted Successfully',
        message: 'User "$fullName" (@$username) has been deleted successfully.',
      );
    } else {
      _showMessage(
        context,
        provider.errorMessage ?? 'Unable to delete user.',
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _userIdentity(
    Map<String, dynamic> user,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        _avatar(user),

        const SizedBox(
          width: 9,
        ),

        SizedBox(
          width: 150,

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            mainAxisAlignment:
                MainAxisAlignment
                    .center,

            children: [
              Text(
                _value(
                  user,
                  [
                    'full_name',
                    'name',
                  ],
                ),

                maxLines: 1,

                overflow:
                    TextOverflow
                        .ellipsis,

                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              Text(
                '@${_value(user, [
                      'username',
                    ])}',

                style:
                    const TextStyle(
                  fontSize: 10,
                  color:
                      AppTheme
                          .silverDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(
    Map<String, dynamic> user,
  ) {
    final isAdmin =
        _value(
          user,
          [
            'role',
          ],
        ).toUpperCase() ==
        'ADMIN';

    return CircleAvatar(
      radius: 22,

      backgroundColor:
          isAdmin
              ? AppTheme
                  .darkNavy
              : AppTheme
                  .goldPrimary
                  .withValues(alpha: 
                  0.16,
                ),

      child:
          Icon(
        isAdmin
            ? Icons
                .admin_panel_settings
            : Icons
                .person_outline,

        color:
            isAdmin
                ? AppTheme
                    .goldPrimary
                : AppTheme
                    .goldDark,

        size: 22,
      ),
    );
  }

  Widget _roleBadge(
    String role,
  ) {
    final isAdmin =
        role.toUpperCase() ==
            'ADMIN';

    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 8,
        vertical: 5,
      ),

      decoration:
          BoxDecoration(
        color:
            isAdmin
                ? AppTheme
                    .darkNavy
                : AppTheme
                    .goldPrimary
                    .withValues(alpha: 
                    0.13,
                  ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child:
          Text(
        role.isEmpty
            ? '-'
            : role,

        style:
            TextStyle(
          fontSize: 9,

          fontWeight:
              FontWeight.w800,

          color:
              isAdmin
                  ? AppTheme
                      .goldPrimary
                  : AppTheme
                      .goldDark,
        ),
      ),
    );
  }

  Widget _statusBadge(
    String status,
  ) {
    final value =
        status.toUpperCase();

    final Color color =
        value == 'ACTIVE'
            ? Colors.green.shade700
            : value == 'LOCKED'
                ? Colors.red.shade700
                : Colors.orange.shade700;

    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 8,
        vertical: 5,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 
          0.09,
        ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child:
          Text(
        status.isEmpty
            ? '-'
            : status,

        style:
            TextStyle(
          fontSize: 9,

          fontWeight:
              FontWeight.w800,

          color: color,
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),

      child:
          Row(
        children: [
          SizedBox(
            width: 90,

            child:
                Text(
              label,

              style:
                  const TextStyle(
                fontSize: 10,

                color:
                    AppTheme
                        .silverDark,
              ),
            ),
          ),

          Expanded(
            child:
                Text(
              value.isEmpty
                  ? '-'
                  : value,

              style:
                  const TextStyle(
                fontSize: 11,

                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController
        controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller:
          controller,

      obscureText:
          obscure,

      decoration:
          InputDecoration(
        labelText:
            label,

        prefixIcon:
            Icon(icon),
      ),
    );
  }

  Widget _emptyUsers() {
    return const Center(
      child:
          Column(
        mainAxisAlignment:
            MainAxisAlignment
                .center,

        children: [
          Icon(
            Icons
                .people_outline,

            size: 52,

            color:
                AppTheme
                    .silverDark,
          ),

          SizedBox(
            height: 10,
          ),

          Text(
            'No users found',

            style:
                TextStyle(
              fontWeight:
                  FontWeight.w800,

              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    UserProvider provider, {
    bool mobile = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 14,
        vertical: mobile ? 3 : 10,
      ),

      child:
          Row(
        children: [
          Text(
            '${provider.totalRecords} users',

            style:
                const TextStyle(
              fontSize: 11,

              color:
                  AppTheme
                      .silverDark,

              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const Spacer(),

          IconButton(
            constraints: mobile
                ? const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  )
                : null,
            padding: mobile ? EdgeInsets.zero : null,
            visualDensity: mobile
                ? VisualDensity.compact
                : null,
            onPressed:
                provider
                        .hasPreviousPage
                    ? provider
                        .previousPage
                    : null,

            icon:
                const Icon(
              Icons
                  .chevron_left,
            ),
          ),

          Text(
            '${provider.currentPage} / ${provider.totalPages == 0 ? 1 : provider.totalPages}',

            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          IconButton(
            constraints: mobile
                ? const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  )
                : null,
            padding: mobile ? EdgeInsets.zero : null,
            visualDensity: mobile
                ? VisualDensity.compact
                : null,
            onPressed:
                provider
                        .hasNextPage
                    ? provider
                        .nextPage
                    : null,

            icon:
                const Icon(
              Icons
                  .chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  String _value(
    Map<String, dynamic>
        data,
    List<String> keys,
  ) {
    for (final key
        in keys) {
      final value =
          data[key];

      if (value != null &&
          value.toString()
              .trim()
              .isNotEmpty) {
        return value
            .toString();
      }
    }

    return '';
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),

        behavior:
            SnackBarBehavior
                .floating,
      ),
    );
  }

  // ============================================================
  // ADMIN AUTHORIZATION
  // ============================================================

  bool _isLoggedInAdmin(AuthProvider auth) {
    final providerUser = auth.currentUser;
    final apiUser = ApiService.currentUser;
    final user = providerUser ?? apiUser;

    if (user == null) {
      debugPrint(
        'ADMIN CHECK: currentUser is null in AuthProvider and ApiService',
      );
      return false;
    }

    String normalizeRole(dynamic value) {
      return value
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
    }

    String? findRole(dynamic value) {
      if (value is Map) {
        const keys = <String>[
          'role',
          'role_code',
          'role_name',
          'user_role',
          'userRole',
          'type',
        ];

        for (final key in keys) {
          final candidate = value[key];

          if (candidate != null &&
              candidate.toString().trim().isNotEmpty) {
            final role = normalizeRole(candidate);

            if (role.isNotEmpty) {
              return role;
            }
          }
        }

        for (final key in const [
          'user',
          'data',
          'result',
        ]) {
          final nestedRole = findRole(value[key]);

          if (nestedRole != null &&
              nestedRole.isNotEmpty) {
            return nestedRole;
          }
        }
      }

      return null;
    }

    final role = findRole(user);

    debugPrint('ADMIN CHECK: user=$user');
    debugPrint('ADMIN CHECK: detected role=$role');

    // User Management is STRICTLY ADMIN-only.
    // SUPER_ADMIN and ADMINISTRATOR are intentionally NOT allowed.
    return role == 'ADMIN';
  }

}

// ============================================================================
// PERMISSION DIALOG
// ============================================================================

class _PermissionDialog
    extends StatefulWidget {
  const _PermissionDialog();

  @override
  State<_PermissionDialog>
      createState() =>
          _PermissionDialogState();
}

class _PermissionDialogState
    extends State<_PermissionDialog> {
  final Map<String, bool>
      _checked = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _loadPermissions();
      },
    );
  }

  void _loadPermissions() {
    final provider = context.read<UserProvider>();

    _checked.clear();

    final activeSet = provider.selectedPermissionCodes
        .map((c) => c.toLowerCase().trim())
        .where((c) => c.isNotEmpty)
        .toSet();

    for (final raw in provider.permissions) {
      final rawCode = raw['permission_code']?.toString() ??
          raw['code']?.toString() ??
          raw['permission_key']?.toString();

      if (rawCode != null && rawCode.isNotEmpty) {
        final code = rawCode.toLowerCase().trim();
        final isAssigned = activeSet.contains(code) || _permissionAllowed(raw);
        _checked[code] = isAssigned;
      }
    }

    final grouped = provider.permissionsGroupedByModule;
    grouped.forEach((module, values) {
      if (values is List) {
        for (final item in values) {
          if (item is Map) {
            final rawCode = item['permission_code']?.toString() ??
                item['code']?.toString() ??
                item['permission_key']?.toString();

            if (rawCode != null && rawCode.isNotEmpty) {
              final code = rawCode.toLowerCase().trim();
              if (!_checked.containsKey(code)) {
                _checked[code] = activeSet.contains(code) || _permissionAllowed(item);
              }
            }
          }
        }
      }
    });

    setState(() {});
  }

  bool _permissionAllowed(Map item) {
    final allowed = item['assigned'] ?? item['allowed'] ?? item['is_assigned'] ?? item['selected'];

    if (allowed is bool) {
      return allowed;
    }

    return allowed == 1 ||
        allowed == '1' ||
        allowed == true ||
        allowed == 'true';
  }

  bool get _isAdmin {
    final provider = context.read<UserProvider>();

    final role = provider.selectedUser?['role']?.toString().toUpperCase();

    return role == 'ADMIN';
  }

  void _selectAll() {
    if (_isAdmin) {
      return;
    }

    final provider = context.read<UserProvider>();

    for (final permission in provider.permissions) {
      final rawCode = permission['permission_code']?.toString() ??
          permission['code']?.toString() ??
          permission['permission_key']?.toString();

      if (rawCode != null && rawCode.isNotEmpty) {
        _checked[rawCode.toLowerCase().trim()] = true;
      }
    }

    setState(() {});
  }

  void _clearAll() {
    if (_isAdmin) {
      return;
    }

    for (final key in _checked.keys.toList()) {
      _checked[key] = false;
    }

    setState(() {});
  }

  bool _isLoggedInAdmin(AuthProvider auth) {
    // Prefer AuthProvider, but fall back to ApiService.currentUser.
    // This handles screens that were opened with a different provider
    // scope while preserving the same authenticated session.
    final providerUser = auth.currentUser;
    final apiUser = ApiService.currentUser;

    final user = providerUser ?? apiUser;

    if (user == null) {
      debugPrint('ADMIN CHECK: currentUser is null in AuthProvider and ApiService');
      return false;
    }

    String normalizeRole(dynamic value) {
      return value
          .toString()
          .trim()
          .toUpperCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
    }

    String? findRole(dynamic value) {
      if (value is Map) {
        const keys = <String>[
          'role',
          'role_code',
          'role_name',
          'user_role',
          'userRole',
          'type',
        ];

        for (final key in keys) {
          final candidate = value[key];
          if (candidate != null && candidate.toString().trim().isNotEmpty) {
            final role = normalizeRole(candidate);
            if (role.isNotEmpty) return role;
          }
        }

        // Some login APIs wrap the user object.
        for (final key in const ['user', 'data', 'result']) {
          final nested = value[key];
          final role = findRole(nested);
          if (role != null && role.isNotEmpty) return role;
        }
      }
      return null;
    }

    final role = findRole(user);
    debugPrint('ADMIN CHECK: user=$user');
    debugPrint('ADMIN CHECK: detected role=$role');

    // User Management and permission management are STRICTLY ADMIN-only.
    // SUPER_ADMIN and ADMINISTRATOR are intentionally denied here.
    return role == 'ADMIN';
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final provider =
        context.watch<UserProvider>();

    final width =
        MediaQuery.of(context)
            .size
            .width;

    final bool isMobile = width < 650;
    final double inset = isMobile ? 0 : 28;
    final double availableWidth = width - (inset * 2);
    final double dialogWidth = isMobile ? width : (availableWidth < 950 ? availableWidth : 950);

    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 0 : 20),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: isMobile ? MediaQuery.of(context).size.height : (width < 1100 ? 680 : 720),
        child: Column(
          children: [
            _header(
              provider,
              isMobile,
            ),

            Expanded(
              child:
                  _permissionContent(
                provider,
              ),
            ),

            _bottomActions(
              provider,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PERMISSION HEADER
  // ============================================================

  Widget _header(
    UserProvider provider,
    bool mobile,
  ) {
    final user =
        provider.selectedUser;

    final name =
        user?['full_name']
                ?.toString() ??
            user?['name']
                ?.toString() ??
            'User';

    final username =
        user?['username']
                ?.toString() ??
            '';

    final role =
        user?['role']
                ?.toString() ??
            '';

    return Container(
      padding:
          EdgeInsets.all(
        mobile ? 15 : 20,
      ),

      decoration:
          const BoxDecoration(
        color:
            AppTheme.darkNavy,

        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(
            20,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 
                0.10,
              ),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .admin_panel_settings_outlined,

              color:
                  AppTheme
                      .goldPrimary,

              size: 27,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  'Manage Permissions',

                  style:
                      TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        mobile
                            ? 17
                            : 20,

                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$name  •  @$username  •  $role',

                  maxLines: 1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      TextStyle(
                    color:
                        Colors.white
                            .withValues(alpha: 
                      0.70,
                    ),

                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              Navigator.pop(
                context,
              );
            },

            icon:
                const Icon(
              Icons.close,
              color:
                  Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERMISSION CONTENT
  // ============================================================

  Widget _permissionContent(
    UserProvider provider,
  ) {
    if (provider.isSaving) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    Map<String, dynamic> grouped =
        Map<String, dynamic>.from(
      provider.permissionsGroupedByModule,
    );

    // Defensive fallback: if the provider has the complete permission
    // catalogue but grouping was not populated, build the grouping here.
    if (grouped.isEmpty && provider.permissions.isNotEmpty) {
      final fallback = <String, List<Map<String, dynamic>>>{};

      for (final raw in provider.permissions) {
        final item = raw;
        final module =
            item['module_name']?.toString().trim().isNotEmpty == true
                ? item['module_name'].toString().trim()
                : item['module']?.toString().trim().isNotEmpty == true
                    ? item['module'].toString().trim()
                    : 'GENERAL';

        fallback.putIfAbsent(module, () => <Map<String, dynamic>>[]).add(item);
      }

      grouped = fallback;
    }

    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No permissions available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.silverDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding:
          const EdgeInsets.all(
        16,
      ),

      children: [
        _permissionSummary(
          provider,
        ),

        const SizedBox(
          height: 12,
        ),

        Row(
          children: [
            Expanded(
              child:
                  OutlinedButton.icon(
                onPressed:
                    _isAdmin
                        ? null
                        : _selectAll,

                icon:
                    const Icon(
                  Icons.select_all,
                  size: 17,
                ),

                label:
                    const Text(
                  'SELECT ALL',
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            Expanded(
              child:
                  OutlinedButton.icon(
                onPressed:
                    _isAdmin
                        ? null
                        : _clearAll,

                icon:
                    const Icon(
                  Icons.clear_all,
                  size: 17,
                ),

                label:
                    const Text(
                  'CLEAR ALL',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 15,
        ),

        ...grouped.entries.map(
          (entry) =>
              _moduleCard(
            entry.key,
            entry.value,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _permissionSummary(
    UserProvider provider,
  ) {
    final total = provider.permissions.length;

    final grantedCodes = <String>{};
    for (final entry in _checked.entries) {
      if (entry.value && entry.key.isNotEmpty) {
        grantedCodes.add(entry.key.toLowerCase().trim());
      }
    }

    final granted = grantedCodes.length;
    final progress = total == 0 ? 0.0 : (granted / total).clamp(0.0, 1.0);

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            AppTheme
                .goldPrimary
                .withValues(alpha: 
          0.08,
        ),

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        border:
            Border.all(
          color:
              AppTheme
                  .goldPrimary
                  .withValues(alpha: 
            0.20,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.security_outlined,
                color: AppTheme.goldDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Permission Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$granted / $total',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.goldDark,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),

            child:
                LinearProgressIndicator(
              value:
                  progress,

              minHeight: 7,

              backgroundColor:
                  Colors.white,

              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                AppTheme
                    .goldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODULE CARD
  // ============================================================

  Widget _moduleCard(
    String module,
    dynamic values,
  ) {
    final List<dynamic> items =
        values is List
            ? values
            : [];

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      decoration:
          BoxDecoration(
        color:
            kPageBackground,

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        border:
            Border.all(
          color:
              Colors.grey
                  .withValues(alpha: 
            0.15,
          ),
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
              vertical: 11,
            ),

            decoration:
                const BoxDecoration(
              color:
                  Colors.white,

              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  13,
                ),
              ),
            ),

            child:
                Text(
              module,

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w900,

                color:
                    AppTheme
                        .darkNavy,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final widgets = items.map((item) {
                  return _permissionCheckbox(
                    item,
                    fullWidth: isNarrow,
                  );
                }).toList();

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < widgets.length; i++) ...[
                        widgets[i],
                        if (i < widgets.length - 1)
                          const SizedBox(height: 7),
                      ],
                    ],
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: widgets,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERMISSION CHECKBOX
  // ============================================================

  Widget _permissionCheckbox(
    dynamic item, {
    bool fullWidth = false,
  }) {
    if (item is! Map) {
      return const SizedBox();
    }

    final rawCode = item['permission_code']?.toString() ??
        item['code']?.toString() ??
        item['permission_key']?.toString() ??
        '';

    final code = rawCode.toLowerCase().trim();

    final label = item['display_name']?.toString() ??
        item['permission_name']?.toString() ??
        item['name']?.toString() ??
        item['action_name']?.toString() ??
        code;

    final checked = _checked[code] ?? false;
    final disabled = _isAdmin;

    void toggle() {
      if (disabled) return;
      setState(() {
        _checked[code] = !checked;
      });
    }

    return InkWell(
      onTap: toggle,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: checked
              ? AppTheme.goldPrimary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: checked ? AppTheme.goldDark : Colors.grey.shade300,
            width: checked ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Checkbox(
              value: checked,
              onChanged: disabled ? null : (_) => toggle(),
              activeColor: AppTheme.goldDark,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            if (fullWidth)
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: checked ? FontWeight.w800 : FontWeight.w500,
                    color: checked ? AppTheme.darkNavy : Colors.black87,
                  ),
                ),
              )
            else
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: checked ? FontWeight.w800 : FontWeight.w500,
                  color: checked ? AppTheme.darkNavy : Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTIONS
  // ============================================================

  Widget _bottomActions(
    UserProvider provider,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 760;

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 17,
                          color: AppTheme.goldDark,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ADMIN has full system access.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isAdmin
                            ? null
                            : () {
                                _savePermissions(provider);
                              },
                        icon: const Icon(
                          Icons.save_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'SAVE',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkNavy,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              if (_isAdmin)
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 17,
                        color: AppTheme.goldDark,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'ADMIN has full system access.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('CANCEL'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAdmin
                    ? null
                    : () {
                        _savePermissions(provider);
                      },
                icon: const Icon(
                  Icons.save_outlined,
                  size: 18,
                ),
                label: const Text('SAVE PERMISSIONS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // SAVE UI
  // ============================================================

  Future<void> _savePermissions(
    UserProvider provider,
  ) async {
    final auth = context.read<AuthProvider>();

    if (!_isLoggedInAdmin(auth)) {
      _showMessage(
        context,
        'Only ADMIN can manage permissions.',
        error: true,
      );
      return;
    }

    if (_isAdmin) {
      _showMessage(
        context,
        'ADMIN has full system access. ADMIN permissions cannot be restricted.',
        error: true,
      );
      return;
    }

    final userId = int.tryParse(
      '${provider.selectedUser?['id'] ?? ''}',
    );

    if (userId == null || userId <= 0) {
      _showMessage(
        context,
        'Invalid user selected.',
        error: true,
      );
      return;
    }

    final selectedSet = <String>{};
    for (final entry in _checked.entries) {
      if (entry.value && entry.key.trim().isNotEmpty) {
        selectedSet.add(entry.key.trim().toLowerCase());
      }
    }
    final selected = selectedSet.toList();

    final success = await provider.updateUserPermissions(
      userId: userId,
      permissionCodes: selected,
    );

    if (!mounted) return;

    if (success) {
      _showMessage(
        context,
        'Permissions saved successfully.',
      );
      Navigator.pop(context);
    } else {
      _showMessage(
        context,
        provider.errorMessage ?? 'Unable to save permissions.',
        error: true,
      );
    }
  }
}