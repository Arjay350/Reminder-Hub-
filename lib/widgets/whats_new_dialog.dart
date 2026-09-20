import 'package:flutter/material.dart';

class WhatsNewItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const WhatsNewItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

class WhatsNewRelease {
  final String version;
  final String releaseDate;
  final String title;
  final String appTitle;
  final String subtitle;
  final List<WhatsNewItem> items;

  const WhatsNewRelease({
    required this.version,
    this.releaseDate = '',
    required this.title,
    required this.appTitle,
    required this.subtitle,
    required this.items,
  });
}

class WhatsNewRegistry {
  static const Map<String, WhatsNewRelease> releases = {
    '1.3.1': WhatsNewRelease(
      version: '1.3.1',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.3.1',
      subtitle: 'Portable backups and safer schedule sharing.',
      items: [
        WhatsNewItem(
          icon: Icons.backup_rounded,
          iconColor: Color(0xFF6366F1),
          title: 'Backup and Restore',
          description:
              'Export and restore your complete Reminder Hub data from a user-selected folder using versioned JSON backups.',
        ),
        WhatsNewItem(
          icon: Icons.share_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'School Schedule Sharing',
          description:
              'Share only school schedule data with classmates and import it with validation and duplicate handling. Personal financial data is never included.',
        ),
        WhatsNewItem(
          icon: Icons.notifications_active_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Reliable Scheduled Notifications',
          description:
              'School schedules, reminders, bills, and AI reset alerts now use more reliable scheduling with Android alarm fallbacks.',
        ),
        WhatsNewItem(
          icon: Icons.menu_book_rounded,
          iconColor: Color(0xFF8B5CF6),
          title: 'Offline Study Materials',
          description:
              'Import PDF, DOCX, TXT, and image materials, then generate rule-based reviewers, quizzes, and flashcards entirely on your device.',
        ),
        WhatsNewItem(
          icon: Icons.refresh_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Fresh Reminders Hub List Updates',
          description:
              'New, edited, completed, and deleted reminders now appear in Reminders Hub without stale list data.',
        ),
        WhatsNewItem(
          icon: Icons.widgets_rounded,
          iconColor: Color(0xFF8B5CF6),
          title: 'Improved School and Bills Widgets',
          description:
              'School Schedule and Bills widgets refresh more reliably with current schedule and payment status information.',
        ),
        WhatsNewItem(
          icon: Icons.open_in_new_rounded,
          iconColor: Color(0xFF10B981),
          title: 'Widget Navigation Fixes',
          description:
              'Widget actions now open Reminder Hub first and then navigate to the requested School Schedule or Bills screen.',
        ),
        WhatsNewItem(
          icon: Icons.history_rounded,
          iconColor: Color(0xFFF59E0B),
          title: 'Preserved Paid Bill History',
          description:
              'Paid bill occurrences and payment history remain available in Bills Tracker.',
        ),
        WhatsNewItem(
          icon: Icons.delete_sweep_rounded,
          iconColor: Color(0xFFEF4444),
          title: 'Removed Notification History',
          description:
              'The unused notification history screen and records were removed while bill payment history was preserved.',
        ),
      ],
    ),
    '1.3.0': WhatsNewRelease(
      version: '1.3.0',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.3.0',
      subtitle: 'Safer backups and portable school schedules.',
      items: [
        WhatsNewItem(
          icon: Icons.folder_open_rounded,
          iconColor: Color(0xFF6366F1),
          title: 'Choose Your Backup Folder',
          description:
              'Save complete offline backups directly to a folder you choose and restore every local module and setting.',
        ),
        WhatsNewItem(
          icon: Icons.school_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Portable School Schedules',
          description:
              'Export, share, and import validated school schedules with duplicate replace, add, or cancel options.',
        ),
        WhatsNewItem(
          icon: Icons.notifications_active_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Schedules Stay Active',
          description:
              'Restored reminders and classes automatically reschedule notifications and refresh home-screen widgets.',
        ),
      ],
    ),
    '1.2.4': WhatsNewRelease(
      version: '1.2.4',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.2.4',
      subtitle: 'Smoother widget launches and safer live widget updates.',
      items: [
        WhatsNewItem(
          icon: Icons.open_in_new_rounded,
          iconColor: Color(0xFF10B981),
          title: 'Reliable Widget Navigation',
          description:
              'View Schedule and View Bills now open the app safely after cold starts, app unlock, and repeated widget taps.',
        ),
        WhatsNewItem(
          icon: Icons.sync_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Live Widget Refresh',
          description:
              'School Schedule and Bills widget updates continue to refresh from native Android alarms and invalidate their list data.',
        ),
      ],
    ),
    '1.2.3': WhatsNewRelease(
      version: '1.2.3',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.2.3',
      subtitle:
          'More reliable notifications, reminders, and home-screen widgets.',
      items: [
        WhatsNewItem(
          icon: Icons.notifications_active_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Reliable Scheduled Notifications',
          description:
              'School schedules, reminders, and bills now select the correct Android alarm mode when exact-alarm access is unavailable.',
        ),
        WhatsNewItem(
          icon: Icons.refresh_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Fresh Reminders List',
          description:
              'New and edited reminders now appear in Reminders Hub immediately, including after returning to the app.',
        ),
        WhatsNewItem(
          icon: Icons.widgets_rounded,
          iconColor: Color(0xFF8B5CF6),
          title: 'Improved Widgets',
          description:
              'School Schedule and Bills widgets refresh more reliably, with live schedule and bill status updates.',
        ),
        WhatsNewItem(
          icon: Icons.open_in_new_rounded,
          iconColor: Color(0xFF10B981),
          title: 'Widget Navigation Fix',
          description:
              'Tapping View Schedule or View Bills now waits for the app to finish starting or unlock before opening the correct screen.',
        ),
        WhatsNewItem(
          icon: Icons.history_rounded,
          iconColor: Color(0xFFF59E0B),
          title: 'Bill Payment History Preserved',
          description:
              'Paid bill occurrences remain available in Bills Tracker while notification history has been removed.',
        ),
      ],
    ),
    '1.2.2': WhatsNewRelease(
      version: '1.2.2',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.2.2',
      subtitle: 'Safer data, steadier schedules, and more accurate tracking.',
      items: [
        WhatsNewItem(
          icon: Icons.cleaning_services_rounded,
          iconColor: Color(0xFFEF4444),
          title: 'Cleaner Data Reset',
          description:
              'Clearing local data now also removes scheduled notifications so deleted reminders cannot fire later.',
        ),
        WhatsNewItem(
          icon: Icons.restore_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Reliable Backup Restore',
          description:
              'Importing a backup now replaces old records, refreshes widgets, and restores scheduled notifications.',
        ),
        WhatsNewItem(
          icon: Icons.lock_rounded,
          iconColor: Color(0xFF8B5CF6),
          title: 'Improved App Lock',
          description:
              'App Lock now activates again when Reminder Hub is sent to the background.',
        ),
        WhatsNewItem(
          icon: Icons.calendar_month_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Sunday School Schedules',
          description:
              'Sunday classes now appear in schedule filters and the weekly timetable.',
        ),
        WhatsNewItem(
          icon: Icons.propane_tank_rounded,
          iconColor: Color(0xFFF97316),
          title: 'More Accurate LPG History',
          description:
              'Current tanks count through today, while previous tanks stop counting when the replacement tank is ordered.',
        ),
        WhatsNewItem(
          icon: Icons.shield_rounded,
          iconColor: Color(0xFF10B981),
          title: 'Stronger Data Recovery',
          description:
              'A damaged local record no longer prevents other valid reminders, bills, accounts, or LPG records from loading.',
        ),
      ],
    ),
    '1.2.1': WhatsNewRelease(
      version: '1.2.1',
      releaseDate: '2026-09-11',
      title: 'What\'s New',
      appTitle: 'Reminder Hub 1.2.1',
      subtitle: 'More reliable reminders and safer account tracking.',
      items: [
        WhatsNewItem(
          icon: Icons.notifications_active_rounded,
          iconColor: Color(0xFF3B82F6),
          title: 'Notification Fixes',
          description:
              'Fixed due-date notifications for Bills, AI reset alerts, and regular Reminders so saved schedules are rescheduled consistently.',
        ),
        WhatsNewItem(
          icon: Icons.receipt_long_rounded,
          iconColor: Color(0xFFF59E0B),
          title: 'Bill Due Dates',
          description:
              'Bills now keep their current occurrence, payment history, and reminder timing when edited or marked paid.',
        ),
        WhatsNewItem(
          icon: Icons.restart_alt_rounded,
          iconColor: Color(0xFF10B981),
          title: 'Automatic Bill Reset',
          description:
              'Choose when a recurring bill becomes unpaid again, such as 1 or 3 days before its next due date.',
        ),
        WhatsNewItem(
          icon: Icons.propane_tank_rounded,
          iconColor: Color(0xFFEF4444),
          title: 'Accurate LPG Tracking',
          description:
              'Tank duration now counts the order day correctly. LPG tracking focuses on how long each tank lasted without predicting refills.',
        ),
        WhatsNewItem(
          icon: Icons.fingerprint_rounded,
          iconColor: Color(0xFF8B5CF6),
          title: 'Biometric Password Protection',
          description:
              'Showing a saved Account Manager password now requires fingerprint or another enrolled biometric.',
        ),
        WhatsNewItem(
          icon: Icons.account_balance_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Finance Account Numbers',
          description:
              'Finance accounts can now store an account number without adding it to other account categories.',
        ),
        WhatsNewItem(
          icon: Icons.verified_user_rounded,
          iconColor: Color(0xFF14B8A6),
          title: 'Safer Data Updates',
          description:
              'Existing bills, payment history, reminders, accounts, LPG orders, and settings remain available after updating.',
        ),
      ],
    ),
  };

