import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/ai_account_dialog.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/password_text_field.dart';

class AIAccountsScreen extends StatefulWidget {
  const AIAccountsScreen({
    super.key,
    this.initialService,
    this.activeOnly = false,
    this.isScreenActive = true,
  });

  final String? initialService;
  final bool activeOnly;
  final bool isScreenActive;

  @override
  State<AIAccountsScreen> createState() => _AIAccountsScreenState();
}

class _AIAccountsScreenState extends State<AIAccountsScreen> {
  final HiveService _hive = HiveService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<AIAccount> _accounts = [];
  late String _selectedServiceFilter = widget.initialService ?? 'All';
  late String _selectedStatusFilter = widget.activeOnly ? 'Active' : 'All';
  String _searchQuery = '';
  Timer? _statusRefreshTimer;

  final List<String> _services = [
    'All',
    'ChatGPT',
    'Claude',
    'Gemini',
    'Grok',
    'Cursor',
    'GitHub Copilot',
    'Perplexity',
    'DeepSeek',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAccounts(),
    );
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _accounts = _hive.getAIAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allCount = _accounts.length;
    final activeCount =
        _accounts.where((a) => a.currentResetStatus == 'Active').length;
    final cooldownCount =
        _accounts.where((a) => a.currentResetStatus == 'Cooldown').length;

