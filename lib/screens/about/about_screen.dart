import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/whats_new_dialog.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Reminder Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // App Logo & Header Banner
          Center(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.alarm_on_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reminder Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your personal companion for remembering\nthe things that matter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Version ${AppConstants.appVersion} • 100% Offline & Private',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Builder(
            builder: (context) {
              final release = WhatsNewRegistry.getRelease(
                AppConstants.appVersion,
              );
              if (release == null) return const SizedBox.shrink();
              return CustomCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF6366F1),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What\'s New',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Version ${release.version} • See what\'s new and improved.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => WhatsNewDialog.show(
                        context,
                        release: release,
                        onDismissed: () {},
                      ),
                      child: const Text('View Updates'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Why Reminder Hub Was Created ─────────────────────────────────
          CustomCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFF14B8A6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Why Reminder Hub Was Created',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Reminder Hub was created from a simple personal need: staying on top of passwords, school schedules, reminders, and important bills can be difficult when there are so many things to remember. As someone who often forgets important details and deadlines, I wanted to create one application that could help me stay organized and remind me of the things that matter.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reminder Hub was built to serve as a personal companion that helps me remember, organize, and manage the things I might otherwise forget.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'What started as a solution to my own everyday struggles became an application designed around one simple idea:',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'If there are important things you might forget, let Reminder Hub help you remember them.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF0D9488),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Core Highlights
          CustomCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Core Highlights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _featureItem(
                  Icons.school_rounded,
                  const Color(0xFF14B8A6),
                  'School & Study Timer',
                  'Manage class schedules and open the Pomodoro Study Timer from the School section.',
                  isDark,
                ),
                _featureItem(
                  Icons.dashboard_customize_rounded,
                  const Color(0xFF8B5CF6),
                  'Active AI Reset Dashboard',
                  'Reset availability follows each account’s saved local date and time. Accounts become active automatically when their reset arrives.',
                  isDark,
                ),
                _featureItem(
                  Icons.visibility_outlined,
                  const Color(0xFF10B981),
                  'Password Visibility Controls',
                  'Eye buttons only reveal or hide saved passwords. Accounts without a saved password are identified clearly.',
                  isDark,
                ),
                _featureItem(
                  Icons.alarm_rounded,
                  const Color(0xFF6366F1),
                  'Reminders & Smart Notifications',
                  'Never miss important tasks, deadlines, or recurring responsibilities.',
                  isDark,
                ),
                _featureItem(
                  Icons.receipt_long_rounded,
                  const Color(0xFFF59E0B),
                  'Bills & Gas Tracker',
                  'Track utilities, due dates, and household LPG consumption offline.',
                  isDark,
                ),
                _featureItem(
                  Icons.security_rounded,
                  const Color(0xFF10B981),
                  'Offline-First & Biometric Lock',
                  'All data remains stored locally on your device with PIN & Fingerprint protection.',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Developer Section (Bottom of the page) ────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A2E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E294B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'Open developer profile photo',
                  child: GestureDetector(
                    key: const ValueKey('developer_profile_photo'),
                    onTap: () => _showDeveloperProfile(context),
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/Developer Profile.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(-0.35, -0.38),
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppConstants.primaryColor,
                                alignment: Alignment.center,
                                child: const Text(
                                  'J',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Developer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Junjifil Jr. Castro',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your 6\'2 Developer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Developer of Reminder Hub',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showDeveloperProfile(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: Semantics(
          label: 'Zoomable developer profile photo',
          child: ClipOval(
            child: Container(
              width: 300,
              height: 300,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(24),
                clipBehavior: Clip.hardEdge,
                child: Image.asset(
                  'assets/images/Developer Profile.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(-0.35, -0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureItem(
    IconData icon,
    Color color,
    String title,
    String desc,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