  static WhatsNewRelease? getRelease(String version) {
    return releases[version];
  }
}

class WhatsNewDialog extends StatefulWidget {
  const WhatsNewDialog({
    super.key,
    required this.release,
    required this.onDismissed,
  });

  final WhatsNewRelease release;
  final VoidCallback onDismissed;

  @override
  State<WhatsNewDialog> createState() => _WhatsNewDialogState();

  static Future<void> show(
    BuildContext context, {
    required WhatsNewRelease release,
    required VoidCallback onDismissed,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => WhatsNewDialog(
        release: release,
        onDismissed: () {
          onDismissed();
          Navigator.of(dialogContext, rootNavigator: true).pop();
        },
      ),
    );
  }
}

class _WhatsNewDialogState extends State<WhatsNewDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.release.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Version ${widget.release.version}',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.release.subtitle,
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
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.release.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = widget.release.items[index];
                    return _WhatsNewListItem(item: item, isDark: isDark);
                  },
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: widget.onDismissed,
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsNewListItem extends StatelessWidget {
  const _WhatsNewListItem({required this.item, required this.isDark});

  final WhatsNewItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.iconColor.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: isDark
                        ? Colors.grey.shade300
                        : const Color(0xFF475569),
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

class WhatsNewFlashCards extends StatefulWidget {
  const WhatsNewFlashCards({
    super.key,
    required this.release,
    this.controller,
    this.onPageChanged,
    this.onCardTapped,
  });

  final WhatsNewRelease release;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onCardTapped;

  @override
  State<WhatsNewFlashCards> createState() => _WhatsNewFlashCardsState();
}

class _WhatsNewFlashCardsState extends State<WhatsNewFlashCards> {
  PageController? _internalController;
  int _currentPage = 0;

  PageController get _controller => widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _internalController = PageController();
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _showNextCard() {
    final nextPage = (_currentPage + 1) % widget.release.items.length;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.release.items.length,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              widget.onPageChanged?.call(page);
            },
            itemBuilder: (context, index) {
              final item = widget.release.items[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCardTapped ?? _showNextCard,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(
                      alpha: isDark ? 0.16 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: item.iconColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: item.iconColor, size: 42),
                        const SizedBox(height: 18),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark
                                ? Colors.grey.shade300
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Tap to continue',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.iconColor,
                            fontWeight: FontWeight.w700,
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
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.release.items.length,
            (index) => Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: index == _currentPage ? 0.9 : 0.25,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
