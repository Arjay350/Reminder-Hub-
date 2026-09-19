import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/password_text_field.dart';
import '../../widgets/user_account_dialog.dart';

class AccountManagerScreen extends StatefulWidget {
  const AccountManagerScreen({super.key});

  @override
  State<AccountManagerScreen> createState() => _AccountManagerScreenState();
}

class _AccountManagerScreenState extends State<AccountManagerScreen> {
  final HiveService _hive = HiveService.instance;

  List<UserAccount> _accounts = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Websites',
    'Apps',
    'Gaming',
    'Finance',
    'Email',
    'Work',
    'School',
    'Shopping',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _accounts = _hive.getUserAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _accounts.where((a) {
      if (_selectedCategory != 'All' && a.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchService = a.serviceName.toLowerCase().contains(q);
        final matchUser = a.username.toLowerCase().contains(q);
        final matchEmail = a.email.toLowerCase().contains(q);
        final matchCategory = a.category.toLowerCase().contains(q);
        if (!matchService && !matchUser && !matchEmail && !matchCategory) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Security Banner Notice - stylized
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '100% Offline Vault',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Encrypted local storage • No internet required',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search service, username, email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF141A2E)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: Colors.orange.withValues(alpha: 0.15),
                    checkmarkColor: Colors.orange,
                    labelStyle: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.orange.shade700
                          : (isDark ? Colors.grey.shade300 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Account Cards List
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: 'No Saved Credentials',
                    message:
                        'Store offline usernames, passwords, recovery emails & logins safely',
                    icon: Icons.lock_person_outlined,
                    actionLabel: 'Add Login Account',
                    onAction: _openAddDialog,
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 350),
                          child: SlideAnimation(
                            verticalOffset: 40.0,
                            child: FadeInAnimation(
                              child: Dismissible(
                                key: Key(account.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  return await showConfirmDeleteDialog(
                                    context,
                                    title: 'Delete Account?',
                                    message:
                                        'This action cannot be undone. Are you sure you want to permanently delete this saved account?',
                                  );
                                },
                                onDismissed: (_) async {
                                  await _hive.deleteUserAccount(account.id);
                                  _loadAccounts();
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 14),
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
                                  margin: const EdgeInsets.only(bottom: 14),
                                  child: CustomCard(
                                    onTap: () => _showAccountDetails(account),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(
                                                  alpha: 0.12,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                account.categoryIcon,
                                                color: Colors.orange.shade700,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    account.serviceName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 17,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${account.accountName} • ${account.email.isNotEmpty ? account.email : account.username}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? Colors.grey.shade400
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 20,
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade700,
                                              ),
                                              onPressed: () =>
                                                  _openEditDialog(account),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _deleteAccount(account),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        PasswordTextField(
                                          password: account.password,
                                          label: 'Password credential',
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            if (account
                                                .username
                                                .isNotEmpty) ...[
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Username',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: account.username,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Username copied',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (account.email.isNotEmpty) ...[
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 14,
                                                ),
                                                label: const Text(
                                                  'Email',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Clipboard.setData(
                                                    ClipboardData(
                                                      text: account.email,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Email copied',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            if (account.website.isNotEmpty)
                                              IconButton.filledTonal(
                                                icon: const Icon(
                                                  Icons.open_in_new_rounded,
                                                  size: 16,
                                                ),
                                                tooltip: 'Open Website',
                                                onPressed: () =>
                                                    _launchURL(account.website),
                                              ),
                                          ],
                                        ),
                                      ],
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
        label: const Text('Add Account'),
      ),
    );
  }

  void _showAccountDetails(UserAccount account) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.12),
                  child: Icon(
                    account.categoryIcon,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.serviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'Category: ${account.category}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow('Account Label', account.accountName, isDark),
            if (account.category == 'Finance' &&
                account.accountNumber.isNotEmpty)
              _detailRow('Account Number', account.accountNumber, isDark),
            if (account.username.isNotEmpty)
              _detailRow('Username', account.username, isDark),
            if (account.email.isNotEmpty)
              _detailRow('Email', account.email, isDark),
            const SizedBox(height: 8),
            PasswordTextField(password: account.password, label: 'Password'),
            if (account.website.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailRow('Website URL', account.website, isDark),
            ],
            if (account.recoveryEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailRow('Recovery Email', account.recoveryEmail, isDark),
            ],
            if (account.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailRow('Notes', account.notes, isDark),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openEditDialog(account);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteAccount(account);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlStr) async {
    try {
      final uri = Uri.parse(
        urlStr.startsWith('http') ? urlStr : 'https://$urlStr',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openAddDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserAccountDialog(),
    );
    if (result != null) _loadAccounts();
  }

  Future<void> _openEditDialog(UserAccount account) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserAccountDialog(account: account),
    );
    if (result != null) _loadAccounts();
  }

  Future<void> _deleteAccount(UserAccount account) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Account?',
      message:
          'This action cannot be undone. Are you sure you want to permanently delete this saved account?',
    );
    if (confirm) {
      await _hive.deleteUserAccount(account.id);
      _loadAccounts();
    }
  }
}
