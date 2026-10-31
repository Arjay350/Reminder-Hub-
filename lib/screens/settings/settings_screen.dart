import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/security/security_service.dart';
import '../../models/app_models.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_backup_service.dart';
import '../../core/utilities/formatters.dart';
import '../../services/notification_service.dart';
import '../../services/hive_service.dart';
import '../../services/widget_service.dart';
import '../../services/pet_service.dart';
import '../../services/feedback_service.dart';
import '../../models/pet_models.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/backup_passphrase_dialog.dart';
import '../../widgets/profile_image_cropper_dialog.dart';
import '../../widgets/secure_action_gate.dart';
import '../about/about_screen.dart';
import '../pet/pet_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onThemeChanged});

  final Function(String themeMode)? onThemeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final HiveService _hive = HiveService.instance;
  late AppSettings _settings;
  bool _loaded = false;
  bool _isGoogleDriveBackingUp = false;
  bool _isGoogleDriveRestoring = false;
  bool _isOpeningFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _hive.ensureInitialized();
    final settings = _hive.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loaded = true;
    });
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    setState(() => _settings = newSettings);
    await _hive.saveSettings(newSettings);
  }

  Future<void> _openProfileImageCropper() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileImageCropperDialog(
        currentSettings: _settings,
        onProfileUpdated: (updated) {
          setState(() => _settings = updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userName = _settings.userName;
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final hasCustomImage =
        _settings.profileImagePath.isNotEmpty &&
        File(_settings.profileImagePath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // User Profile Card - Premium design with custom avatar & cropping
          CustomCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openProfileImageCropper,
                  child: Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasCustomImage
                              ? Image.file(
                                  File(_settings.profileImagePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _defaultAvatar(userInitial),
                                )
                              : _defaultAvatar(userInitial),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Profile Name',
                  onPressed: _editUserName,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Section
          _sectionHeader('Appearance'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.palette_outlined,
                    Colors.purple,
                  ),
                  title: const Text(
                    'Theme Mode',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    _settings.themeMode,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _settings.themeMode,
                    underline: const SizedBox.shrink(),
                    dropdownColor: isDark
                        ? const Color(0xFF141A2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    items: const [
                      DropdownMenuItem(value: 'System', child: Text('System')),
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final updated = _settings.copyWith(themeMode: val);
                        _saveSettings(updated);
                        widget.onThemeChanged?.call(val);
                      }
                    },
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF1E294B),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.attach_money_rounded,
                    Colors.green,
                  ),
                  title: const Text(
                    'Default Currency',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    _settings.currency,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: _settings.currency,
                    underline: const SizedBox.shrink(),
                    dropdownColor: isDark
                        ? const Color(0xFF141A2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    items: const [
                      DropdownMenuItem(value: '₱', child: Text('₱ PHP')),
                      DropdownMenuItem(value: '\$', child: Text('\$ USD')),
                      DropdownMenuItem(value: '€', child: Text('€ EUR')),
                      DropdownMenuItem(value: '£', child: Text('£ GBP')),
                      DropdownMenuItem(value: '¥', child: Text('¥ JPY')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _saveSettings(_settings.copyWith(currency: val));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Calendar Preferences Section
          _sectionHeader('Calendar Preferences'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              secondary: _settingsIconContainer(
                Icons.calendar_month_outlined,
                const Color(0xFF14B8A6),
              ),
              title: const Text(
                'Hide School Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Hide recurring classes in Calendar and Reminders. School tasks remain visible.',
                style: TextStyle(fontSize: 12),
              ),
              value: _settings.hideSchoolScheduleInCalendar,
              onChanged: (val) {
                _saveSettings(
                  _settings.copyWith(hideSchoolScheduleInCalendar: val),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Pet Companion Section
          _sectionHeader('Pet Companion'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: ValueListenableBuilder<PetPreferences>(
              valueListenable: PetService.instance.preferencesNotifier,
              builder: (context, petPrefs, _) {
                return Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      secondary: _settingsIconContainer(
                        Icons.pets,
                        const Color(0xFF6366F1),
                      ),
                      title: const Text(
                        'Pet Companion',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        petPrefs.enabled
                            ? '${petPrefs.name} is active on your dashboard'
                            : 'Companion is disabled',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: petPrefs.enabled,
                      onChanged: (val) async {
                        await PetService.instance.updatePreferences(
                          petPrefs.copyWith(enabled: val),
                        );
                        setState(() {});
                      },
                    ),
                    if (petPrefs.enabled) ...[
                      const Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFF1E294B),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: _settingsIconContainer(
                          Icons.tune,
                          const Color(0xFF10B981),
                        ),
                        title: const Text(
                          'Companion Settings & Appearance',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Coat: ${petPrefs.coatStyle.name} • ${petPrefs.totalPets} pats',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PetSettingsScreen(),
                            ),
                          ).then((_) => setState(() {}));
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Security Section — Fingerprint Unlock
          _sectionHeader('Security & Privacy'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  secondary: _settingsIconContainer(
                    Icons.lock_outline_rounded,
                    Colors.orange,
                  ),
                  title: const Text(
                    'App Lock PIN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Require 4-digit PIN to access vault',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _settings.appLock,
                  onChanged: (val) async {
                    if (val) {
                      await _setupAppPin();
                    } else {
                      final authenticated = await showSecureActionGate(
                        context,
                        title: 'Disable App Lock PIN',
                        message:
                            'Enter your PIN or authenticate to turn off App Lock.',
                      );
                      if (!authenticated) return;
                      await SecurityService.instance.removeAppPin();
                      _saveSettings(_settings.copyWith(appLock: false));
                    }
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF1E294B),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  secondary: _settingsIconContainer(
                    Icons.fingerprint_rounded,
                    Colors.blue,
                  ),
                  title: const Text(
                    'Fingerprint Unlock',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Use your fingerprint to unlock Reminder Hub',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _settings.biometricEnabled,
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (val) {
                      final isAvail = await SecurityService.instance
                          .isBiometricsAvailable();
                      if (!isAvail) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Fingerprint unlock isn\'t available on this device.',
                            ),
                          ),
                        );
                        return;
                      }
                      _saveSettings(_settings.copyWith(biometricEnabled: true));
                    } else {
                      final authenticated = await showSecureActionGate(
                        context,
                        title: 'Disable Fingerprint Unlock',
                        message: 'Authenticate to turn off fingerprint unlock.',
                      );
                      if (!authenticated) return;
                      _saveSettings(
                        _settings.copyWith(biometricEnabled: false),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notifications Section
          _sectionHeader('Notifications'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.notifications_active_outlined,
                    const Color(0xFF3B82F6),
                  ),
                  title: const Text(
                    'Allow Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Open Android notification permission settings',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: () => NotificationService.instance
                      .openAppNotificationSettings(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Backup & Restore Section
          _sectionHeader('Offline Backup & Restore'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.upload_file_outlined,
                    Colors.blue,
                  ),
                  title: const Text(
                    'Export Offline Backup',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Create a passphrase-encrypted database backup',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final passphrase = await showBackupPassphraseDialog(
                        context,
                        restoring: false,
                      );
                      if (passphrase == null || !mounted) return;
                      final path = await BackupService.instance.exportBackup(
                        passphrase: passphrase,
                      );
                      if (mounted && path != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Backup saved: $path')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not export backup: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF1E294B),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.download_for_offline_outlined,
                    Colors.green,
                  ),
                  title: const Text(
                    'Import Backup File',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Restore an encrypted backup or older JSON backup',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final shouldRestore = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Restore Full Backup?'),
                        content: const Text(
                          'This will replace the current local data with the selected backup. '
                          'Export a current backup first if you want to keep it.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    );
                    if (shouldRestore != true || !context.mounted) return;
                    final passphrase = await showBackupPassphraseDialog(
                      context,
                      restoring: true,
                    );
                    if (passphrase == null || !context.mounted) return;
                    bool success;
                    try {
                      success = await BackupService.instance.importBackup(
                        passphrase: passphrase,
                      );
                    } catch (error) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Could not restore backup: $error'),
                          ),
                        );
                      }
                      return;
                    }
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Backup imported successfully!'
                              : 'Failed to import backup',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFF1E294B),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: _settingsIconContainer(
                    Icons.delete_forever_outlined,
                    Colors.red,
                  ),
                  title: const Text(
                    'Clear All Local Data',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Wipe offline database completely',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.red,
                    size: 20,
                  ),
                  onTap: _confirmClearData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Google Drive Cloud Backup Section
          _sectionHeader('Google Drive Cloud Backup'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: ValueListenableBuilder<GoogleSignInAccount?>(
              valueListenable:
                  GoogleDriveBackupService.instance.currentUserNotifier,
              builder: (context, user, _) {
                final isConnected = user != null;
                final lastBackup = _settings.lastGoogleDriveBackupDate;
                String lastBackupSubtitle;
                if (lastBackup != null && lastBackup.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(lastBackup).toLocal();
                    lastBackupSubtitle =
                        'Last backup: ${Formatters.formatDate(dt)} at ${Formatters.formatTime(dt)}';
                  } catch (_) {
                    lastBackupSubtitle = 'Last backup: $lastBackup';
                  }
                } else {
                  lastBackupSubtitle = 'No cloud backups created yet';
                }

                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      leading: isConnected
                          ? CircleAvatar(
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.15,
                              ),
                              backgroundImage: user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl == null
                                  ? Text(
                                      user.displayName?.isNotEmpty == true
                                          ? user.displayName![0].toUpperCase()
                                          : 'G',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            )
                          : _settingsIconContainer(
                              Icons.cloud_sync_outlined,
                              Colors.blue,
                            ),
                      title: Text(
                        isConnected
                            ? (user.displayName ?? 'Google Account')
                            : 'Connect Google Account',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        isConnected
                            ? user.email
                            : 'Sign in to back up reminders & data to Google Drive',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isConnected
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: _handleGoogleSignOut,
                              child: const Text('Disconnect'),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: _handleGoogleSignIn,
                              child: const Text('Connect'),
                            ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0xFF1E294B),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: _settingsIconContainer(
                        Icons.cloud_upload_outlined,
                        Colors.blue,
                      ),
                      title: const Text(
                        'Back Up to Google Drive',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        lastBackupSubtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _isGoogleDriveBackingUp
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right, size: 20),
                      onTap: _isGoogleDriveBackingUp
                          ? null
                          : _handleGoogleDriveBackup,
                    ),
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0xFF1E294B),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: _settingsIconContainer(
                        Icons.cloud_download_outlined,
                        Colors.green,
                      ),
                      title: const Text(
                        'Restore from Google Drive',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Download and safely restore from cloud backup',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: _isGoogleDriveRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right, size: 20),
                      onTap: _isGoogleDriveRestoring
                          ? null
                          : _handleGoogleDriveRestore,
                    ),
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0xFF1E294B),
                    ),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      secondary: _settingsIconContainer(
                        Icons.sync_outlined,
                        Colors.teal,
                      ),
                      title: const Text(
                        'Auto-Backup to Cloud',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Prompts for a passphrase on startup; it is never saved',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _settings.autoGoogleDriveBackup,
                      onChanged: (val) async {
                        final updated = _settings.copyWith(
                          autoGoogleDriveBackup: val,
                        );
                        await _saveSettings(updated);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Feedback Section
          _sectionHeader('Feedback'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  minVerticalPadding: 12,
                  leading: _settingsIconContainer(
                    Icons.feedback_outlined,
                    const Color(0xFF14B8A6),
                  ),
                  title: const Text(
                    'Send Feedback',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Report bugs and suggest improvements',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: _isOpeningFeedback
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, size: 20),
                  onTap: _isOpeningFeedback ? null : _openFeedbackForm,
                ),
                const Divider(height: 1, indent: 20, endIndent: 20),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    'Feedback opens through Google Forms. Information you choose to submit, including your email address if requested, is collected through Google Forms. ReminderHub does not automatically send your personal app data with this feedback.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About Section
          _sectionHeader('About & Creator'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: _settingsIconContainer(
                Icons.info_outline_rounded,
                const Color(0xFF6366F1),
              ),
              title: const Text(
                'About Reminder Hub',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Why Reminder Hub was created • Developer info',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _openFeedbackForm() async {
    if (_isOpeningFeedback) return;
    setState(() => _isOpeningFeedback = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = FeedbackService.responderUri;
      if (uri == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The feedback form link is unavailable.')),
        );
        return;
      }
      final opened = await FeedbackService.openFeedbackForm();
      if (!mounted) return;
      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Google Forms. Check your internet connection and try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not open the feedback form. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningFeedback = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await GoogleDriveBackupService.instance.signIn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account connected.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to Google: $error')),
      );
    }
  }

  Future<void> _handleGoogleSignOut() async {
    try {
      await GoogleDriveBackupService.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account disconnected.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not disconnect Google account: $error')),
      );
    }
  }

  Future<void> _handleGoogleDriveBackup() async {
    if (_isGoogleDriveBackingUp) return;
    final passphrase = await showBackupPassphraseDialog(
      context,
      restoring: false,
    );
    if (passphrase == null || !mounted) return;
    setState(() => _isGoogleDriveBackingUp = true);
    try {
      final result = await GoogleDriveBackupService.instance.createBackup(
        passphrase: passphrase,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Backup uploaded to Google Drive.'
                : 'Backup failed: ${result.errorMessage ?? 'Unknown error'}',
          ),
        ),
      );
      if (result.success) {
        await _loadSettings();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $error')));
    } finally {
      if (mounted) setState(() => _isGoogleDriveBackingUp = false);
    }
  }

  Future<void> _handleGoogleDriveRestore() async {
    if (_isGoogleDriveRestoring) return;
    setState(() => _isGoogleDriveRestoring = true);
    try {
      final backups = await GoogleDriveBackupService.instance.listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Google Drive backups were found.')),
        );
        return;
      }

      final selectedBackup = await showDialog<GoogleDriveBackupFile>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Choose a backup to restore'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final backup in backups)
                  ListTile(
                    title: Text(backup.name),
                    subtitle: Text(Formatters.formatDate(backup.createdTime)),
                    onTap: () => Navigator.of(dialogContext).pop(backup),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selectedBackup == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: const Text(
            'Restoring replaces the current local data. A safety snapshot will be used if the restore fails.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final passphrase = await showBackupPassphraseDialog(
        context,
        restoring: true,
      );
      if (passphrase == null || !mounted) return;
      final result = await GoogleDriveBackupService.instance.restoreBackup(
        selectedBackup.id,
        passphrase: passphrase,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? 'Backup restored successfully.'
                : 'Restore failed: ${result.errorMessage ?? 'Unknown error'}',
          ),
        ),
      );
      if (result.success) await _loadSettings();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore Google Drive backup: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleDriveRestoring = false);
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _settingsIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _defaultAvatar(String initial) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Future<void> _editUserName() async {
    final controller = TextEditingController(text: _settings.userName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
        title: const Text(
          'Edit Profile Name',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _saveSettings(
                  _settings.copyWith(userName: controller.text.trim()),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupAppPin() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
        title: const Text(
          'Set Security PIN',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(labelText: '4-Digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = controller.text.trim();
              if (pin.length == 4) {
                await SecurityService.instance.setAppPin(pin);
                _saveSettings(_settings.copyWith(appLock: true));
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
        title: const Text(
          'Wipe All Local Data?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will delete all reminders, bills, AI accounts, credentials, and gas records. Action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await NotificationService.instance.cancelAll();
              await _hive.clearAll();
              await WidgetService.instance.updateSchoolWidget();
              await WidgetService.instance.updateBillsWidget();
              messenger.showSnackBar(
                const SnackBar(content: Text('All data cleared successfully.')),
              );
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
