// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  final _shopNameCtrl =
      TextEditingController(
    text: 'GOLD & SILVER PAWN LOAN MANAGEMENT',
  );

  final _shopAddressCtrl =
      TextEditingController(
    text:
        'Main Market Road, Commercial Complex',
  );

  final _shopPhoneCtrl =
      TextEditingController(
    text: '+91 98765 43210',
  );

  final _defaultRateCtrl =
      TextEditingController(
    text: '2.00',
  );

  // ADMIN credential change
  final _currentAdminUsernameCtrl = TextEditingController(
    text: ApiService.currentUser?['username']?.toString() ?? '',
  );
  final _currentAdminPasswordCtrl =
      TextEditingController();
  final _newAdminUsernameCtrl =
      TextEditingController();
  final _newAdminPasswordCtrl =
      TextEditingController();
  final _confirmAdminPasswordCtrl =
      TextEditingController();

  bool _isAdminCredentialSaving = false;
  bool _isSettingsSaving = false;
  bool _obscureCurrentAdminPassword = true;
  bool _obscureNewAdminPassword = true;
  bool _obscureConfirmAdminPassword = true;

  bool _isBackupLoading = false;
  List<Map<String, dynamic>> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackups();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await ApiService.getSettings();
      if (!mounted) return;
      setState(() {
        if (data['shop_name'] != null && data['shop_name'].toString().isNotEmpty) {
          _shopNameCtrl.text = data['shop_name'].toString();
        }
        if (data['shop_address'] != null && data['shop_address'].toString().isNotEmpty) {
          _shopAddressCtrl.text = data['shop_address'].toString();
        }
        if (data['shop_phone'] != null && data['shop_phone'].toString().isNotEmpty) {
          _shopPhoneCtrl.text = data['shop_phone'].toString();
        }
        if (data['default_interest_rate'] != null && data['default_interest_rate'].toString().isNotEmpty) {
          _defaultRateCtrl.text = data['default_interest_rate'].toString();
        }
      });
    } catch (e) {
      // ignore
    }
  }

  // ============================================================
  // BREAKPOINTS
  // ============================================================

  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  bool _isMobile(double width) =>
      width < mobileBreakpoint;

  bool _isDesktop(double width) =>
      width >= desktopBreakpoint;

  bool get _isAdmin =>
      (ApiService.currentUser?['role']?.toString().toUpperCase() ?? '') ==
      'ADMIN';

  // ============================================================
  // SAVE SETTINGS
  // ============================================================

  Future<void> _saveSettings() async {
    setState(() => _isSettingsSaving = true);
    try {
      await ApiService.saveSettings({
        'shop_name': _shopNameCtrl.text.trim(),
        'shop_address': _shopAddressCtrl.text.trim(),
        'shop_phone': _shopPhoneCtrl.text.trim(),
        'default_interest_rate': _defaultRateCtrl.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop Settings saved successfully!'),
          backgroundColor: Color(0xFF065F46),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSettingsSaving = false);
      }
    }
  }


  // ============================================================
  // ADMIN CREDENTIALS
  // ============================================================

  Future<void> _updateAdminCredentials() async {
    final currentPassword =
        _currentAdminPasswordCtrl.text;
    final newUsername =
        _newAdminUsernameCtrl.text.trim();
    final newPassword =
        _newAdminPasswordCtrl.text;
    final confirmPassword =
        _confirmAdminPasswordCtrl.text;

    if (currentPassword.isEmpty) {
      _showCredentialMessage('Current password is required.');
      return;
    }

    if (newUsername.isEmpty && newPassword.isEmpty) {
      _showCredentialMessage(
        'Enter a new User ID, a new password, or both.',
      );
      return;
    }

    if (newPassword.isNotEmpty &&
        newPassword != confirmPassword) {
      _showCredentialMessage('New password and confirmation do not match.');
      return;
    }

    setState(() => _isAdminCredentialSaving = true);

    try {
      await ApiService.updateAdminCredentials(
        currentPassword: currentPassword,
        newUsername: newUsername,
        newPassword: newPassword,
      );

      if (!mounted) return;

      _currentAdminPasswordCtrl.clear();
      _newAdminUsernameCtrl.clear();
      _newAdminPasswordCtrl.clear();
      _confirmAdminPasswordCtrl.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'ADMIN credentials updated successfully.',
          ),
          backgroundColor: Color(0xFF065F46),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showCredentialMessage(
        'Credential update failed: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isAdminCredentialSaving = false);
      }
    }
  }

  void _showCredentialMessage(
    String message, {
    bool error = true,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? AppTheme.statusDanger : const Color(0xFF065F46),
      ),
    );
  }

  // ============================================================
  // DATABASE BACKUP & RESTORE
  // ============================================================

  Future<void> _createBackup() async {
    setState(() => _isBackupLoading = true);

    try {
      final result =
          await ApiService.createDatabaseBackup();

      if (!mounted) return;

      await _loadBackups();

      final fileName =
          result['file_name']?.toString() ?? 'backup.sql';

      // Open the server download endpoint in the browser.
      // The PHP endpoint sends Content-Disposition: attachment,
      // so the generated .sql file is downloaded to the computer.
      final downloadUrl =
          ApiService.getDatabaseBackupDownloadUrl(fileName);
      final uri = Uri.parse(downloadUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Backup created and download started: $fileName'
                : 'Backup created: $fileName. Open the backup list to download it.',
          ),
          backgroundColor:
              const Color(0xFF065F46),
          duration:
              const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Backup failed: $e'),
          backgroundColor:
              AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackupLoading = false);
      }
    }
  }

  Future<void> _loadBackups() async {
    final backups =
        await ApiService.getDatabaseBackups();

    if (!mounted) return;

    setState(() {
      _backups = backups;
    });
  }

  Future<void> _openRestoreDialog() async {
    setState(() => _isBackupLoading = true);

    try {
      await _loadBackups();

      if (!mounted) return;

      if (_backups.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('No database backups available.'),
          ),
        );
        return;
      }

      final selected =
          await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Restore Database Backup',
            ),
            content: SizedBox(
              width: 520,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _backups.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(height: 1),
                itemBuilder: (_, index) {
                  final backup =
                      _backups[index];

                  final fileName =
                      backup['file_name']
                          ?.toString() ??
                      '';

                  final createdAt =
                      backup['created_at']
                          ?.toString() ??
                      '';

                  final size =
                      int.tryParse(
                            '${backup['size_bytes'] ?? 0}',
                          ) ??
                          0;

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(
                        Icons
                            .backup_outlined,
                        color:
                            AppTheme.goldDark,
                      ),
                      title: Text(
                        fileName,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                      subtitle: Text(
                        '$createdAt • ${_formatBackupSize(size)}',
                      ),
                      onTap: () =>
                          Navigator.pop(
                        dialogContext,
                        fileName,
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child:
                    const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (selected == null ||
          selected.trim().isEmpty ||
          !mounted) {
        return;
      }

      final confirmed =
          await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Confirm Database Restore',
            ),
            content: const Text(
              'Restoring this backup will replace the current database data. '
              'This action cannot be undone. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                  false,
                ),
                child:
                    const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                  true,
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.statusDanger,
                  foregroundColor:
                      Colors.white,
                ),
                child:
                    const Text('Restore'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      setState(() =>
          _isBackupLoading = true);

      await ApiService
          .restoreDatabaseBackup(
        selected,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Database restored successfully. Please refresh the ERP.',
          ),
          backgroundColor:
              Color(0xFF065F46),
          duration:
              Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Restore failed: $e'),
          backgroundColor:
              AppTheme.statusDanger,
          duration:
              const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() =>
            _isBackupLoading = false);
      }
    }
  }

  Future<void> _confirmAndRestoreBackup(String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Database Restore'),
          content: Text(
            'Restoring "$fileName" will replace current database records with this backup. '
            'This action cannot be undone. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusDanger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBackupLoading = true);
    try {
      await ApiService.restoreDatabaseBackup(fileName);
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully! Please refresh the page.'),
          backgroundColor: Color(0xFF065F46),
          duration: Duration(seconds: 5),
        ),
      );
      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackupLoading = false);
      }
    }
  }

  String _formatBackupSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _defaultRateCtrl.dispose();
    _currentAdminUsernameCtrl.dispose();
    _currentAdminPasswordCtrl.dispose();
    _newAdminUsernameCtrl.dispose();
    _newAdminPasswordCtrl.dispose();
    _confirmAdminPasswordCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override


  Widget build(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width;

    final mobile =
        _isMobile(width);

    final desktop =
        _isDesktop(width);

    return Scaffold(
      backgroundColor:
          AppTheme.backgroundLight,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            mobile
                ? 10
                : desktop
                    ? 24
                    : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1100,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildShopCard(
                    mobile: mobile,
                  ),

                  if (_isAdmin) ...[
                    SizedBox(
                      height: mobile ? 12 : 20,
                    ),

                    _buildAdminCredentialsCard(
                      mobile: mobile,
                    ),
                  ],

                  SizedBox(
                    height: mobile
                        ? 12
                        : 20,
                  ),

                  _buildBackupCard(
                    mobile: mobile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SHOP CARD
  // ============================================================

  Widget _buildShopCard({
    required bool mobile,
  }) {
    return _settingsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'SHOP INFORMATION & OFFICIAL RECEIPT HEADER',
            Icons.store,
          ),

          SizedBox(
            height: mobile ? 12 : 14,
          ),

          _buildTextField(
            controller: _shopNameCtrl,
            label:
                'Shop / Entity Name',
            icon: Icons.store,
          ),

          SizedBox(
            height: mobile ? 10 : 14,
          ),

          _buildTextField(
            controller:
                _shopAddressCtrl,
            label: 'Shop Address',
            icon:
                Icons.location_on,
            maxLines: mobile ? 2 : 1,
          ),

          SizedBox(
            height: mobile ? 10 : 14,
          ),

          // ==================================================
          // PHONE + RATE
          // MOBILE: STACKED
          // TABLET/DESKTOP: SIDE BY SIDE
          // ==================================================

          if (mobile)
            Column(
              children: [
                _buildTextField(
                  controller:
                      _shopPhoneCtrl,
                  label:
                      'Phone Number',
                  icon: Icons.phone,
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(
                  height: 10,
                ),

                _buildTextField(
                  controller:
                      _defaultRateCtrl,
                  label:
                      'Default Monthly Rate (%)',
                  suffix:
                      '% / mo',
                  icon: Icons.percent,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      _buildTextField(
                    controller:
                        _shopPhoneCtrl,
                    label:
                        'Phone Number',
                    icon:
                        Icons.phone,
                    keyboardType:
                        TextInputType.phone,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      _buildTextField(
                    controller:
                        _defaultRateCtrl,
                    label:
                        'Default Monthly Rate (%)',
                    suffix:
                        '% / mo',
                    icon:
                        Icons.percent,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),

          SizedBox(
            height: mobile ? 14 : 18,
          ),

          if (mobile)
            SizedBox(
              width: double.infinity,
              child: _buildSaveButton(),
            )
          else
            Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  _buildSaveButton(),
            ),
        ],
      ),
    );
  }


  // ============================================================
  // ADMIN CREDENTIALS CARD
  // ============================================================

  Widget _buildAdminCredentialsCard({
    required bool mobile,
  }) {
    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'ADMIN USER ID & PASSWORD',
            Icons.admin_panel_settings_outlined,
          ),

          const SizedBox(height: 6),

          Text(
            'Change the existing ADMIN login credentials. The same ADMIN account remains active.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          SizedBox(height: mobile ? 12 : 14),

          TextField(
            controller: _currentAdminUsernameCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Current User ID',
              prefixIcon: Icon(
                Icons.person_outline,
                color: AppTheme.goldDark,
              ),
            ),
          ),

          SizedBox(height: mobile ? 10 : 14),

          _buildPasswordField(
            controller: _currentAdminPasswordCtrl,
            label: 'Current Password',
            icon: Icons.lock_outline,
            obscureText: _obscureCurrentAdminPassword,
            onToggle: () {
              setState(() {
                _obscureCurrentAdminPassword =
                    !_obscureCurrentAdminPassword;
              });
            },
          ),

          SizedBox(height: mobile ? 10 : 14),

          if (mobile)
            Column(
              children: [
                _buildTextField(
                  controller: _newAdminUsernameCtrl,
                  label: 'New User ID',
                  icon: Icons.person_add_alt_1_outlined,
                ),
                const SizedBox(height: 10),
                _buildPasswordField(
                  controller: _newAdminPasswordCtrl,
                  label: 'New Password',
                  icon: Icons.lock_reset_outlined,
                  obscureText: _obscureNewAdminPassword,
                  onToggle: () {
                    setState(() {
                      _obscureNewAdminPassword =
                          !_obscureNewAdminPassword;
                    });
                  },
                ),
                const SizedBox(height: 10),
                _buildPasswordField(
                  controller: _confirmAdminPasswordCtrl,
                  label: 'Confirm New Password',
                  icon: Icons.verified_user_outlined,
                  obscureText: _obscureConfirmAdminPassword,
                  onToggle: () {
                    setState(() {
                      _obscureConfirmAdminPassword =
                          !_obscureConfirmAdminPassword;
                    });
                  },
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _newAdminUsernameCtrl,
                        label: 'New User ID',
                        icon: Icons.person_add_alt_1_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildPasswordField(
                        controller: _newAdminPasswordCtrl,
                        label: 'New Password',
                        icon: Icons.lock_reset_outlined,
                        obscureText: _obscureNewAdminPassword,
                        onToggle: () {
                          setState(() {
                            _obscureNewAdminPassword =
                                !_obscureNewAdminPassword;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildPasswordField(
                  controller: _confirmAdminPasswordCtrl,
                  label: 'Confirm New Password',
                  icon: Icons.verified_user_outlined,
                  obscureText: _obscureConfirmAdminPassword,
                  onToggle: () {
                    setState(() {
                      _obscureConfirmAdminPassword =
                          !_obscureConfirmAdminPassword;
                    });
                  },
                ),
              ],
            ),

          SizedBox(height: mobile ? 14 : 18),

          SizedBox(
            width: mobile ? double.infinity : null,
            child: ElevatedButton.icon(
              onPressed: _isAdminCredentialSaving
                  ? null
                  : _updateAdminCredentials,
              icon: _isAdminCredentialSaving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _isAdminCredentialSaving
                    ? 'Updating...'
                    : 'Update ADMIN Credentials',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: AppTheme.goldDark,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATABASE BACKUP & RESTORE CARD
  // ============================================================

  Widget _buildBackupCard({
    required bool mobile,
  }) {
    return _settingsCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'DATABASE BACKUP & RESTORE',
            Icons.storage_rounded,
          ),

          SizedBox(
            height: mobile ? 8 : 10,
          ),

          const Text(
            'Protect backend_api data by creating a complete database backup. '
            'Existing backups can be restored from this ERP.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color:
                  AppTheme.silverDark,
            ),
          ),

          SizedBox(
            height: mobile ? 12 : 14,
          ),

          if (mobile)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child:
                      _buildCreateBackupButton(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child:
                      _buildRestoreBackupButton(),
                ),
              ],
            )
          else
            Row(
              children: [
                _buildCreateBackupButton(),
                const SizedBox(width: 10),
                _buildRestoreBackupButton(),
              ],
            ),

          if (_backups.isNotEmpty) ...[
            SizedBox(
              height: mobile ? 14 : 18,
            ),
            Row(
              children: [
                const Icon(
                  Icons.history,
                  size: 18,
                  color: AppTheme.goldDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Created Backups (${_backups.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.silverBorder,
                  width: 0.8,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _backups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final backup = _backups[index];
                  final fileName = backup['file_name']?.toString() ?? 'backup.sql';
                  final createdAt = backup['created_at']?.toString() ?? '';
                  final size = int.tryParse('${backup['size_bytes'] ?? backup['file_size'] ?? 0}') ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.goldPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: AppTheme.goldDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.darkNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$createdAt  •  ${_formatBackupSize(size)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.silverDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Download Backup File',
                          child: IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.darkNavy),
                            onPressed: () async {
                              final downloadUrl = ApiService.getDatabaseBackupDownloadUrl(fileName);
                              final uri = Uri.parse(downloadUrl);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                          ),
                        ),
                        Tooltip(
                          message: 'Restore This Backup',
                          child: IconButton(
                            icon: const Icon(Icons.restore_rounded, size: 20, color: Color(0xFF065F46)),
                            onPressed: () => _confirmAndRestoreBackup(fileName),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateBackupButton() {
    return ElevatedButton.icon(
      onPressed: _isBackupLoading
          ? null
          : _createBackup,
      icon: _isBackupLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.backup_outlined,
              size: 18,
            ),
      label: Text(
        _isBackupLoading
            ? 'Processing...'
            : 'Create Backup',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            AppTheme.darkNavy,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    );
  }

  Widget _buildRestoreBackupButton() {
    return OutlinedButton.icon(
      onPressed: _isBackupLoading
          ? null
          : _openRestoreDialog,
      icon: const Icon(
        Icons.restore_rounded,
        size: 18,
      ),
      label:
          const Text('Restore Backup'),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            AppTheme.darkNavy,
        side: const BorderSide(
          color: AppTheme.darkNavy,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSettingsSaving ? null : _saveSettings,
      icon: _isSettingsSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.save_outlined,
              size: 18,
            ),
      label: Text(_isSettingsSaving ? 'Saving...' : 'Save Settings'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.darkNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 13,
        ),
      ),
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget _settingsCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppTheme.silverBorder,
          width: 0.8,
        ),
      ),
      child: child,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color:
              AppTheme.goldDark,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts
                .plusJakartaSans(
              fontWeight:
                  FontWeight.w800,
              fontSize: 13,
              color:
                  AppTheme.darkNavy,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color:
              AppTheme.goldDark,
        ),
        suffixText: suffix,
      ),
    );
  }

}
