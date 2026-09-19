import 'package:flutter/material.dart';
import 'reminder_dialog.dart';
import 'bill_dialog.dart';
import 'ai_account_dialog.dart';
import 'user_account_dialog.dart';
import 'gas_purchase_dialog.dart';
import 'school_class_dialog.dart';

class QuickAddModal extends StatelessWidget {
  const QuickAddModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E294B) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E294B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Add Entry',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _quickOption(
            context,
            title: 'Add Reminder',
            subtitle: 'Personal tasks, meetings, recurring alerts',
            icon: Icons.add_alert_rounded,
            color: const Color(0xFF6366F1),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ReminderDialog(),
              );
            },
          ),
          const SizedBox(height: 12),
          _quickOption(
            context,
            title: 'Add Bill',
            subtitle: 'Recurring utility bills, rent, internet',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const BillDialog(),
              );
            },
          ),
          const SizedBox(height: 12),
          _quickOption(
            context,
            title: 'Add AI Account',
            subtitle: 'ChatGPT, Claude, Gemini reset schedules',
            icon: Icons.smart_toy_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AIAccountDialog(),
              );
            },
          ),
          const SizedBox(height: 12),
          _quickOption(
            context,
            title: 'Add Login Account',
            subtitle: 'Websites, apps, password credential manager',
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const UserAccountDialog(),
              );
            },
          ),
          const SizedBox(height: 12),
          _quickOption(
            context,
            title: 'Add Class Schedule',
            subtitle: 'Recurring school classes, rooms & instructors',
            icon: Icons.school_rounded,
            color: const Color(0xFF14B8A6),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const SchoolClassDialog(),
              );
            },
          ),
          const SizedBox(height: 12),
          _quickOption(
            context,
            title: 'Add LPG Order',
            subtitle: 'Record LPG/Gas refill & estimate empty date',
            icon: Icons.propane_tank_rounded,
            color: const Color(0xFFEF4444),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const GasPurchaseDialog(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E294B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }
}
