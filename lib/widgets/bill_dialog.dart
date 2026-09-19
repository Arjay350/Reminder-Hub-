import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/utilities/formatters.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class BillDialog extends StatefulWidget {
  const BillDialog({super.key, this.bill});

  final Bill? bill;

  @override
  State<BillDialog> createState() => _BillDialogState();
}

class _BillDialogState extends State<BillDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late double _amount;
  late DateTime _dueDate;
  late String _repeat;
  late String _category;
  late bool _paid;
  late String _reminderSchedule;
  late String _resetSchedule;
  late String _notes;

  final List<String> _categories = [
    'Utilities',
    'Internet',
    'Rent / Mortgage',
    'Insurance',
    'Credit Card',
    'Subscription',
    'Other',
  ];

  final List<String> _repeats = ['None', 'Monthly', 'Yearly'];
  final List<String> _reminderSchedules = [
    'Same day',
    '1 day before',
    '2 days before',
    '3 days before',
    '5 days before',
    '1 week before',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _name = b?.name ?? '';
    _amount = b?.amount ?? 0.0;
    _dueDate = b?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _repeat = b?.repeat ?? 'Monthly';
    _category = b?.category ?? 'Utilities';
    _paid = b?.paid ?? false;
    _reminderSchedule = b?.reminderSchedule ?? '3 days before';
    _resetSchedule = b?.resetSchedule ?? _reminderSchedule;
    _notes = b?.notes ?? '';
  }

  String _getRecurrenceHint() {
    final dueStr = DateFormat('MMM dd, yyyy').format(_dueDate);
    switch (_repeat) {
      case 'Monthly':
        return '🔔 Repeats every month on day ${_dueDate.day} ($_reminderSchedule)';
      case 'Yearly':
        return '🔔 Repeats every year on ${DateFormat('MMMM d').format(_dueDate)} ($_reminderSchedule)';
      default:
        return '🔔 Fires once for due date: $dueStr ($_reminderSchedule)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bill != null;
    final paymentHistory = widget.bill?.paymentHistory ?? [];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Bill' : 'New Bill',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: 'Bill Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.receipt_long),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter bill name'
                    : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _amount == 0.0 ? '' : _amount.toString(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                validator: (val) => val == null || double.tryParse(val) == null
                    ? 'Please enter valid amount'
                    : null,
                onSaved: (val) => _amount = double.parse(val!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 1825),
                          ),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_dueDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _category = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _repeat,
                      decoration: InputDecoration(
                        labelText: 'Repeat',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _repeats
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _repeat = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _reminderSchedule,
                      decoration: InputDecoration(
                        labelText: 'Remind Before',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _reminderSchedules
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _reminderSchedule = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _resetSchedule,
                decoration: InputDecoration(
                  labelText: 'Reset to Unpaid',
                  helperText:
                      'Recurring bills become unpaid at this point before the next due date.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.restart_alt_rounded),
                ),
                items: _reminderSchedules
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _resetSchedule = val!),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _getRecurrenceHint(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                _buildCurrentOccurrenceStatus(widget.bill!),
              ],
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _notes,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.notes),
                ),
                onSaved: (val) => _notes = val ?? '',
              ),

              // ── Payment History Section (edit mode only) ──────────────────
              if (isEditing) ...[
                const SizedBox(height: 16),
                const Text(
                  'Payment History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (paymentHistory.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No payment history yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: paymentHistory.reversed.map((payment) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          title: Text(
                            Formatters.formatDate(payment.occurrenceDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Paid on ${Formatters.formatDate(payment.paidDate)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            Formatters.formatCurrency(payment.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],

              // ─────────────────────────────────────────────────────────────
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as Paid'),
                value: _paid,
                onChanged: (val) => setState(() => _paid = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update Bill' : 'Save Bill',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentOccurrenceStatus(Bill bill) {
    final status = bill.getDisplayStatus();
    final displayDueDate = bill.getDisplayDueDate();
    final statusLabel = bill.getStatusLabel();
    final payment = bill.getCurrentPayment();

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'unpaid':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'upcoming':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'Current Status: $statusLabel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Due: ${Formatters.formatDate(displayDueDate)}',
            style: TextStyle(
              fontSize: 11,
              color: statusColor.withValues(alpha: 0.8),
            ),
          ),
          if (payment != null) ...[
            const SizedBox(height: 4),
            Text(
              'Paid on ${Formatters.formatDate(payment.paidDate)}',
              style: TextStyle(
                fontSize: 11,
                color: statusColor.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (status == 'upcoming') ...[
            const SizedBox(height: 4),
            Text(
              'Due in ${bill.getDaysUntilDue()} days',
              style: TextStyle(
                fontSize: 11,
                color: statusColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final bill = Bill(
      id: widget.bill?.id ?? const Uuid().v4(),
      name: _name,
      amount: _amount,
      dueDate: _dueDate,
      repeat: _repeat,
      category: _category,
      paid: _paid,
      reminderSchedule: _reminderSchedule,
      resetSchedule: _resetSchedule,
      notes: _notes,
      // Preserve existing payment history — never clear it on edit
      paymentHistory: widget.bill?.paymentHistory,
    );

    await HiveService.instance.saveBill(bill);
    await NotificationService.instance.scheduleBillNotification(bill);
    if (mounted) Navigator.pop(context, bill);
  }
}
