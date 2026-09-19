import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';
import 'confirm_delete_dialog.dart';

class SupplierDialog extends StatefulWidget {
  const SupplierDialog({super.key, this.supplier});

  final Supplier? supplier;

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _PhoneEntry {
  _PhoneEntry({
    required this.id,
    required this.controller,
    required this.network,
  });

  final String id;
  final TextEditingController controller;
  String network;
}

class _SupplierDialogState extends State<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late String _address;
  late String _notes;
  final List<_PhoneEntry> _phoneEntries = [];

  static const List<String> _networks = [
    'Globe',
    'Smart',
    'DITO',
    'TM',
    'TNT',
    'Sun',
    'Landline',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = s?.name ?? '';
    _address = s?.address ?? '';
    _notes = s?.notes ?? '';

    if (s != null && s.phoneNumbers.isNotEmpty) {
      for (final p in s.phoneNumbers) {
        _phoneEntries.add(_PhoneEntry(
          id: p.id.isNotEmpty ? p.id : const Uuid().v4(),
          controller: TextEditingController(text: p.phoneNumber),
          network: _networks.contains(p.network) ? p.network : 'Globe',
        ));
      }
    } else if (s != null && s.contactNumber.isNotEmpty) {
      _phoneEntries.add(_PhoneEntry(
        id: const Uuid().v4(),
        controller: TextEditingController(text: s.contactNumber),
        network: 'Globe',
      ));
    } else {
      _phoneEntries.add(_PhoneEntry(
        id: const Uuid().v4(),
        controller: TextEditingController(),
        network: 'Globe',
      ));
    }
  }

  @override
  void dispose() {
    for (final entry in _phoneEntries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  void _addPhoneNumber() {
    setState(() {
      _phoneEntries.add(_PhoneEntry(
        id: const Uuid().v4(),
        controller: TextEditingController(),
        network: 'Smart',
      ));
    });
  }

  void _removePhoneNumber(int index) {
    if (_phoneEntries.length > 1) {
      setState(() {
        final removed = _phoneEntries.removeAt(index);
        removed.controller.dispose();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one phone number field is required.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        isEditing ? Icons.edit_rounded : Icons.storefront_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? 'Edit Supplier' : 'Add Supplier',
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
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: 'Supplier Name *',
                  hintText: 'e.g. ABC LPG Center',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.storefront),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter supplier name' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 18),

              // Phone Numbers Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact Phone Numbers',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPhoneNumber,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Number', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              ...List.generate(_phoneEntries.length, (index) {
                final entry = _phoneEntries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Network Selector
                      Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 8),
                        child: DropdownButtonFormField<String>(
                          initialValue: entry.network,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: _networks
                              .map((net) => DropdownMenuItem(
                                    value: net,
                                    child: Text(net, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => entry.network = val);
                            }
                          },
                        ),
                      ),

                      // Phone Number Input
                      Expanded(
                        child: TextFormField(
                          controller: entry.controller,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Number ${index + 1}',
                            hintText: '0917-XXX-XXXX',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            prefixIcon: const Icon(Icons.phone, size: 18),
                          ),
                          validator: (val) {
                            if (index == 0 && (val == null || val.trim().isEmpty)) {
                              return 'Enter at least 1 phone number';
                            }
                            return null;
                          },
                        ),
                      ),

                      // Remove button
                      if (_phoneEntries.length > 1) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Remove number',
                          onPressed: () => _removePhoneNumber(index),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              TextFormField(
                initialValue: _address,
                decoration: InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'e.g. 123 Main St, Barangay Centro',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                onSaved: (val) => _address = val?.trim() ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _notes,
                decoration: InputDecoration(
                  labelText: 'Notes / Delivery Details (optional)',
                  hintText: 'e.g. Delivers free, open 7 AM - 7 PM',
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEditing ? 'Update Supplier' : 'Save Supplier',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Supplier'),
                    onPressed: _delete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final phoneNumbers = <SupplierPhoneNumber>[];
    for (final entry in _phoneEntries) {
      final phone = entry.controller.text.trim();
      if (phone.isNotEmpty) {
        phoneNumbers.add(SupplierPhoneNumber(
          id: entry.id,
          phoneNumber: phone,
          network: entry.network,
        ));
      }
    }

    if (phoneNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one phone number for the supplier.')),
      );
      return;
    }

    final supplier = Supplier(
      id: widget.supplier?.id ?? const Uuid().v4(),
      name: _name,
      phoneNumbers: phoneNumbers,
      contactNumber: phoneNumbers.first.phoneNumber,
      address: _address,
      notes: _notes,
    );

    await HiveService.instance.saveSupplier(supplier);
    if (mounted) Navigator.pop(context, supplier);
  }

  Future<void> _delete() async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Supplier?',
      message: 'This action cannot be undone. Are you sure you want to permanently delete this supplier?',
    );
    if (confirm && widget.supplier != null) {
      await HiveService.instance.deleteSupplier(widget.supplier!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }
}