    final filtered = _accounts.where((a) {
      if (_selectedServiceFilter != 'All' &&
          a.service != _selectedServiceFilter) {
        return false;
      }
      if (_selectedStatusFilter != 'All' &&
          a.currentResetStatus != _selectedStatusFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchService = a.service.toLowerCase().contains(q);
        final matchAccount = a.accountName.toLowerCase().contains(q);
        final matchEmail = a.email.toLowerCase().contains(q);
        final matchUsername = a.username.toLowerCase().contains(q);
        final matchPlan = a.plan.toLowerCase().contains(q);
        final matchNotes = a.notes.toLowerCase().contains(q);
        final matchStatus = a.currentResetStatus.toLowerCase().contains(q);
        if (!matchService &&
            !matchAccount &&
            !matchEmail &&
            !matchUsername &&
            !matchPlan &&
            !matchNotes &&
            !matchStatus) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedStatusFilter == 'Active'
              ? _selectedServiceFilter == 'All'
                  ? 'Active AI Resets'
                  : '${_providerLabel(_selectedServiceFilter)} — Active Resets'
              : _selectedStatusFilter == 'Cooldown'
                  ? _selectedServiceFilter == 'All'
                      ? 'Cooldown AI Accounts'
                      : '${_providerLabel(_selectedServiceFilter)} — Cooldown'
                  : _selectedServiceFilter == 'All'
                      ? 'AI Accounts'
                      : '${_providerLabel(_selectedServiceFilter)} Accounts',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search AI accounts, email, service...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
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

          // Service filter chips at the top
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final s = _services[index];
                final isSelected = _selectedServiceFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedServiceFilter = s),
                    selectedColor: const Color(
                      0xFF8B5CF6,
                    ).withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF8B5CF6),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : (isDark ? Colors.grey.shade300 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Status filter chips (All, Active, Cooldown) inside below service categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statusFilterChip('All', 'All', allCount, isDark),
                const SizedBox(width: 8),
                _statusFilterChip(
                  'Active',
                  'Active',
                  activeCount,
                  isDark,
                  color: const Color(0xFF31A24C),
                ),
                const SizedBox(width: 8),
                _statusFilterChip(
                  'Cooldown',
                  'Cooldown',
                  cooldownCount,
                  isDark,
                  color: Colors.amber.shade700,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: _searchQuery.isNotEmpty
                        ? 'No Matches Found'
                        : _selectedStatusFilter == 'Active'
                            ? _selectedServiceFilter == 'All'
                                ? 'No Active Resets'
                                : 'No Active ${_providerLabel(_selectedServiceFilter)} Resets'
                            : _selectedStatusFilter == 'Cooldown'
                                ? _selectedServiceFilter == 'All'
                                    ? 'No Accounts in Cooldown'
                                    : 'No ${_providerLabel(_selectedServiceFilter)} in Cooldown'
                                : 'No AI Accounts Saved',
                    message: _searchQuery.isNotEmpty
                        ? 'No AI accounts matching "$_searchQuery"'
                        : _selectedStatusFilter == 'Active'
                            ? 'There are no active resets for this selection right now.'
                            : _selectedStatusFilter == 'Cooldown'
                                ? 'No AI accounts are currently waiting for their reset time.'
                                : 'Keep track of ChatGPT, Claude, Gemini reset schedules & passwords',
                    icon: _searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : _selectedStatusFilter == 'Active'
                            ? Icons.check_circle_outline
                            : _selectedStatusFilter == 'Cooldown'
                                ? Icons.schedule
                                : Icons.smart_toy_outlined,
                    actionLabel: 'Add AI Account',
                    onAction: _openAddDialog,
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final account = filtered[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Dismissible(
                                key: Key(account.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  return await showConfirmDeleteDialog(
                                    context,
                                    title: 'Delete AI Account?',
                                    message:
                                        'This action cannot be undone. Are you sure you want to permanently delete this AI account?',
                                  );
                                },
                                onDismissed: (_) async {
                                  await NotificationService.instance
                                      .cancelNotificationForId(account.id);
                                  await _hive.deleteAIAccount(account.id);
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: account.serviceColor
                                                    .withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _serviceIcon(account.service),
                                                color: account.serviceColor,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment.center,
                                                    children: [
                                                      Text(
                                                        account.service,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: account
                                                              .serviceColor,
                                                        ),
                                                      ),
                                                      Container(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 160,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: account
                                                              .serviceColor
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          account.accountName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: account
                                                                .serviceColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    account.email,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                            PopupMenuButton<String>(
                                              tooltip: 'Account actions',
                                              onSelected: (action) {
                                                if (action == 'edit') {
                                                  _openEditDialog(account);
                                                } else {
                                                  _deleteAccount(account);
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_outlined),
                                                      SizedBox(width: 12),
                                                      Text('Edit account'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 12),
                                                      Text('Delete account'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final columns =
                                                constraints.maxWidth >= 680
                                                ? 3
                                                : constraints.maxWidth >= 380
                                                ? 2
                                                : 1;
                                            final gap = 8.0;
                                            final width =
                                                (constraints.maxWidth -
                                                    gap * (columns - 1)) /
                                                columns;
                                            return Wrap(
                                              spacing: gap,
                                              runSpacing: gap,
                                              children: [
                                                SizedBox(
                                                  width: width,
                                                  child: _infoBadge(
                                                    Icons.workspace_premium,
                                                    'Plan: ${account.plan}',
                                                    isDark,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: width,
                                                  child: _infoBadge(
                                                    Icons.alarm,
                                                    _formatResetBadge(account),
                                                    isDark,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: width,
                                                  child: _resetStatusBadge(
                                                    account.currentResetStatus,
                                                    isDark,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                        if (account.password.trim().isNotEmpty)
                                          PasswordTextField(
                                            password: account.password,
                                            label: 'Password Credential',
                                            authenticateOnReveal: true,
                                            authenticateOnCopy: true,
                                            hideOnBackground: true,
                                            isScreenActive: widget.isScreenActive,
                                          ),
                                        if (account.password.trim().isEmpty)
                                          const Text('No password saved'),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                account.isFreePlan
                                                    ? 'Free Plan • No renewal needed'
                                                    : 'Renewal: ${Formatters.formatDate(account.renewalDate)}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: account.isFreePlan
                                                      ? Colors.green.shade600
                                                      : Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.copy_rounded,
                                                size: 18,
                                              ),
                                              tooltip: 'Copy Email',
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
                                                      'Email copied to clipboard',
                                                    ),
                                                  ),
                                                );
                                              },
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
        label: const Text('Add AI Account'),
      ),
    );
  }

  Widget _statusFilterChip(
    String value,
    String label,
    int count,
    bool isDark, {
    Color? color,
  }) {
    final isSelected = _selectedStatusFilter == value;
    final primaryColor = color ?? const Color(0xFF8B5CF6);
    return Expanded(
      child: FilterChip(
        label: Center(
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.grey.shade300 : Colors.black87),
            ),
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedStatusFilter = value),
        selectedColor: primaryColor.withValues(alpha: 0.15),
        checkmarkColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E294B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetStatusBadge(String status, bool isDark) {
    final isActive = status == 'Active';
    final color = isActive
        ? const Color(0xFF31A24C)
        : (isDark ? Colors.amber.shade200 : Colors.amber.shade900);
    final background = isActive
        ? const Color(0xFF31A24C).withValues(alpha: isDark ? 0.2 : 0.12)
        : Colors.amber.withValues(alpha: isDark ? 0.16 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.schedule,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatResetBadge(AIAccount account) {
    final sched = account.resetSchedule.trim().toLowerCase();
    if (sched == 'daily') {
      return 'Reset: Daily at ${account.resetTime}';
    } else if (sched == 'weekly') {
      final dayName = DateFormat('EEE').format(account.resetDate);
      return 'Reset: Every $dayName at ${account.resetTime}';
    } else if (sched == 'monthly') {
      return 'Reset: Monthly (Day ${account.resetDate.day}) at ${account.resetTime}';
    } else {
      return 'Reset: ${Formatters.formatShortDate(account.resetDate)} at ${account.resetTime}';
    }
  }

  String _providerLabel(String provider) =>
      provider == 'GitHub Copilot' ? 'Copilot' : provider;

  IconData _serviceIcon(String service) {
    switch (service) {
      case 'ChatGPT':
        return Icons.chat_bubble_outline;
      case 'Claude':
        return Icons.auto_awesome;
      case 'Gemini':
        return Icons.stars;
      case 'Grok':
        return Icons.bolt;
      case 'Cursor':
        return Icons.code;
      case 'GitHub Copilot':
        return Icons.terminal;
      default:
        return Icons.smart_toy;
    }
  }

  Future<void> _openAddDialog() async {
    final defaultService =
        _selectedServiceFilter != 'All' ? _selectedServiceFilter : null;
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AIAccountDialog(initialService: defaultService),
    );
    if (result != null) _loadAccounts();
  }

  Future<void> _openEditDialog(AIAccount account) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AIAccountDialog(account: account),
    );
    if (result != null) _loadAccounts();
  }

  Future<void> _deleteAccount(AIAccount account) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete AI Account?',
      message:
          'This action cannot be undone. Are you sure you want to permanently delete this AI account?',
    );
    if (confirm) {
      await NotificationService.instance.cancelNotificationForId(account.id);
      await _hive.deleteAIAccount(account.id);
      _loadAccounts();
    }
  }
}
