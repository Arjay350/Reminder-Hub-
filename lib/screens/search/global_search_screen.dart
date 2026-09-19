import 'package:flutter/material.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final HiveService _hive = HiveService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Reminder> _reminders = [];
  List<Bill> _bills = [];
  List<AIAccount> _aiAccounts = [];
  List<UserAccount> _userAccounts = [];
  List<GasPurchase> _gasPurchases = [];

  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _reminders = _hive.getReminders();
      _bills = _hive.getBills();
      _aiAccounts = _hive.getAIAccounts();
      _userAccounts = _hive.getUserAccounts();
      _gasPurchases = _hive.getGasPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();

    final matchedReminders = q.isEmpty
        ? <Reminder>[]
        : _reminders
              .where(
                (r) =>
                    r.title.toLowerCase().contains(q) ||
                    r.category.toLowerCase().contains(q) ||
                    r.description.toLowerCase().contains(q),
              )
              .toList();

    final matchedBills = q.isEmpty
        ? <Bill>[]
        : _bills
              .where(
                (b) =>
                    b.name.toLowerCase().contains(q) ||
                    b.category.toLowerCase().contains(q),
              )
              .toList();

    final matchedAIAccounts = q.isEmpty
        ? <AIAccount>[]
        : _aiAccounts
              .where(
                (a) =>
                    a.service.toLowerCase().contains(q) ||
                    a.accountName.toLowerCase().contains(q) ||
                    a.email.toLowerCase().contains(q) ||
                    a.username.toLowerCase().contains(q),
              )
              .toList();

    final matchedUserAccounts = q.isEmpty
        ? <UserAccount>[]
        : _userAccounts
              .where(
                (u) =>
                    u.serviceName.toLowerCase().contains(q) ||
                    u.accountName.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q) ||
                    u.username.toLowerCase().contains(q) ||
                    u.category.toLowerCase().contains(q),
              )
              .toList();

    final matchedGas = q.isEmpty
        ? <GasPurchase>[]
        : _gasPurchases
              .where(
                (g) =>
                    g.gasType.toLowerCase().contains(q) ||
                    g.supplierName.toLowerCase().contains(q),
              )
              .toList();

    final totalMatches =
        matchedReminders.length +
        matchedBills.length +
        matchedAIAccounts.length +
        matchedUserAccounts.length +
        matchedGas.length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search all reminders, bills, accounts, gas...',
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _query = val),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'Type to search across Reminder Hub',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : totalMatches == 0
          ? Center(
              child: Text(
                'No matching items found for "$_query"',
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (matchedReminders.isNotEmpty) ...[
                  _sectionHeader('Reminders (${matchedReminders.length})'),
                  ...matchedReminders.map(
                    (r) => ListTile(
                      leading: Icon(r.categoryIcon, color: r.categoryColor),
                      title: Text(r.title),
                      subtitle: Text(
                        '${r.category} • ${Formatters.formatShortDate(r.date)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (matchedBills.isNotEmpty) ...[
                  _sectionHeader('Bills (${matchedBills.length})'),
                  ...matchedBills.map(
                    (b) => ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: Colors.green,
                      ),
                      title: Text(b.name),
                      subtitle: Text(Formatters.formatCurrency(b.amount)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (matchedAIAccounts.isNotEmpty) ...[
                  _sectionHeader('AI Accounts (${matchedAIAccounts.length})'),
                  ...matchedAIAccounts.map(
                    (a) => ListTile(
                      leading: const Icon(
                        Icons.smart_toy,
                        color: Colors.purple,
                      ),
                      title: Text('${a.service} - ${a.accountName}'),
                      subtitle: Text(a.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (matchedUserAccounts.isNotEmpty) ...[
                  _sectionHeader(
                    'Saved Logins (${matchedUserAccounts.length})',
                  ),
                  ...matchedUserAccounts.map(
                    (u) => ListTile(
                      leading: Icon(u.categoryIcon, color: Colors.orange),
                      title: Text(u.serviceName),
                      subtitle: Text(u.email.isNotEmpty ? u.email : u.username),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (matchedGas.isNotEmpty) ...[
                  _sectionHeader('Gas Purchases (${matchedGas.length})'),
                  ...matchedGas.map(
                    (g) => ListTile(
                      leading: const Icon(
                        Icons.local_gas_station,
                        color: Colors.red,
                      ),
                      title: Text('${g.gasType} (${g.tankSize})'),
                      subtitle: Text('Supplier: ${g.supplierName}'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
