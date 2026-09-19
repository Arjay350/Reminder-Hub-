import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';

class GasPurchaseDialog extends StatefulWidget {
  const GasPurchaseDialog({super.key, this.purchase, this.suppliers = const []});

  final GasPurchase? purchase;
  final List<Supplier> suppliers;

  @override
  State<GasPurchaseDialog> createState() => _GasPurchaseDialogState();
}

class _GasPurchaseDialogState extends State<GasPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _tankSizePreset;
  late TextEditingController _customTankSizeController;
  late double _amountPaid;
  late DateTime _purchaseDate;
  late String _supplierName;
  late String _contactNumber;
  late String _notes;

  final List<String> _tankSizes = ['5 kg', '11 kg', '22 kg', '50 kg', '2.7 kg', 'Custom'];

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    final existingSize = p?.tankSize ?? '11 kg';
    if (_tankSizes.contains(existingSize) && existingSize != 'Custom') {
      _tankSizePreset = existingSize;
      _customTankSizeController = TextEditingController();
    } else {
      _tankSizePreset = 'Custom';
      _customTankSizeController = TextEditingController(text: existingSize);
    }

    _amountPaid = p?.amountPaid ?? 0.0;
    _purchaseDate = p?.purchaseDate ?? DateTime.now();
    _supplierName = p?.supplierName ?? '';
    _contactNumber = p?.contactNumber ?? '';
    _notes = p?.notes ?? '';
  }

  @override
  void dispose() {
    _customTankSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.purchase != null;

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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isEditing ? Icons.edit_rounded : Icons.propane_tank_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit LPG Order' : 'Record LPG Order',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 730)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _purchaseDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Order / Refill Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(_purchaseDate),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tank Size Selection (User decides tank size)
              Text(
                'Select LPG Tank Size',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tankSizePreset,
                      decoration: InputDecoration(
                        labelText: 'Tank Size (User Choice)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.propane_tank_outlined),
                      ),
                      items: _tankSizes
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _tankSizePreset = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _amountPaid == 0.0 ? '' : _amountPaid.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price / Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                      validator: (val) => val == null || double.tryParse(val) == null
                          ? 'Enter price'
                          : null,
                      onSaved: (val) => _amountPaid = double.parse(val!),
                    ),
                  ),
                ],
              ),

              if (_tankSizePreset == 'Custom') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customTankSizeController,
                  decoration: InputDecoration(
                    labelText: 'Specify Custom Tank Size (e.g. 13 kg)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.tune),
                  ),
                  validator: (val) =>
                      _tankSizePreset == 'Custom' && (val == null || val.trim().isEmpty)
                          ? 'Please specify custom tank size'
                          : null,
                ),
              ],
              const SizedBox(height: 14),

              // Supplier Directory Selector & Link
              if (widget.suppliers.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: widget.suppliers.any((s) => s.name == _supplierName)
                      ? _supplierName
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Select from Supplier Directory',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.storefront),
                  ),
                  hint: const Text('Choose saved supplier from directory'),
                  items: widget.suppliers
                      .map(
                        (s) {
                          final phoneSummary = s.phoneNumbers.isNotEmpty
                              ? s.phoneNumbers.map((p) => '${p.network}: ${p.phoneNumber}').join(', ')
                              : s.contactNumber;
                          return DropdownMenuItem(
                            value: s.name,
                            child: Text(
                              phoneSummary.isNotEmpty ? '${s.name} ($phoneSummary)' : s.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final sup = widget.suppliers.firstWhere((s) => s.name == val);
                      setState(() {
                        _supplierName = sup.name;
                        _contactNumber = sup.phoneNumbers.isNotEmpty
                            ? sup.phoneNumbers.first.phoneNumber
                            : sup.contactNumber;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                key: ValueKey('supplier_name_$_supplierName'),
                initialValue: _supplierName,
                decoration: InputDecoration(
                  labelText: 'Supplier Name (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                onSaved: (val) => _supplierName = val?.trim() ?? '',
                onChanged: (val) => _supplierName = val,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('contact_number_$_contactNumber'),
                initialValue: _contactNumber,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Supplier Contact Number (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                onSaved: (val) => _contactNumber = val?.trim() ?? '',
              ),
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
                onSaved: (val) => _notes = val?.trim() ?? '',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update LPG Order' : 'Save LPG Order',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final chosenTankSize = _tankSizePreset == 'Custom'
        ? _customTankSizeController.text.trim()
        : _tankSizePreset;

    final purchase = GasPurchase(
      id: widget.purchase?.id ?? const Uuid().v4(),
      gasType: 'LPG',
      tankSize: chosenTankSize.isNotEmpty ? chosenTankSize : '11 kg',
      amountPaid: _amountPaid,
      purchaseDate: _purchaseDate,
      supplierName: _supplierName,
      contactNumber: _contactNumber,
      notes: _notes,
    );

    await HiveService.instance.saveGasPurchase(purchase);
    if (mounted) Navigator.pop(context, purchase);
  }
}
