import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utilities/formatters.dart';
import '../../models/app_models.dart';
import '../../services/gas_calculation_service.dart';
import '../../services/hive_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gas_purchase_dialog.dart';
import '../../widgets/supplier_dialog.dart';

class GasTrackerScreen extends StatefulWidget {
  const GasTrackerScreen({super.key});

  @override
  State<GasTrackerScreen> createState() => _GasTrackerScreenState();
}

class _GasTrackerScreenState extends State<GasTrackerScreen>
    with SingleTickerProviderStateMixin {
  final HiveService _hive = HiveService.instance;

  late TabController _tabController;
  List<GasPurchase> _purchases = [];
  List<Supplier> _suppliers = [];
  Timer? _dayUpdateTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGasData();
    _dayUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadGasData() async {
    await _hive.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _purchases = _hive.getGasPurchases();
      _suppliers = _hive.getSuppliers();
    });
  }

  @override
  void dispose() {
    _dayUpdateTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Order calculation: purchases sorted by purchaseDate descending (newest first)
    final today = DateTime.now();
    final latestPurchase = _purchases.where((purchase) {
      final purchaseDay = DateTime(
        purchase.purchaseDate.year,
        purchase.purchaseDate.month,
        purchase.purchaseDate.day,
      );
      final todayDay = DateTime(today.year, today.month, today.day);
      return !purchaseDay.isAfter(todayDay);
    }).firstOrNull;

    final avgDuration = GasCalculationService.calculateAverageDuration(
      _purchases,
    );
    final longestDuration = GasCalculationService.calculateLongestDuration(
      _purchases,
    );
    final shortestDuration = GasCalculationService.calculateShortestDuration(
      _purchases,
    );
    final totalSpent = GasCalculationService.calculateTotalSpent(_purchases);

    // Active tank days elapsed (inclusive of the order day)
    final activeTankDays = latestPurchase != null
        ? GasCalculationService.calculateActiveTankDays(
            latestPurchase.purchaseDate,
          )
        : 0;

    // Previous tank duration ends when the next tank is ordered.
    int? lastTankDuration;
    if (_purchases.length >= 2) {
      lastTankDuration = GasCalculationService.calculateCompletedTankDuration(
        _purchases[1].purchaseDate,
        _purchases[0].purchaseDate,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LPG Cooking Gas Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Orders & Statistics'),
            Tab(text: 'Suppliers Directory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Household LPG Orders & Duration Analytics
          RefreshIndicator(
            onRefresh: _loadGasData,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Active Tank Card
                if (latestPurchase != null) ...[
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.propane_tank_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Cooking LPG Tank',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'LPG ${latestPurchase.tankSize}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'In Use: $activeTankDays ${activeTankDays == 1 ? 'day' : 'days'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ordered on ${Formatters.formatDate(latestPurchase.purchaseDate)} • ${Formatters.formatCurrency(latestPurchase.amountPaid)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (lastTankDuration != null &&
                            lastTankDuration > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Previous tank lasted: ${GasCalculationService.formatDurationText(lastTankDuration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (latestPurchase.supplierName.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _navigateToSupplier(
                                  latestPurchase.supplierName,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                    horizontal: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Supplier: ${latestPurchase.supplierName}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (latestPurchase.contactNumber.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _callNumber(latestPurchase.contactNumber),
                                  icon: const Icon(Icons.phone, size: 16),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.red.shade700,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  CustomCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.propane_tank_outlined,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No LPG Orders Yet',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Record your first LPG order to start tracking how long your tanks last in your household.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openAddPurchaseDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add LPG Order'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Household LPG Analytics & Statistics Card Grid
                Text(
                  'Household Tank Duration Stats',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Average Duration',
                              avgDuration > 0 ? '$avgDuration days' : 'N/A',
                              'per cooking tank',
                              Colors.red,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              'Shortest Tank',
                              shortestDuration > 0
                                  ? '$shortestDuration days'
                                  : 'N/A',
                              'min lifespan',
                              Colors.orange,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              'Longest Tank',
                              longestDuration > 0
                                  ? '$longestDuration days'
                                  : 'N/A',
                              'max lifespan',
                              Colors.green,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              'Total Orders',
                              '${_purchases.length}',
                              Formatters.formatCurrency(totalSpent),
                              Colors.indigo,
                              isDark,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Average Duration',
                                avgDuration > 0 ? '$avgDuration days' : 'N/A',
                                'per cooking tank',
                                Colors.red,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                'Shortest Tank',
                                shortestDuration > 0
                                    ? '$shortestDuration days'
                                    : 'N/A',
                                'min lifespan',
                                Colors.orange,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Longest Tank',
                                longestDuration > 0
                                    ? '$longestDuration days'
                                    : 'N/A',
                                'max lifespan',
                                Colors.green,
                                isDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildStatCard(
                                'Total Orders',
                                '${_purchases.length}',
                                Formatters.formatCurrency(totalSpent),
                                Colors.indigo,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Order History Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LPG Order History',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _openAddPurchaseDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_purchases.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No historical LPG orders logged.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...List.generate(_purchases.length, (index) {
                    final p = _purchases[index];

                    // Duration for this tank if a previous order exists (i.e. index + 1)
                    int? duration;
                    if (index < _purchases.length - 1) {
                      duration =
                          p.purchaseDate
                              .difference(_purchases[index + 1].purchaseDate)
                              .inDays +
                          1;
                    }

                    final durationText = duration != null
                        ? '\nLasted: ${GasCalculationService.formatDurationText(duration)}'
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: CustomCard(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade50,
                            child: const Icon(
                              Icons.propane_tank_rounded,
                              color: Colors.red,
                            ),
                          ),
                          title: Text(
                            'LPG Tank (${p.tankSize}) — ${Formatters.formatCurrency(p.amountPaid)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                'Ordered: ${Formatters.formatDate(p.purchaseDate)}$durationText',
                              ),
                              if (p.supplierName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () =>
                                      _navigateToSupplier(p.supplierName),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 14,
                                        color: Colors.indigo,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Supplier: ${p.supplierName}',
                                        style: const TextStyle(
                                          color: Colors.indigo,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _openEditPurchaseDialog(p),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () => _deletePurchase(p),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Tab 2: Suppliers Directory with Delete Actions
          RefreshIndicator(
            onRefresh: _loadGasData,
            child: _suppliers.isEmpty
                ? EmptyState(
                    title: 'No suppliers yet',
                    message:
                        'Add a supplier to quickly access their information when needed.',
                    icon: Icons.storefront_outlined,
                    actionLabel: 'Add Supplier',
                    onAction: _openAddSupplierDialog,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _suppliers.length,
                    itemBuilder: (context, index) {
                      final s = _suppliers[index];
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final phoneList = s.phoneNumbers.isNotEmpty
                          ? s.phoneNumbers
                          : (s.contactNumber.isNotEmpty
                                ? [
                                    SupplierPhoneNumber(
                                      id: 'legacy',
                                      phoneNumber: s.contactNumber,
                                      network: 'Globe',
                                    ),
                                  ]
                                : <SupplierPhoneNumber>[]);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: CustomCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Supplier Header
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.indigo.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: const Icon(
                                        Icons.storefront,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (s.address.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on_outlined,
                                                    size: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      s.address,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      tooltip: 'Edit Supplier',
                                      onPressed: () =>
                                          _openEditSupplierDialog(s),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      tooltip: 'Delete Supplier',
                                      onPressed: () => _deleteSupplier(s),
                                    ),
                                  ],
                                ),

                                if (s.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E294B)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.notes,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            s.notes,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Phone Numbers List
                                if (phoneList.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  ...phoneList.map((p) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 3,
                                      ),
                                      child: Row(
                                        children: [
                                          // Network Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.networkColor.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: p.networkColor
                                                    .withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  p.networkIcon,
                                                  size: 11,
                                                  color: p.networkColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  p.network,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: p.networkColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              p.phoneNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                          // Copy button
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 16,
                                            ),
                                            tooltip: 'Copy Number',
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                _copyNumber(p.phoneNumber),
                                          ),
                                          const SizedBox(width: 6),
                                          // Call button
                                          IconButton.filledTonal(
                                            icon: const Icon(
                                              Icons.phone_in_talk,
                                              size: 16,
                                              color: Colors.green,
                                            ),
                                            tooltip: 'Call ${p.phoneNumber}',
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                            onPressed: () =>
                                                _callNumber(p.phoneNumber),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openAddPurchaseDialog();
          } else {
            _openAddSupplierDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'Record LPG Order' : 'Add Supplier',
        ),
      ),
    );
  }

  void _navigateToSupplier(String supplierName) {
    if (supplierName.trim().isEmpty) return;
    final match = _suppliers
        .where((s) => s.name.toLowerCase() == supplierName.toLowerCase())
        .firstOrNull;
    if (match != null) {
      _tabController.animateTo(1);
      _openEditSupplierDialog(match);
    } else {
      _tabController.animateTo(1);
    }
  }

  Future<void> _copyNumber(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Copied $phone to clipboard'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _callNumber(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Calling $phone...')));
      }
    }
  }

  Future<void> _openAddPurchaseDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GasPurchaseDialog(suppliers: _suppliers),
    );
    if (result != null) _loadGasData();
  }

  Future<void> _openEditPurchaseDialog(GasPurchase purchase) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          GasPurchaseDialog(purchase: purchase, suppliers: _suppliers),
    );
    if (result != null) _loadGasData();
  }

  Future<void> _deletePurchase(GasPurchase purchase) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete LPG Order?',
      message:
          'This action cannot be undone. Are you sure you want to permanently delete this LPG order record?',
    );
    if (confirm) {
      await NotificationService.instance.cancelNotificationForId(purchase.id);
      await _hive.deleteGasPurchase(purchase.id);
      await _loadGasData();
    }
  }

  Future<void> _openAddSupplierDialog() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupplierDialog(),
    );
    if (result != null) _loadGasData();
  }

  Future<void> _openEditSupplierDialog(Supplier supplier) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierDialog(supplier: supplier),
    );
    if (result != null) _loadGasData();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Supplier?',
      message:
          'This action cannot be undone. Are you sure you want to permanently delete this supplier?',
    );
    if (confirm) {
      await _hive.deleteSupplier(supplier.id);
      await _loadGasData();
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color valueColor,
    bool isDark,
  ) {
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
