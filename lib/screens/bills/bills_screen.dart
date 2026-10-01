import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_service.dart';
import '../../services/pet_service.dart';
import '../../widgets/bill_dialog.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final HiveService _hive = HiveService.instance;

  List<Bill> _bills = [];
  String _selectedFilter = 'Unpaid'; // All, Unpaid, Paid

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _bills = _hive.getBills();
    });
    PetService.instance.onBillsChecked();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _bills.where((b) {
      final s = b.getDisplayStatus();
      if (_selectedFilter == 'Unpaid' && s == 'paid') return false;
      if (_selectedFilter == 'Paid' && s != 'paid') return false;
      return true;
    }).toList();

    filtered.sort(
      (a, b) => a.getDisplayDueDate().compareTo(b.getDisplayDueDate()),
    );

    final totalUnpaidAmount = _bills
        .where((b) => b.getDisplayStatus() != 'paid')
        .fold(0.0, (sum, item) => sum + item.amount);

    final unpaidCount = _bills
        .where((b) => b.getDisplayStatus() != 'paid')
        .length;
    final paidCount = _bills
        .where((b) => b.getDisplayStatus() == 'paid')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bills Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Total Unpaid Summary Banner - styled premium
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Upcoming Unpaid',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatCurrency(totalUnpaidAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),

          // Filter Segmented Buttons - styled clean
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _filterChip('Unpaid', 'Unpaid ($unpaidCount)'),
                const SizedBox(width: 8),
                _filterChip('Paid', 'Paid ($paidCount)'),
                const SizedBox(width: 8),
                _filterChip('All', 'All (${_bills.length})'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: _bills.isEmpty ? 'No bills yet' : 'All caught up',
                    message: _bills.isEmpty
                        ? 'Add your first bill to keep upcoming payments in view.'
                        : 'There are no bills in this view right now.',
                    icon: Icons.receipt_outlined,
                    actionLabel: 'Add Bill',
                    onAction: _openAddDialog,
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final bill = filtered[index];
                        final displayStatus = bill.getDisplayStatus();
                        final displayDueDate = bill.getDisplayDueDate();
                        final isOverdue = displayStatus == 'overdue';
                        final isPaid = displayStatus == 'paid';
                        final today = DateUtils.dateOnly(DateTime.now());
                        final dueDay = DateUtils.dateOnly(displayDueDate);
                        final daysUntilDue = dueDay.difference(today).inDays;
                        final urgencyColor = isOverdue
                            ? Colors.red
                            : isPaid
                            ? Colors.green
                            : daysUntilDue <= 3
                            ? Colors.orange
                            : Colors.blue;
                        final urgencyLabel = isPaid
                            ? 'PAID'
                            : isOverdue
                            ? 'OVERDUE BY ${-daysUntilDue}D'
                            : daysUntilDue == 0
                            ? 'DUE TODAY'
                            : daysUntilDue <= 3
                            ? 'DUE IN ${daysUntilDue}D'
                            : 'UPCOMING';

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 325),
                          child: SlideAnimation(
                            verticalOffset: 40.0,
                            child: FadeInAnimation(
                              child: Dismissible(
                                key: Key(bill.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  return await showConfirmDeleteDialog(
                                    context,
                                    title: 'Delete Bill?',
                                    message: bill.paymentHistory.isNotEmpty
                                        ? 'This will permanently delete "${bill.name}" and its ${bill.paymentHistory.length} payment record(s). This action cannot be undone.'
                                        : 'This action cannot be undone. Are you sure you want to permanently delete this bill record?',
                                  );
                                },
                                onDismissed: (_) async {
                                  await NotificationService.instance
                                      .cancelNotificationForId(bill.id);
                                  await _hive.deleteBill(bill.id);
                                  try {
                                    await WidgetService.instance
                                        .updateBillsWidget();
                                  } catch (_) {}
                                  _loadBills();
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: CustomCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    onTap: () => _openEditDialog(bill),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isOverdue
                                              ? Colors.red.withValues(
                                                  alpha: 0.12,
                                                )
                                              : isPaid
                                              ? Colors.green.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.blue.withValues(
                                                  alpha: 0.12,
                                                ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          color: isOverdue
                                              ? Colors.red
                                              : isPaid
                                              ? Colors.green
                                              : Colors.blue,
                                          size: 22,
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  Formatters.formatCurrency(
                                                    bill.amount,
                                                  ),
                                                  style: TextStyle(
                                                    color: isPaid
                                                        ? Colors.grey
                                                        : null,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -.4,
                                                  ),
                                                ),
                                              ),
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: urgencyColor
                                                      .withValues(alpha: .12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  urgencyLabel,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: urgencyColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  bill.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    decoration: isPaid
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: isPaid
                                                        ? Colors.grey
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              if (bill.isRecurring)
                                                Text(
                                                  bill.repeat,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Due ${Formatters.formatDate(displayDueDate)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isOverdue
                                                    ? Colors.red
                                                    : (isDark
                                                          ? Colors.grey.shade400
                                                          : Colors
                                                                .grey
                                                                .shade600),
                                                fontWeight: isOverdue
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            if (!isPaid)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 7,
                                                  right: 12,
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: TweenAnimationBuilder<double>(
                                                    tween: Tween(
                                                      end: isOverdue
                                                          ? 1.0
                                                          : ((7 - daysUntilDue) /
                                                                    7)
                                                                .clamp(0.0, 1.0),
                                                    ),
                                                    duration: const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, value, _) =>
                                                        LinearProgressIndicator(
                                                          value: value,
                                                          minHeight: 4,
                                                          color: urgencyColor,
                                                          backgroundColor:
                                                              urgencyColor
                                                                  .withValues(
                                                                    alpha: .12,
                                                                  ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            if (bill.paymentHistory.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2.0,
                                                ),
                                                child: Text(
                                                  '${bill.paymentHistory.length} previous payment(s)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.green.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      isThreeLine: true,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: isPaid
                                                  ? Colors.green.withValues(
                                                      alpha: .12,
                                                    )
                                                  : urgencyColor.withValues(
                                                      alpha: .10,
                                                    ),
                                            ),
                                            icon: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              transitionBuilder:
                                                  (child, animation) =>
                                                      ScaleTransition(
                                                        scale: animation,
                                                        child: child,
                                                      ),
                                              child: Icon(
                                                isPaid
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                          .radio_button_unchecked_rounded,
                                                key: ValueKey(isPaid),
                                                color: isPaid
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                            ),
                                            tooltip: isPaid
                                                ? 'Mark as Unpaid'
                                                : 'Mark as Paid',
                                            onPressed: () =>
                                                _togglePaidStatus(bill),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'Bill options',
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _openEditDialog(bill);
                                              } else if (value == 'delete') {
                                                _deleteBill(bill);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                  title: Text('Edit bill'),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: ListTile(
                                                  leading: Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  title: Text('Delete bill'),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.more_vert_rounded,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Bill'),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: FilterChip(
        label: Center(child: Text(label, style: const TextStyle(fontSize: 12))),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = value),
        selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF10B981),
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? const Color(0xFF10B981)
              : (isDark ? Colors.grey.shade300 : Colors.black87),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Future<void> _togglePaidStatus(Bill bill) async {
    // Toggling OFF (currently paid non-recurring bill -> unmark paid)
    if (bill.paid) {
      final updated = bill.copyWith(paid: false);
      await _hive.saveBill(updated);
      await NotificationService.instance.scheduleBillNotification(updated);
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (_) {}
      _loadBills();
      if (mounted) _showPaymentFeedback('Marked as unpaid');
      return;
    }

    // Toggling ON for non-recurring bill: simple mark as paid
    if (!bill.isRecurring) {
      final updated = bill.copyWith(paid: true);
      await _hive.saveBill(updated);
      PetService.instance.onBillPaid(updated);
      await NotificationService.instance.cancelNotificationForId(bill.id);
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (_) {}
      _loadBills();
      if (mounted) _showPaymentFeedback('Bill marked as paid');
      return;
    }

    // Recurring bill: calculate next occurrence and show confirmation
    final nextDate = bill.getNextOccurrence(bill.dueDate);

    if (!mounted) return;
    final confirmed = await _showRecurringPayConfirmation(
      bill,
      bill.dueDate,
      nextDate,
    );
    if (!confirmed || !mounted) return;

    // Step 1: Record completed occurrence in payment history
    final payment = BillPayment(
      occurrenceDate: bill.dueDate,
      paidDate: DateTime.now(),
      amount: bill.amount,
    );
    final newHistory = [...bill.paymentHistory, payment];

    // Step 2 & 3: Advance dueDate to next occurrence and reset paid to false
    final updated = bill.copyWith(
      dueDate: nextDate,
      paid: false,
      paymentHistory: newHistory,
    );

    // Step 4: Persist updated bill to Hive
    await _hive.saveBill(updated);
    PetService.instance.onBillPaid(updated);

    // Step 5: Cancel old notification and schedule notification for new occurrence
    await NotificationService.instance.cancelNotificationForId(bill.id);
    await NotificationService.instance.scheduleBillNotification(updated);

    // Update Bills widget
    try {
      await WidgetService.instance.updateBillsWidget();
    } catch (e) {
      debugPrint('WidgetService.updateBillsWidget error: $e');
    }

    _loadBills();
    if (mounted) _showPaymentFeedback('Payment recorded');
  }

  void _showPaymentFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(message),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Shows confirmation dialog explaining the recurring-bill lifecycle before
  /// completing the current occurrence.
  Future<bool> _showRecurringPayConfirmation(
    Bill bill,
    DateTime currentDate,
    DateTime nextDate,
  ) async {
    final currentDateStr = Formatters.formatDate(currentDate);
    final nextDateStr = Formatters.formatDate(nextDate);
    final settings = _hive.getSettings();
    final currency = settings.currency;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Mark Bill as Paid?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bill.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '$currency${bill.amount.toStringAsFixed(2)} • Due $currentDateStr',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'After marking as paid:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _confirmBullet(
              '$currentDateStr will be recorded in payment history',
            ),
            _confirmBullet('The next bill will be due $nextDateStr'),
            _confirmBullet('The new $nextDateStr bill will be marked UNPAID'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BillDialog(),
    );
    if (result != null) {
      _loadBills();
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (e) {
        debugPrint('WidgetService.updateBillsWidget error: $e');
      }
    }
  }

  Future<void> _openEditDialog(Bill bill) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BillDialog(bill: bill),
    );
    if (result != null) {
      _loadBills();
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (e) {
        debugPrint('WidgetService.updateBillsWidget error: $e');
      }
    }
  }

  Future<void> _deleteBill(Bill bill) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Bill?',
      message: bill.paymentHistory.isNotEmpty
          ? 'This will permanently delete "${bill.name}" and its ${bill.paymentHistory.length} payment record(s). This action cannot be undone.'
          : 'This action cannot be undone. Are you sure you want to permanently delete this bill record?',
    );
    if (confirm) {
      await NotificationService.instance.cancelNotificationForId(bill.id);
      await _hive.deleteBill(bill.id);
      try {
        await WidgetService.instance.updateBillsWidget();
      } catch (e) {
        debugPrint('WidgetService.updateBillsWidget error: $e');
      }
      _loadBills();
    }
  }
}
