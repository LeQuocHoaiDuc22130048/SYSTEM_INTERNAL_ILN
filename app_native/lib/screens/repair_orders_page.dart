import '../widgets/permission_gate.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/repair_device.dart';
import '../models/repair_order.dart';
import '../models/user.dart';
import '../models/app_permission.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import 'customer_picker_sheet.dart';
import '../utils/media_auth_headers.dart';
import '../widgets/status_badge.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/modal_top_bar.dart';

Future<void> showRepairOrderDetails(
  BuildContext context,
  String orderId,
) async {
  if (!context.read<AuthProvider>().can(AppPermission.viewRepairOrders)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bạn không có quyền xem đơn sửa chữa.')),
    );
    return;
  }
  try {
    final data = await context.read<BackendDataProvider>().api.get(
      '/api/v1/repair-orders/$orderId',
    );
    final order = RepairOrder.fromJson(data as Map<String, dynamic>);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(order: order),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể mở đơn sửa chữa. Đơn có thể đã bị xóa hoặc bạn không có quyền truy cập.',
          ),
        ),
      );
    }
  }
}

Future<void> _callCustomerPhone(BuildContext context, String? rawPhone) async {
  final cleaned = (rawPhone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  try {
    await launchUrl(uri);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở ứng dụng gọi điện tới $cleaned')),
      );
    }
  }
}

Future<void> showCreateRepairOrderSheet(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (!auth.can(AppPermission.viewRepairOrders) ||
      !auth.can(AppPermission.createRepairOrders)) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateOrderSheet(),
  );
}

class RepairOrdersPage extends StatefulWidget {
  final String? targetOrderId;
  const RepairOrdersPage({super.key, this.targetOrderId});

  @override
  State<RepairOrdersPage> createState() => _RepairOrdersPageState();
}

class _RepairOrdersPageState extends State<RepairOrdersPage> {
  final ValueNotifier<RepairOrderStatus?> _filter = ValueNotifier(null);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  final ValueNotifier<DateTimeRange?> _dateFilter = ValueNotifier(null);
  final ValueNotifier<bool?> _warrantyFilter = ValueNotifier(null);
  final ValueNotifier<int> _visibleCount = ValueNotifier(20);
  final ScrollController _scrollController = ScrollController();
  bool _fillingPage = false;
  int _fillGeneration = 0;

  void _resetPage() {
    _visibleCount.value = 20;
    _fillVisibleOrders();
  }

  Future<void> _fillVisibleOrders() async {
    if (_fillingPage || !mounted) return;
    final backend = context.read<BackendDataProvider>();
    final generation = _fillGeneration;
    _fillingPage = true;
    try {
      while (mounted &&
          generation == _fillGeneration &&
          _filteredOrders.length < _visibleCount.value &&
          backend.hasMoreRepairOrders &&
          !backend.isLoading &&
          !backend.isLoadingMoreRepairOrders) {
        await backend.loadMoreRepairOrders();
        if (backend.repairOrdersPageError != null) break;
      }
    } finally {
      if (generation == _fillGeneration) _fillingPage = false;
    }
  }

  Future<void> _refreshOrders() async {
    _fillGeneration++;
    _fillingPage = false;
    _visibleCount.value = 20;
    await context.read<BackendDataProvider>().loadRepairOrders(pageSize: 20);
    if (mounted) await _fillVisibleOrders();
  }

  Future<void> _loadNextPage() async {
    final backend = context.read<BackendDataProvider>();
    if (_fillingPage || backend.isLoadingMoreRepairOrders) return;
    _visibleCount.value += 20;
    await _fillVisibleOrders();
  }

  Future<void> _retryPage() async {
    await context.read<BackendDataProvider>().loadMoreRepairOrders();
    if (mounted) await _fillVisibleOrders();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final backend = context.read<BackendDataProvider>();
        if (backend.repairOrdersPageError == null &&
            (_visibleCount.value < _filteredOrders.length ||
                backend.hasMoreRepairOrders)) {
          _loadNextPage();
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _filter.addListener(_resetPage);
    _searchQuery.addListener(_resetPage);
    _dateFilter.addListener(_resetPage);
    _warrantyFilter.addListener(_resetPage);

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshOrders();
      if (!mounted) return;
      if (widget.targetOrderId != null) {
        _showOrderById(widget.targetOrderId!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RepairOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != null &&
        widget.targetOrderId != oldWidget.targetOrderId) {
      _showOrderById(widget.targetOrderId!);
    }
  }

  void _showOrderById(String id) {
    final orders = context.read<BackendDataProvider>().repairOrders;
    final matchIndex = orders.indexWhere((o) => o.id == id);
    if (matchIndex != -1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _OrderDetailSheet(order: orders[matchIndex]),
      );
    } else {
      showRepairOrderDetails(context, id);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _filter.removeListener(_resetPage);
    _searchQuery.removeListener(_resetPage);
    _dateFilter.removeListener(_resetPage);
    _warrantyFilter.removeListener(_resetPage);

    _searchQuery.dispose();
    _filter.dispose();
    _dateFilter.dispose();
    _warrantyFilter.dispose();
    _visibleCount.dispose();
    super.dispose();
  }

  void _showDatePickerDialog(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final presets = [
      ('Hôm nay', DateTimeRange(start: today, end: today)),
      ('Hôm qua', DateTimeRange(start: yesterday, end: yesterday)),
      (
        '7 ngày qua',
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: today,
        ),
      ),
      (
        'Tháng này',
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        ),
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        void select(DateTimeRange? range) {
          _dateFilter.value = range;
          Navigator.pop(sheetContext);
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lọc theo ngày nhận đơn',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => select(null),
                        child: const Text('Tất cả'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in presets)
                        ActionChip(
                          label: Text(preset.$1),
                          onPressed: () => select(preset.$2),
                        ),
                    ],
                  ),
                  Localizations.override(
                    context: sheetContext,
                    locale: const Locale('vi', 'VN'),
                    delegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    child: CalendarDatePicker(
                      initialDate: _dateFilter.value?.start ?? today,
                      firstDate: DateTime(2020),
                      lastDate: today.add(const Duration(days: 365)),
                      onDateChanged: (date) =>
                          select(DateTimeRange(start: date, end: date)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateOrderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateOrderSheet(),
    );
  }

  List<RepairOrder> get _filteredOrders {
    final backend = context.read<BackendDataProvider>();
    final currentFilter = _filter.value;
    final selectedDate = _dateFilter.value;
    final warrantyVal = _warrantyFilter.value;
    final query = _searchQuery.value.trim().toLowerCase();

    return backend.repairOrders.where((order) {
      final matchesFilter =
          currentFilter == null || order.status == currentFilter;
      final matchesSearch =
          query.isEmpty ||
          order.orderNumber.toLowerCase().contains(query) ||
          order.deviceName.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          (order.customerPhone ?? '').contains(query) ||
          (order.serialNumber?.toLowerCase().contains(query) ?? false) ||
          order.devices.any(
            (d) => (d.serialNumber?.toLowerCase().contains(query) ?? false),
          );

      final receivedDate = DateUtils.dateOnly(order.createdAt);
      final matchesDate =
          selectedDate == null ||
          (!receivedDate.isBefore(selectedDate.start) &&
              !receivedDate.isAfter(selectedDate.end));

      final matchesWarranty =
          warrantyVal == null || order.underWarranty == warrantyVal;

      return matchesFilter && matchesSearch && matchesDate && matchesWarranty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    if (!backend.isLoading &&
        !backend.isLoadingMoreRepairOrders &&
        backend.repairOrdersPageError == null &&
        backend.hasMoreRepairOrders &&
        _filteredOrders.length < _visibleCount.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fillVisibleOrders();
      });
    }

    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.width >= 760;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 20 : 22,
                wide ? 22 : 16,
                wide ? 20 : 22,
                12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đơn sửa chữa',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${backend.repairOrdersTotal} đơn tổng cộng',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (screenSize.width > 900)
                            PermissionGate(
                              permission: AppPermission.createRepairOrders,
                              child: ElevatedButton.icon(
                                onPressed: () => _showCreateOrderSheet(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tạo đơn'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => _searchQuery.value = value,
                              decoration: InputDecoration(
                                hintText:
                                    'Tìm mã đơn, số seri, thiết bị, khách...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ValueListenableBuilder<DateTimeRange?>(
                            valueListenable: _dateFilter,
                            builder: (context, selectedDate, _) {
                              final hasDate = selectedDate != null;
                              return Material(
                                color: hasDate
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : (isDark
                                          ? AppColors.surfaceDark
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  key: const ValueKey(
                                    'repair-order-date-filter-button',
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showDatePickerDialog(context),
                                  child: Container(
                                    height: 46,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: hasDate ? 10 : 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: hasDate
                                            ? AppColors.primary
                                            : (isDark
                                                  ? AppColors.borderDark
                                                  : AppColors.borderLight),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasDate
                                              ? Icons.event_available_outlined
                                              : Icons.calendar_today_outlined,
                                          size: 18,
                                          color: hasDate
                                              ? AppColors.primary
                                              : (isDark
                                                    ? AppColors
                                                          .textSecondaryDark
                                                    : AppColors
                                                          .textSecondaryLight),
                                        ),
                                        if (hasDate) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            selectedDate.start ==
                                                    selectedDate.end
                                                ? DateFormat(
                                                    'dd/MM/yyyy',
                                                  ).format(selectedDate.start)
                                                : '${DateFormat('dd/MM').format(selectedDate.start)}–${DateFormat('dd/MM').format(selectedDate.end)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            key: const ValueKey(
                                              'repair-order-date-clear-button',
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _dateFilter.value = null;
                                              });
                                            },
                                            child: const Icon(
                                              Icons.cancel,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        key: const ValueKey('repair-orders-filter-scroll'),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterChip('Tất cả', null),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildWarrantyFilterChip('Bảo hành', true),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildWarrantyFilterChip(
                                'Không BH',
                                false,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 20,
                              margin: const EdgeInsets.only(right: 8),
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                            ...[
                              _buildFilterChip(
                                'Chưa kiểm tra',
                                RepairOrderStatus.pending,
                              ),
                              _buildFilterChip(
                                'Chờ kiểm tra',
                                RepairOrderStatus.waitingForCheck,
                              ),
                              _buildFilterChip(
                                'Đang kiểm tra',
                                RepairOrderStatus.checking,
                              ),
                              _buildFilterChip(
                                'Đã kiểm tra',
                                RepairOrderStatus.checked,
                              ),
                              _buildFilterChip(
                                'Đang sửa',
                                RepairOrderStatus.inProgress,
                              ),
                              _buildFilterChip(
                                'Hoàn thành',
                                RepairOrderStatus.completed,
                              ),
                              _buildFilterChip(
                                'Đã giao',
                                RepairOrderStatus.delivered,
                              ),
                              _buildFilterChip(
                                'Đã trả',
                                RepairOrderStatus.cancelled,
                              ),
                            ].map(
                              (child) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: backend.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : backend.error != null
                  ? _ErrorState(
                      message: backend.error!,
                      onRetry: _refreshOrders,
                      isDark: isDark,
                    )
                  : AnimatedBuilder(
                      animation: Listenable.merge([
                        _searchQuery,
                        _filter,
                        _dateFilter,
                        _warrantyFilter,
                        _visibleCount,
                      ]),
                      builder: (context, _) {
                        final filtered = _filteredOrders;
                        final totalItems = filtered.length;
                        final currentVisible = _visibleCount.value.clamp(
                          0,
                          totalItems,
                        );

                        final pageItems = filtered.sublist(
                          0,
                          currentVisible > totalItems
                              ? totalItems
                              : currentVisible,
                        );

                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _refreshOrders,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: (screenSize.height - 200).clamp(
                                    150.0,
                                    600.0,
                                  ),
                                  child: _EmptyOrders(isDark: isDark),
                                ),
                                _buildInfiniteScrollFooter(0, 0, isDark, wide),
                              ],
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: _refreshOrders,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              wide ? 20 : 22,
                              4,
                              wide ? 20 : 22,
                              24,
                            ),
                            itemCount: pageItems.length + 1,
                            itemBuilder: (context, index) {
                              if (index == pageItems.length) {
                                return _buildInfiniteScrollFooter(
                                  pageItems.length,
                                  totalItems,
                                  isDark,
                                  wide,
                                );
                              }
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 980,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _OrderCard(
                                      order: pageItems[index],
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarrantyFilterChip(String label, bool? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final orders = backend.repairOrders;

    return ValueListenableBuilder<RepairOrderStatus?>(
      valueListenable: _filter,
      builder: (context, currentStatusFilter, _) {
        final count = value == null
            ? orders
                  .where(
                    (order) =>
                        currentStatusFilter == null ||
                        order.status == currentStatusFilter,
                  )
                  .length
            : orders
                  .where(
                    (order) =>
                        order.underWarranty == value &&
                        (currentStatusFilter == null ||
                            order.status == currentStatusFilter),
                  )
                  .length;

        return ValueListenableBuilder<bool?>(
          valueListenable: _warrantyFilter,
          builder: (context, currentFilter, _) {
            final isSelected = currentFilter == value;
            return FilterChip(
              label: Text(
                '$label  $count${backend.hasMoreRepairOrders ? '+' : ''}',
              ),
              selected: isSelected,
              onSelected: (selected) {
                _warrantyFilter.value = selected ? value : null;
              },
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : const Color(0xFFF1F5F9),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, RepairOrderStatus? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final orders = backend.repairOrders;

    return ValueListenableBuilder<bool?>(
      valueListenable: _warrantyFilter,
      builder: (context, currentWarrantyFilter, _) {
        final count = status == null
            ? orders
                  .where(
                    (order) =>
                        currentWarrantyFilter == null ||
                        order.underWarranty == currentWarrantyFilter,
                  )
                  .length
            : orders
                  .where(
                    (order) =>
                        order.status == status &&
                        (currentWarrantyFilter == null ||
                            order.underWarranty == currentWarrantyFilter),
                  )
                  .length;

        return ValueListenableBuilder<RepairOrderStatus?>(
          valueListenable: _filter,
          builder: (context, currentFilter, _) {
            final isSelected = currentFilter == status;
            final countLabel = status == null && currentWarrantyFilter == null
                ? '${backend.repairOrdersTotal}'
                : '$count${backend.hasMoreRepairOrders ? '+' : ''}';
            return FilterChip(
              label: Text('$label  $countLabel'),
              selected: isSelected,
              onSelected: (selected) {
                _filter.value = selected ? status : null;
                if (status == null) {
                  _warrantyFilter.value = null;
                }
              },
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : const Color(0xFFF1F5F9),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        );
      },
    );
  }

  Widget _buildInfiniteScrollFooter(
    int loadedCount,
    int totalCount,
    bool isDark,
    bool wide,
  ) {
    final backend = context.watch<BackendDataProvider>();
    final hasMore = loadedCount < totalCount || backend.hasMoreRepairOrders;
    final filtering =
        _filter.value != null ||
        _searchQuery.value.trim().isNotEmpty ||
        _dateFilter.value != null ||
        _warrantyFilter.value != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 24),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(
              alpha: 0.7,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              Text(
                filtering
                    ? 'Đã hiển thị $loadedCount kết quả • Đã tải ${backend.repairOrders.length}/${backend.repairOrdersTotal} đơn'
                    : 'Đã hiển thị $loadedCount/${backend.repairOrdersTotal} đơn hàng',
                textAlign: TextAlign.center,
              ),
              if (backend.isLoadingMoreRepairOrders)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (backend.repairOrdersPageError != null) ...[
                Text(
                  backend.repairOrdersPageError!,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: _retryPage,
                  child: const Text('Thử lại'),
                ),
              ] else if (hasMore)
                TextButton(
                  onPressed: _loadNextPage,
                  child: const Text('Tải thêm đơn hàng'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isWarrantyValid(DateTime? expiry) {
  if (expiry == null) return true;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
  return !expiryDate.isBefore(today);
}

class _OrderCard extends StatelessWidget {
  final RepairOrder order;
  final bool isDark;

  const _OrderCard({required this.order, required this.isDark});

  String _resolveSerial() {
    if (order.serialNumber != null && order.serialNumber!.trim().isNotEmpty) {
      return order.serialNumber!.trim();
    }
    for (final d in order.devices) {
      if (d.serialNumber != null && d.serialNumber!.trim().isNotEmpty) {
        return d.serialNumber!.trim();
      }
    }
    return 'Không có seri';
  }

  Widget _buildWarrantyBadge() {
    final hasWarranty =
        order.underWarranty || order.devices.any((d) => d.underWarranty);
    if (!hasWarranty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Text(
          'Không BH',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    final isValid = order.devices.isNotEmpty
        ? order.devices.any(
            (d) => d.underWarranty && _isWarrantyValid(d.warrantyExpiry),
          )
        : true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isValid ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isValid ? 'BH • Còn hạn' : 'BH • Hết hạn',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isValid ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        order.customerPhone != null && order.customerPhone!.trim().isNotEmpty;
    final assigneeText = order.assigneeNames.isNotEmpty
        ? order.assigneeNames.join(', ')
        : (order.assignedToName ?? 'Chưa phân công');
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final primaryColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return InkWell(
      onTap: () => _showOrderDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Device Name + Order Code + Top-Right Badges ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.wrench,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildWarrantyBadge(),
                      StatusBadge(status: order.status, size: 'sm'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.45)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark.withValues(alpha: 0.6)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cột trái: Tên khách + SĐT (bấm gọi nhanh) ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  order.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          InkWell(
                            key: ValueKey('call-customer-${order.id}'),
                            onTap: hasPhone
                                ? () => _callCustomerPhone(
                                    context,
                                    order.customerPhone,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasPhone
                                      ? Icons.phone_in_talk_outlined
                                      : Icons.phone_outlined,
                                  size: 13.5,
                                  color: hasPhone
                                      ? AppColors.primary
                                      : secondaryColor,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    hasPhone
                                        ? order.customerPhone!
                                        : 'Chưa có SĐT',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: hasPhone
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: hasPhone
                                          ? AppColors.primary
                                          : secondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: 16,
                      thickness: 1,
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                    ),
                    // ── Cột phải: Ngày nhận + Số seri ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 13.5,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(order.createdAt.toLocal()),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.tag,
                                size: 13.5,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _resolveSerial(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Dòng phụ: Kỹ thuật viên phụ trách & Mô tả lỗi ngắn ──
            Row(
              children: [
                Icon(
                  Icons.engineering_outlined,
                  size: 14,
                  color: secondaryColor,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    assigneeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                if (order.description != null &&
                    order.description!.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '•',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      order.description!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailSheet(order: order),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final RepairOrder order;

  const _OrderDetailSheet({required this.order});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa đơn sửa chữa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa đơn sửa chữa ${order.orderNumber}? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await context.read<BackendDataProvider>().deleteRepairOrder(
                  order.id,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xóa đơn sửa chữa thành công'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa thất bại: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLinkCustomerDialog(
    BuildContext context,
    RepairOrder order,
  ) async {
    final picked = await showCustomerPickerSheet(context);
    if (picked == null || !context.mounted) return;

    if (picked.id == order.customerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đơn hàng đã liên kết với khách hàng này rồi.'),
        ),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isChanging = order.customerId != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(
          isChanging ? 'Chuyển hồ sơ khách hàng' : 'Liên kết hồ sơ khách hàng',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khách hàng: ${picked.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Mã KH: ${picked.customerCode} (${picked.typeLabel})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Lý do thay đổi hồ sơ *',
                  hintText: 'Nhập lý do chuyển/liên kết hồ sơ...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập lý do';
                  }
                  if (v.trim().length < 3) {
                    return 'Lý do phải có ít nhất 3 ký tự';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dlgCtx, true);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final backend = context.read<BackendDataProvider>();
        await backend.linkRepairOrderCustomer(
          order.id,
          customerId: picked.id,
          reason: reasonCtrl.text.trim(),
        );
        await backend.loadRepairOrders();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật liên kết hồ sơ khách hàng thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi liên kết hồ sơ: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildClusterCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order =
        context
            .watch<BackendDataProvider>()
            .repairOrders
            .where((item) => item.id == this.order.id)
            .firstOrNull ??
        this.order;
    final canDelete = context.watch<AuthProvider>().can(
      AppPermission.deleteRepairOrders,
    );
    final hasPhone =
        order.customerPhone != null && order.customerPhone!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModalTopBar(
              title: 'Chi tiết đơn sửa chữa',
              trailing: canDelete
                  ? IconButton(
                      key: const ValueKey('order-detail-delete-button'),
                      tooltip: 'Xóa đơn hàng',
                      onPressed: () => _confirmDelete(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                    )
                  : null,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Tóm tắt thiết bị & trạng thái ──
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.wrench,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.deviceName,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Cụm 1: Thông tin khách hàng ──
                    _buildClusterCard(
                      isDark: isDark,
                      icon: Icons.person_outline,
                      title: 'Thông tin khách hàng',
                      children: [
                        _DetailRow('Khách hàng', order.customerName),
                        Row(
                          children: [
                            Expanded(
                              child: _DetailRow(
                                'SĐT khách',
                                order.customerPhone ?? 'Chưa có',
                              ),
                            ),
                            if (hasPhone)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () => _callCustomerPhone(
                                    context,
                                    order.customerPhone,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.phone_in_talk_outlined,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Gọi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: order.customerId != null
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            )),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: order.customerId != null
                                      ? AppColors.success.withValues(alpha: 0.3)
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.black12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    order.customerId != null
                                        ? LucideIcons.userCheck
                                        : LucideIcons.userX,
                                    size: 12,
                                    color: order.customerId != null
                                        ? AppColors.success
                                        : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.customerId != null
                                        ? 'Đã liên kết hồ sơ'
                                        : 'Chưa liên kết hồ sơ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: order.customerId != null
                                          ? AppColors.success
                                          : (isDark
                                                ? Colors.white60
                                                : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (context.watch<AuthProvider>().can(
                              order.customerId == null
                                  ? AppPermission.assignOrderCustomer
                                  : AppPermission.transferOrderCustomer,
                            ))
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppColors.primary,
                                ),
                                icon: const Icon(LucideIcons.link, size: 13),
                                label: Text(
                                  order.customerId != null
                                      ? 'Chuyển hồ sơ'
                                      : 'Liên kết hồ sơ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () =>
                                    _showLinkCustomerDialog(context, order),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // ── Cụm 2: Thông tin thiết bị ──
                    if (order.devices.length <= 1)
                      _buildClusterCard(
                        isDark: isDark,
                        icon: Icons.devices_outlined,
                        title: 'Thông tin thiết bị',
                        children: [
                          _DetailRow(
                            'Số seri',
                            order.devices.isNotEmpty
                                ? (order.devices.first.serialNumber ??
                                      'Không có')
                                : (order.serialNumber ?? 'Không có'),
                          ),
                          _DetailRow('Bảo hành', () {
                            final isUnderWarranty = order.devices.isNotEmpty
                                ? order.devices.first.underWarranty
                                : order.underWarranty;
                            final expiry = order.devices.isNotEmpty
                                ? order.devices.first.warrantyExpiry
                                : null;
                            if (!isUnderWarranty) return 'Không bảo hành';
                            final isValid = _isWarrantyValid(expiry);
                            final expiryStr = expiry != null
                                ? DateFormat('dd/MM/yyyy').format(expiry)
                                : 'Không rõ';
                            return '$expiryStr (${isValid ? "Còn hạn" : "Hết hạn"})';
                          }()),
                          if (order.devices.isNotEmpty &&
                              order.devices.first.description != null &&
                              order.devices.first.description!.isNotEmpty)
                            _DetailRow(
                              'Mô tả lỗi',
                              order.devices.first.description!,
                            )
                          else if (order.description != null &&
                              order.description!.isNotEmpty)
                            _DetailRow('Mô tả lỗi', order.description!),
                        ],
                      )
                    else ...[
                      Text(
                        'Thiết bị (${order.devices.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.devices.asMap().entries.map(
                        (e) => _DeviceDetailCard(
                          isDark: isDark,
                          index: e.key,
                          deviceName: e.value.deviceName,
                          serialNumber: e.value.serialNumber,
                          underWarranty: e.value.underWarranty,
                          warrantyExpiry: e.value.warrantyExpiry,
                          description: e.value.description,
                          assignedToName: e.value.assignedToName,
                          statusLabel: e.value.statusLabel,
                        ),
                      ),
                    ],
                    // ── Cụm 3: Phân công & Thời gian ──
                    _buildClusterCard(
                      isDark: isDark,
                      icon: Icons.engineering_outlined,
                      title: 'Phân công & Tiến độ',
                      children: [
                        _DetailRow(
                          'Người sửa (đơn)',
                          order.assigneeNames.isNotEmpty
                              ? order.assigneeNames.join(', ')
                              : (order.assignedToName ?? 'Chưa phân công'),
                        ),
                        _DetailRow(
                          'Ngày tạo',
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(order.createdAt.toLocal()),
                        ),
                        if (order.updatedAt != null)
                          _DetailRow(
                            'Cập nhật',
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(order.updatedAt!.toLocal()),
                          ),
                        if (order.notes != null && order.notes!.isNotEmpty)
                          _DetailRow('Ghi chú', order.notes!),
                      ],
                    ),
                    if (order.media.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Đính kèm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: order.media.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 1.0,
                            ),
                        itemBuilder: (context, index) {
                          final media = order.media[index];
                          final url = context
                              .read<BackendDataProvider>()
                              .api
                              .resolveUrl(media.url);
                          if (media.isVideo) {
                            return GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => VideoPlayerDialog(
                                    videoUrl: url,
                                    title: media.caption ?? 'Video đính kèm',
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.grey[200],
                                  child: const Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_circle_outline,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        child: Text(
                                          'VIDEO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => ImagePreviewDialog(
                                  imageUrl: url,
                                  caption: media.caption,
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                headers: mediaAuthHeaders(context, url),
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: isDark
                                            ? AppColors.surfaceDark
                                            : Colors.grey[200],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: isDark
                                        ? AppColors.surfaceDark
                                        : Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 20),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── Sticky Bottom Action Row: 2 nút chính nằm ngang ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PermissionGate.any(
                      permissions: const [
                        AppPermission.updateRepairOrderStatus,
                        AppPermission.cancelRepairOrders,
                      ],
                      child: OutlinedButton(
                        onPressed:
                            context.watch<AuthProvider>().canAny(const [
                              AppPermission.updateRepairOrderStatus,
                              AppPermission.cancelRepairOrders,
                            ])
                            ? () async {
                                final updated =
                                    await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      isDismissible: false,
                                      enableDrag: false,
                                      useSafeArea: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) =>
                                          _OrderStatusSheet(order: order),
                                    );
                                if (updated == true && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cập nhật trạng thái thành công!',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, size: 17),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Cập nhật trạng thái',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PermissionGate.any(
                      permissions: const [
                        AppPermission.updateRepairOrders,
                        AppPermission.assignRepairOrders,
                        AppPermission.uploadRepairMedia,
                        AppPermission.deleteRepairMedia,
                      ],
                      child: ElevatedButton(
                        onPressed:
                            context.watch<AuthProvider>().canAny(const [
                              AppPermission.updateRepairOrders,
                              AppPermission.assignRepairOrders,
                              AppPermission.uploadRepairMedia,
                              AppPermission.deleteRepairMedia,
                            ])
                            ? () async {
                                final updated =
                                    await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          _EditOrderSheet(order: order),
                                    );
                                if (updated == true && context.mounted) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  });
                                }
                              }
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 17),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Chỉnh sửa',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _orderStatuses = [
  MapEntry('PENDING', 'Chưa kiểm tra'),
  MapEntry('WAITING_FOR_CHECK', 'Chờ kiểm tra'),
  MapEntry('CHECKING', 'Đang kiểm tra'),
  MapEntry('CHECKED', 'Đã kiểm tra'),
  MapEntry('IN_PROGRESS', 'Đang sửa'),
  MapEntry('COMPLETED', 'Hoàn thành'),
  MapEntry('DELIVERED', 'Đã giao'),
  MapEntry('CANCELLED', 'Đã trả'),
];

String _orderStatusCode(RepairOrderStatus status) => switch (status) {
  RepairOrderStatus.pending => 'PENDING',
  RepairOrderStatus.waitingForCheck => 'WAITING_FOR_CHECK',
  RepairOrderStatus.checking => 'CHECKING',
  RepairOrderStatus.checked => 'CHECKED',
  RepairOrderStatus.inProgress => 'IN_PROGRESS',
  RepairOrderStatus.completed => 'COMPLETED',
  RepairOrderStatus.delivered => 'DELIVERED',
  RepairOrderStatus.cancelled => 'CANCELLED',
};

class _OrderStatusSheet extends StatefulWidget {
  final RepairOrder order;

  const _OrderStatusSheet({required this.order});

  @override
  State<_OrderStatusSheet> createState() => _OrderStatusSheetState();
}

class _OrderStatusSheetState extends State<_OrderStatusSheet> {
  final _noteController = TextEditingController();
  late String _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = _orderStatusCode(widget.order.status);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _noteController.text.trim();
      await context.read<BackendDataProvider>().updateRepairOrderStatus(
        widget.order.id,
        status: _status,
        note: note.isEmpty ? null : note,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          key: const ValueKey('order-status-update-sheet'),
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height - keyboardInset) * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModalTopBar(
                    title: 'Cập nhật trạng thái',
                    onClose: _saving ? () {} : () => Navigator.pop(context),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đơn hàng: ${widget.order.orderNumber}'),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final entry in _orderStatuses.where(
                                  (entry) => context.watch<AuthProvider>().can(
                                    entry.key == 'CANCELLED'
                                        ? AppPermission.cancelRepairOrders
                                        : AppPermission.updateRepairOrderStatus,
                                  ),
                                ))
                                  SizedBox(
                                    width: (constraints.maxWidth - 8) / 2,
                                    child: Builder(
                                      builder: (context) {
                                        final visual = _statusVisualForCode(
                                          entry.key,
                                          isDark: isDark,
                                        );
                                        return ChoiceChip(
                                          key: ValueKey(
                                            'update-status-${entry.key}',
                                          ),
                                          selected: _status == entry.key,
                                          onSelected: _saving
                                              ? null
                                              : (_) => setState(
                                                  () => _status = entry.key,
                                                ),
                                          showCheckmark: false,
                                          avatar: Icon(
                                            visual.icon,
                                            color: visual.color,
                                            size: 20,
                                          ),
                                          backgroundColor: visual.bgColor,
                                          selectedColor: visual.color
                                              .withValues(alpha: 0.2),
                                          side: BorderSide(
                                            color: _status == entry.key
                                                ? visual.color
                                                : visual.borderColor,
                                            width: _status == entry.key ? 2 : 1,
                                          ),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: visual.color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  visual.label,
                                                  style: TextStyle(
                                                    color: visual.color,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _noteController,
                            enabled: !_saving,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Ghi chú (không bắt buộc)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _saving ||
                                    _status ==
                                        _orderStatusCode(widget.order.status)
                                ? null
                                : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Lưu thay đổi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailCard extends StatelessWidget {
  final bool isDark;
  final int index;
  final String deviceName;
  final String? serialNumber;
  final bool underWarranty;
  final DateTime? warrantyExpiry;
  final String? description;
  final String? assignedToName;
  final String? statusLabel;

  const _DeviceDetailCard({
    required this.isDark,
    required this.index,
    required this.deviceName,
    this.serialNumber,
    this.underWarranty = false,
    this.warrantyExpiry,
    this.description,
    this.assignedToName,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thiết bị ${index + 1}: $deviceName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: underWarranty
                            ? AppColors.infoLight
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        underWarranty ? 'Bảo hành' : 'Không BH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: underWarranty
                              ? AppColors.primary
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (underWarranty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isWarrantyValid(warrantyExpiry)
                              ? AppColors.successLight
                              : AppColors.errorLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isWarrantyValid(warrantyExpiry)
                              ? 'Còn hạn'
                              : 'Hết hạn',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isWarrantyValid(warrantyExpiry)
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (serialNumber != null && serialNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Số seri: $serialNumber',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
            if (underWarranty && warrantyExpiry != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: !_isWarrantyValid(warrantyExpiry)
                        ? AppColors.error
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn bảo hành: ${DateFormat('dd/MM/yyyy').format(warrantyExpiry!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: !_isWarrantyValid(warrantyExpiry)
                          ? AppColors.error
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      fontWeight: !_isWarrantyValid(warrantyExpiry)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (!_isWarrantyValid(warrantyExpiry)) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '(Hết hạn)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (assignedToName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Phụ trách: $assignedToName',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
            if (statusLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final bool isDark;

  const _EmptyOrders({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.searchX,
            size: 44,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 14),
          Text(
            'Không tìm thấy đơn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thử thay đổi từ khóa hoặc bộ lọc',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderSheet extends StatefulWidget {
  final RepairOrder order;

  const _EditOrderSheet({required this.order});

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _noteController;
  final Set<String> _technicianIds = <String>{};
  String? _nextStatus;
  bool _saving = false;

  // Danh sách thiết bị
  final List<_DeviceFormEntry> _deviceEntries = [];

  // Danh sách hình ảnh/video chọn mới
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();
  // Danh sách media ID muốn xóa
  final Set<String> _deletedMediaIds = {};

  bool _isVideo(String path) {
    final lowercase = path.toLowerCase();
    return lowercase.endsWith('.mp4') ||
        lowercase.endsWith('.mov') ||
        lowercase.endsWith('.avi') ||
        lowercase.endsWith('.mkv') ||
        lowercase.endsWith('.webm');
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  Future<void> _pickMultiImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedias.addAll(pickedFiles);
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  bool get _canAssign =>
      context.read<AuthProvider>().can(AppPermission.assignRepairOrders);

  String get _currentStatusBackendCode => _orderStatusCode(widget.order.status);

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(
      text: widget.order.customerName,
    );
    _customerPhoneController = TextEditingController(
      text: widget.order.customerPhone ?? '',
    );
    _noteController = TextEditingController(text: widget.order.notes ?? '');

    // Khởi tạo device entries từ dữ liệu đơn hiện tại
    if (widget.order.devices.isNotEmpty) {
      for (final d in widget.order.devices) {
        final entry = _DeviceFormEntry(initialName: d.deviceName);
        entry.serialController.text = d.serialNumber ?? '';
        entry.descController.text = d.description ?? '';
        entry.underWarranty = d.underWarranty;
        entry.warrantyExpiry = d.warrantyExpiry;

        // Tự động khôi phục ngày bảo hành (warrantyStartDate) từ ngày hết hạn
        if (d.warrantyExpiry != null) {
          final expiry = d.warrantyExpiry!;
          final createdAt = widget.order.createdAt;

          DateTime subtractMonths(DateTime date, int months) {
            int targetYear = date.year;
            int targetMonth = date.month - months;
            while (targetMonth <= 0) {
              targetYear -= 1;
              targetMonth += 12;
            }
            final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
            final day = date.day > lastDay ? lastDay : date.day;
            return DateTime(targetYear, targetMonth, day);
          }

          final start6 = subtractMonths(expiry, 6);
          final start12 = subtractMonths(expiry, 12);

          final diff6 = (start6.difference(createdAt).inDays).abs();
          final diff12 = (start12.difference(createdAt).inDays).abs();

          entry.warrantyStartDate = diff6 < diff12 ? start6 : start12;
        }

        entry.assignedToId = d.assignedToId;
        entry.assignedToName = d.assignedToName;
        _deviceEntries.add(entry);
      }
    } else {
      // Fallback: tạo 1 entry từ các field cũ của đơn
      final entry = _DeviceFormEntry(initialName: widget.order.deviceName);
      entry.serialController.text = widget.order.serialNumber ?? '';
      entry.descController.text = widget.order.description ?? '';
      entry.underWarranty = widget.order.underWarranty;
      _deviceEntries.add(entry);
    }

    _technicianIds.addAll(widget.order.assigneeIds);
    if (_technicianIds.isEmpty && widget.order.assignedToId != null) {
      _technicianIds.add(widget.order.assignedToId!);
    }
    _nextStatus = _currentStatusBackendCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canAssign) {
        final backend = context.read<BackendDataProvider>();
        if (backend.repairAssignees.isEmpty) {
          backend.loadRepairAssignees();
        }
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    for (final e in _deviceEntries) {
      e.dispose();
    }
    super.dispose();
  }

  List<MapEntry<String, String>> _availableStatuses() {
    return _orderStatuses;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final Set<String> originalIds = widget.order.assigneeIds.toSet();
    if (originalIds.isEmpty && widget.order.assignedToId != null) {
      originalIds.add(widget.order.assignedToId!);
    }

    bool infoChanged =
        _customerNameController.text.trim() != widget.order.customerName ||
        _customerPhoneController.text.replaceAll(RegExp(r'\D'), '') !=
            (widget.order.customerPhone ?? '').replaceAll(RegExp(r'\D'), '');

    if (!infoChanged) {
      if (_deviceEntries.length != widget.order.devices.length) {
        infoChanged = true;
      } else {
        for (int i = 0; i < _deviceEntries.length; i++) {
          final entry = _deviceEntries[i];
          final orig = widget.order.devices[i];
          if (entry.nameController.text.trim() != orig.deviceName ||
              (entry.serialController.text.trim().isEmpty
                      ? null
                      : entry.serialController.text.trim()) !=
                  orig.serialNumber ||
              entry.underWarranty != orig.underWarranty ||
              entry.warrantyExpiry != orig.warrantyExpiry ||
              (entry.descController.text.trim().isEmpty
                      ? null
                      : entry.descController.text.trim()) !=
                  orig.description ||
              entry.assignedToId != orig.assignedToId) {
            infoChanged = true;
            break;
          }
        }
      }
    }

    final assignmentChanged =
        _canAssign &&
        (!originalIds.containsAll(_technicianIds) ||
            !_technicianIds.containsAll(originalIds));

    final mediaChanged =
        _selectedMedias.isNotEmpty || _deletedMediaIds.isNotEmpty;
    final statusChanged =
        _nextStatus != null && _nextStatus != _currentStatusBackendCode;
    final note = _noteController.text.trim();
    final noteChanged = note != (widget.order.notes ?? '');

    if (!assignmentChanged &&
        !statusChanged &&
        !infoChanged &&
        !mediaChanged &&
        !noteChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có thay đổi để lưu.')));
      return;
    }

    setState(() => _saving = true);
    final backend = context.read<BackendDataProvider>();
    try {
      if ((infoChanged || noteChanged) &&
          context.read<AuthProvider>().can(AppPermission.updateRepairOrders)) {
        await backend.updateRepairOrder(
          widget.order.id,
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.replaceAll(
            RegExp(r'\D'),
            '',
          ),
          devices: _deviceEntries
              .map(
                (e) => RepairDevice(
                  id: '',
                  deviceName: e.nameController.text.trim(),
                  serialNumber: e.serialController.text.trim().isEmpty
                      ? null
                      : e.serialController.text.trim(),
                  underWarranty: e.underWarranty,
                  warrantyExpiry: e.underWarranty ? e.warrantyExpiry : null,
                  description: e.descController.text.trim().isEmpty
                      ? null
                      : e.descController.text.trim(),
                  assignedToId: e.assignedToId,
                ),
              )
              .toList(),
          note: note,
          reload: !assignmentChanged && !statusChanged && !mediaChanged,
        );
      }
      if (assignmentChanged) {
        await backend.assignRepairOrder(
          widget.order.id,
          technicianIds: _technicianIds.toList(),
          note: note.isEmpty ? null : note,
          reload: !statusChanged && !mediaChanged,
        );
      }
      if (statusChanged) {
        await backend.updateRepairOrderStatus(
          widget.order.id,
          status: _nextStatus!,
          note: note.isEmpty ? null : note,
        );
      }
      if (_deletedMediaIds.isNotEmpty) {
        for (final mediaId in _deletedMediaIds) {
          await backend.deleteRepairMedia(
            widget.order.id,
            mediaId: mediaId,
            reload: false,
          );
        }
      }
      if (_selectedMedias.isNotEmpty) {
        for (final media in _selectedMedias) {
          await backend.uploadRepairMedia(
            widget.order.id,
            bytes: await media.readAsBytes(),
            filename: media.name,
            isVideo: _isVideo(media.path),
          );
        }
      }
      if (mediaChanged) {
        await backend.loadRepairOrders();
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật đơn sửa chữa thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  InputDecoration _unifiedInputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    bool alignLabelWithHint = false,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
  }) {
    final effectiveSuffixIcon = suffixIcon ??
        (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number
            ? IconButton(
                icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                tooltip: 'Ẩn bàn phím',
                onPressed: () => FocusScope.of(context).unfocus(),
              )
            : null);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction ??
          (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: _unifiedInputDecoration(
        context,
        label: label,
        hint: hint,
        icon: icon,
        alignLabelWithHint: maxLines > 1,
        suffixIcon: effectiveSuffixIcon,
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Trường này không được để trống';
        }
        return null;
      },
    );
  }

  String _resolveTechnicianName(String id, BackendDataProvider backend) {
    if (id.startsWith('name:')) {
      return id.substring(5);
    }
    for (final emp in backend.repairAssignees) {
      if (emp.id == id) return emp.name;
    }
    final idx = widget.order.assigneeIds.indexOf(id);
    if (idx != -1 && idx < widget.order.assigneeNames.length) {
      return widget.order.assigneeNames[idx];
    }
    if (id == widget.order.assignedToId &&
        widget.order.assignedToName != null) {
      return widget.order.assignedToName!;
    }
    return 'Kỹ thuật viên';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final technicians = backend.repairAssignees
        .where(
          (user) =>
              (user.role == UserRole.employee ||
                  user.role == UserRole.technician) &&
              user.status == UserStatus.active,
        )
        .toList();
    final statuses = _availableStatuses()
        .where(
          (entry) => context.watch<AuthProvider>().can(
            entry.key == 'CANCELLED'
                ? AppPermission.cancelRepairOrders
                : AppPermission.updateRepairOrderStatus,
          ),
        )
        .toList();
    final existingMedias = widget.order.media
        .where((m) => !_deletedMediaIds.contains(m.id))
        .toList();

    return _KeyboardBottomPadding(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModalTopBar(title: 'Chỉnh sửa ${widget.order.orderNumber}'),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Section 1: Thông tin khách hàng ──
                        if (context.watch<AuthProvider>().can(
                          AppPermission.updateRepairOrders,
                        ))
                          _FormSectionCard(
                            isDark: isDark,
                            icon: Icons.person_outline,
                            title: '1. Thông tin khách hàng',
                            children: [
                              _buildTextField(
                                context,
                                controller: _customerNameController,
                                label: 'Tên khách hàng',
                                hint: 'Nhập tên khách hàng',
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                context,
                                controller: _customerPhoneController,
                                label: 'Số điện thoại',
                                hint: '0901 234 567',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                required: false,
                              ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        // ── Section 2: Thông tin thiết bị ──
                        if (context.watch<AuthProvider>().can(
                          AppPermission.updateRepairOrders,
                        ))
                          _FormSectionCard(
                            isDark: isDark,
                            icon: Icons.devices_outlined,
                            title: '2. Thông tin thiết bị',
                            children: List.generate(_deviceEntries.length, (
                              index,
                            ) {
                              final entry = _deviceEntries[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < _deviceEntries.length - 1
                                      ? 16
                                      : 0,
                                ),
                                child: _DeviceFormCard(
                                  key: ValueKey(entry.id),
                                  index: index,
                                  entry: entry,
                                  isDark: isDark,
                                  canAssign: _canAssign,
                                  technicians: technicians,
                                  canRemove: _deviceEntries.length > 1,
                                  onRemove: () => setState(
                                    () => _deviceEntries.removeAt(index),
                                  ),
                                  onChanged: () => setState(() {}),
                                  orderCreatedAt: widget.order.createdAt,
                                ),
                              );
                            }),
                          ),
                        const SizedBox(height: 14),
                        // ── Section 3: Xử lý & Phân công ──
                        _FormSectionCard(
                          isDark: isDark,
                          icon: Icons.engineering_outlined,
                          title: '3. Xử lý & Phân công',
                          children: [
                            PermissionGate(
                              permission: AppPermission.assignRepairOrders,
                              child: _UnifiedTechnicianAssignmentField(
                                isDark: isDark,
                                canAssign: _canAssign,
                                selectedIds: _technicianIds,
                                resolveName: (id) =>
                                    _resolveTechnicianName(id, backend),
                                onTapPick: _canAssign
                                    ? () async {
                                        final selected =
                                            await showModalBottomSheet<
                                              Set<String>
                                            >(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) =>
                                                  _TechnicianMultiSelectBottomSheet(
                                                    technicians: technicians,
                                                    initialSelected:
                                                        _technicianIds,
                                                    isDark: isDark,
                                                  ),
                                            );
                                        if (selected != null) {
                                          setState(() {
                                            _technicianIds
                                              ..clear()
                                              ..addAll(selected);
                                          });
                                        }
                                      }
                                    : null,
                                onRemoveId: _canAssign
                                    ? (id) => setState(
                                        () => _technicianIds.remove(id),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 14),
                            PermissionGate(
                              permission: AppPermission.updateRepairOrderStatus,
                              child: _OrderStatusSelectorField(
                                isDark: isDark,
                                selectedStatusCode:
                                    _nextStatus ?? _currentStatusBackendCode,
                                statuses: statuses,
                                onStatusSelected: (value) =>
                                    setState(() => _nextStatus = value),
                              ),
                            ),
                            const SizedBox(height: 14),
                            PermissionGate.any(
                              permissions: const [
                                AppPermission.uploadRepairMedia,
                                AppPermission.deleteRepairMedia,
                              ],
                              child: _UnifiedMediaPickerBox(
                                isDark: isDark,
                                existingMediaWidgets: existingMedias.map((m) {
                                  final url = backend.api.resolveUrl(m.url);
                                  return _MediaThumbItem(
                                    isVideo: m.isVideo,
                                    imageUrl: m.isVideo ? null : url,
                                    label: 'Video',
                                    onRemove:
                                        context.watch<AuthProvider>().can(
                                          AppPermission.deleteRepairMedia,
                                        )
                                        ? () => setState(
                                            () => _deletedMediaIds.add(m.id),
                                          )
                                        : null,
                                  );
                                }).toList(),
                                newMediaFiles: _selectedMedias,
                                isVideoPath: _isVideo,
                                onRemoveNewAt: (idx) => setState(
                                  () => _selectedMedias.removeAt(idx),
                                ),
                                onCamera: () => _pickImage(ImageSource.camera),
                                onGallery: _pickMultiImages,
                                onVideo: _pickVideo,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 14),
                              decoration: _unifiedInputDecoration(
                                context,
                                label: 'Ghi chú xử lý',
                                hint: 'Nhập ghi chú hoặc kết quả kiểm tra...',
                                icon: Icons.notes_outlined,
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Sticky Bottom Bar: Ghim cố định nút "Lưu thay đổi" ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.06,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  key: const ValueKey('edit-order-sticky-save-button'),
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
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
}

class _FormSectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _FormSectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Helper: Lấy ký tự đầu của tên chính (ví dụ: Nguyễn Tấn Phát -> P) ──────
String _givenNameInitial(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'K';
  return parts.last.substring(0, 1).toUpperCase();
}

class _UnifiedTechnicianAssignmentField extends StatelessWidget {
  final bool isDark;
  final bool canAssign;
  final Set<String> selectedIds;
  final String Function(String id) resolveName;
  final VoidCallback? onTapPick;
  final void Function(String id)? onRemoveId;

  const _UnifiedTechnicianAssignmentField({
    required this.isDark,
    required this.canAssign,
    required this.selectedIds,
    required this.resolveName,
    this.onTapPick,
    this.onRemoveId,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
      key: const ValueKey('order-technician-selector'),
      onTap: onTapPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kỹ thuật viên phụ trách',
          prefixIcon: const Icon(Icons.engineering_outlined, size: 20),
          suffixIcon: canAssign
              ? Icon(Icons.keyboard_arrow_down_rounded, color: secondaryColor)
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: selectedIds.isEmpty
            ? Text(
                canAssign ? 'Chưa phân công (Chạm để chọn)' : 'Chưa phân công',
                style: TextStyle(fontSize: 13.5, color: secondaryColor),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...selectedIds.map((id) {
                    final name = resolveName(id);
                    return InputChip(
                      key: ValueKey('assigned-tech-chip-$id'),
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          _givenNameInitial(name),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      label: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      backgroundColor: AppColors.primary.withValues(
                        alpha: isDark ? 0.18 : 0.08,
                      ),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      deleteIcon: const Icon(Icons.close_rounded, size: 15),
                      deleteIconColor: AppColors.error,
                      deleteButtonTooltipMessage: 'Bỏ chọn $name',
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: onTapPick,
                      onDeleted: onRemoveId != null
                          ? () => onRemoveId!(id)
                          : null,
                    );
                  }),
                ],
              ),
      ),
    );
  }
}

// ─── Cấu hình màu sắc & Icon cho Trạng thái đơn hàng ─────────────────────────

class _OrderStatusVisual {
  final String code;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _OrderStatusVisual({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}

_OrderStatusVisual _statusVisualForCode(String code, {bool isDark = false}) {
  switch (code) {
    case 'PENDING':
      return _OrderStatusVisual(
        code: code,
        label: 'Chưa kiểm tra',
        subtitle: 'Đơn mới tiếp nhận, chưa kiểm tra',
        icon: Icons.radio_button_unchecked_rounded,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      );
    case 'WAITING_FOR_CHECK':
      return _OrderStatusVisual(
        code: code,
        label: 'Chờ kiểm tra',
        subtitle: 'Đang xếp hàng chờ kỹ thuật kiểm tra',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFF0284C7),
        bgColor: isDark
            ? const Color(0xFF0284C7).withValues(alpha: 0.16)
            : const Color(0xFFE0F2FE),
        borderColor: const Color(0xFF7DD3FC),
      );
    case 'CHECKING':
      return _OrderStatusVisual(
        code: code,
        label: 'Đang kiểm tra',
        subtitle: 'Kỹ thuật viên đang đo đạc, chẩn đoán lỗi',
        icon: Icons.manage_search_rounded,
        color: const Color(0xFF6366F1),
        bgColor: isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.16)
            : const Color(0xFFEEF2FF),
        borderColor: const Color(0xFFA5B4FC),
      );
    case 'CHECKED':
      return _OrderStatusVisual(
        code: code,
        label: 'Đã kiểm tra',
        subtitle: 'Đã xác định nguyên nhân lỗi & phương án',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF0D9488),
        bgColor: isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.16)
            : const Color(0xFFCCFBF1),
        borderColor: const Color(0xFF5EEAD4),
      );
    case 'IN_PROGRESS':
      return _OrderStatusVisual(
        code: code,
        label: 'Đang sửa',
        subtitle: 'Đang tiến hành sửa chữa, thay thế linh kiện',
        icon: Icons.build_circle_outlined,
        color: const Color(0xFFD97706),
        bgColor: isDark
            ? const Color(0xFFD97706).withValues(alpha: 0.16)
            : const Color(0xFFFEF3C7),
        borderColor: const Color(0xFFFCD34D),
      );
    case 'COMPLETED':
      return _OrderStatusVisual(
        code: code,
        label: 'Hoàn thành',
        subtitle: 'Đã sửa xong và kiểm tra vận hành ổn định',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF16A34A),
        bgColor: isDark
            ? const Color(0xFF16A34A).withValues(alpha: 0.16)
            : const Color(0xFFDCFCE7),
        borderColor: const Color(0xFF86EFAC),
      );
    case 'DELIVERED':
      return _OrderStatusVisual(
        code: code,
        label: 'Đã giao',
        subtitle: 'Đã bàn giao thiết bị cho khách hàng',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF2563EB),
        bgColor: isDark
            ? const Color(0xFF2563EB).withValues(alpha: 0.16)
            : const Color(0xFFDBEAFE),
        borderColor: const Color(0xFF93C5FD),
      );
    case 'CANCELLED':
      return _OrderStatusVisual(
        code: code,
        label: 'Đã trả',
        subtitle: 'Hoàn trả thiết bị cho khách hàng',
        icon: Icons.assignment_return_outlined,
        color: const Color(0xFFDC2626),
        bgColor: isDark
            ? const Color(0xFFDC2626).withValues(alpha: 0.16)
            : const Color(0xFFFEE2E2),
        borderColor: const Color(0xFFFCA5A5),
      );
    default:
      return _OrderStatusVisual(
        code: code,
        label: code,
        subtitle: '',
        icon: Icons.radio_button_unchecked_rounded,
        color: const Color(0xFF64748B),
        bgColor: const Color(0xFFF1F5F9),
        borderColor: const Color(0xFFCBD5E1),
      );
  }
}

class _OrderStatusSelectorField extends StatelessWidget {
  final bool isDark;
  final String selectedStatusCode;
  final List<MapEntry<String, String>> statuses;
  final ValueChanged<String> onStatusSelected;

  const _OrderStatusSelectorField({
    required this.isDark,
    required this.selectedStatusCode,
    required this.statuses,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _statusVisualForCode(selectedStatusCode, isDark: isDark);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
      key: const ValueKey('order-status-selector'),
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _OrderStatusPickerSheet(
            selectedStatusCode: selectedStatusCode,
            statuses: statuses,
            isDark: isDark,
          ),
        );
        if (picked != null) {
          onStatusSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Trạng thái đơn hàng',
          prefixIcon: Icon(visual.icon, size: 20, color: visual.color),
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: secondaryColor,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: visual.bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: visual.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: visual.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    visual.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: visual.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusPickerSheet extends StatelessWidget {
  final String selectedStatusCode;
  final List<MapEntry<String, String>> statuses;
  final bool isDark;

  const _OrderStatusPickerSheet({
    required this.selectedStatusCode,
    required this.statuses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalTopBar(title: 'Chọn trạng thái đơn hàng'),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: statuses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = statuses[index];
                    final visual = _statusVisualForCode(
                      entry.key,
                      isDark: isDark,
                    );
                    final isSelected = entry.key == selectedStatusCode;

                    return InkWell(
                      key: ValueKey('status-option-${entry.key}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? visual.bgColor
                              : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? visual.color
                                : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: visual.bgColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: visual.borderColor),
                              ),
                              child: Icon(
                                visual.icon,
                                color: visual.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          visual.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: visual.bgColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: visual.borderColor,
                                          ),
                                        ),
                                        child: Text(
                                          visual.label,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: visual.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (visual.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      visual.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? visual.color
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.grey[400]),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaThumbItem extends StatelessWidget {
  final bool isVideo;
  final String? imageUrl;
  final File? localFile;
  final String label;
  final VoidCallback? onRemove;

  const _MediaThumbItem({
    required this.isVideo,
    this.imageUrl,
    this.localFile,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isVideo
                ? Container(
                    width: 84,
                    height: 84,
                    color: AppColors.infoLight.withValues(alpha: 0.25),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_circle_outline,
                          size: 28,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : localFile != null
                ? Image.file(
                    localFile!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    imageUrl ?? '',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 84,
                      height: 84,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 18),
                    ),
                  ),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  static const double _strokeWidth = 1.4;
  static const double _dashWidth = 5.0;
  static const double _dashGap = 3.5;

  const _DashedRectPainter({required this.color, this.radius = 12.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += _dashWidth + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _UnifiedMediaPickerBox extends StatelessWidget {
  final bool isDark;
  final List<Widget> existingMediaWidgets;
  final List<XFile> newMediaFiles;
  final bool Function(String path) isVideoPath;
  final void Function(int index) onRemoveNewAt;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;

  const _UnifiedMediaPickerBox({
    required this.isDark,
    this.existingMediaWidgets = const [],
    required this.newMediaFiles,
    required this.isVideoPath,
    required this.onRemoveNewAt,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
  });

  Future<void> _showMediaActionSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ModalTopBar(title: 'Thêm ảnh / video đính kèm'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          key: const ValueKey('media-action-camera'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          title: const Text(
                            'Chụp ảnh mới',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Mở máy ảnh chụp trực tiếp tình trạng thiết bị',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            onCamera();
                          },
                        ),
                        const SizedBox(height: 6),
                        ListTile(
                          key: const ValueKey('media-action-gallery'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: AppColors.success,
                            ),
                          ),
                          title: const Text(
                            'Chọn từ thư viện',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Chọn một hoặc nhiều ảnh có sẵn trong máy',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            onGallery();
                          },
                        ),
                        const SizedBox(height: 6),
                        ListTile(
                          key: const ValueKey('media-action-video'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.videocam_outlined,
                              color: AppColors.warning,
                            ),
                          ),
                          title: const Text(
                            'Quay/Chọn video',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Đính kèm video ghi lại lỗi hoặc quá trình kiểm tra',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            onVideo();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = existingMediaWidgets.length + newMediaFiles.length;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 16, color: secondaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Đính kèm ảnh / video',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              if (totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount tệp',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: Row(
              children: [
                // Ô viền nét đứt "+ Thêm ảnh / video" ở góc trái
                if (context.watch<AuthProvider>().can(
                  AppPermission.uploadRepairMedia,
                ))
                  InkWell(
                    key: const ValueKey('media-picker-add-tile'),
                    onTap: () => _showMediaActionSheet(context),
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _DashedRectPainter(
                        color: AppColors.primary.withValues(alpha: 0.65),
                        radius: 12,
                      ),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: isDark ? 0.12 : 0.05,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '+ Thêm\nảnh / video',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                // Danh sách cuộn ngang hiển thị preview ảnh/video bên phải
                Expanded(
                  child: totalCount == 0
                      ? Container(
                          height: 84,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark.withValues(alpha: 0.4)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark.withValues(alpha: 0.6)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Chưa có ảnh/video đính kèm.\nBấm vào dấu + bên trái để tải lên.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: secondaryColor,
                            ),
                          ),
                        )
                      : ListView(
                          key: const ValueKey('media-picker-preview-list'),
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...existingMediaWidgets,
                            ...newMediaFiles.asMap().entries.map((e) {
                              final index = e.key;
                              final file = e.value;
                              final isVideo = isVideoPath(file.path);
                              return _MediaThumbItem(
                                isVideo: isVideo,
                                localFile: isVideo ? null : File(file.path),
                                label: 'Video mới',
                                onRemove: () => onRemoveNewAt(index),
                              );
                            }),
                          ],
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

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet();

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  Customer? _selectedCustomer;
  bool _isManualCustomer = false;
  bool _isLoading = false;
  final Set<String> _technicianIds = <String>{};
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();

  // Danh sách thiết bị — mỗi phần tử giữ các controller của 1 thiết bị
  final List<_DeviceFormEntry> _deviceEntries = [];

  @override
  void initState() {
    super.initState();
    _deviceEntries.add(_DeviceFormEntry()); // Ít nhất 1 thiết bị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final canAssign = context.read<AuthProvider>().can(
          AppPermission.assignRepairOrders,
        );
        if (canAssign) {
          final backend = context.read<BackendDataProvider>();
          if (backend.repairAssignees.isEmpty) {
            backend.loadRepairAssignees();
          }
        }
      }
    });
  }

  bool _isVideo(String path) {
    final lowercase = path.toLowerCase();
    return lowercase.endsWith('.mp4') ||
        lowercase.endsWith('.mov') ||
        lowercase.endsWith('.avi') ||
        lowercase.endsWith('.mkv') ||
        lowercase.endsWith('.webm');
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  Future<void> _pickMultiImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedias.addAll(pickedFiles);
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final backend = context.read<BackendDataProvider>();

    final String? customerId = (_selectedCustomer != null && !_isManualCustomer)
        ? _selectedCustomer!.id
        : null;
    final String? customerName = customerId != null
        ? null
        : _customerNameController.text.trim();
    final String? customerPhone = customerId != null
        ? null
        : (_customerPhoneController.text.replaceAll(RegExp(r'\D'), '').isEmpty
              ? null
              : _customerPhoneController.text.replaceAll(RegExp(r'\D'), ''));

    try {
      final order = await backend.createRepairOrder(
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        devices: _deviceEntries
            .map(
              (e) => RepairDevice(
                id: '',
                deviceName: e.nameController.text.trim(),
                serialNumber: e.serialController.text.trim().isEmpty
                    ? null
                    : e.serialController.text.trim(),
                underWarranty: e.underWarranty,
                warrantyExpiry: e.underWarranty ? e.warrantyExpiry : null,
                description: e.descController.text.trim().isEmpty
                    ? null
                    : e.descController.text.trim(),
                assignedToId: e.assignedToId,
              ),
            )
            .toList(),
      );
      for (final media in _selectedMedias) {
        await backend.uploadRepairMedia(
          order.id,
          bytes: await media.readAsBytes(),
          filename: media.name,
          isVideo: _isVideo(media.path),
        );
      }
      if (_technicianIds.isNotEmpty) {
        await backend.assignRepairOrder(
          order.id,
          technicianIds: _technicianIds.toList(),
          reload: false,
        );
      }
      await backend.loadRepairOrders();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo đơn sửa chữa thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    for (final e in _deviceEntries) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAssign = context.watch<AuthProvider>().can(
      AppPermission.assignRepairOrders,
    );
    final technicians = context
        .watch<BackendDataProvider>()
        .repairAssignees
        .where(
          (user) =>
              (user.role == UserRole.employee ||
                  user.role == UserRole.technician) &&
              user.status == UserStatus.active,
        )
        .toList();

    return _KeyboardBottomPadding(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModalTopBar(title: 'Tạo đơn sửa chữa mới'),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormSectionCard(
                            isDark: isDark,
                            icon: Icons.person_outline,
                            title: '1. Thông tin khách hàng',
                            children: [
                              if (_selectedCustomer != null &&
                                  !_isManualCustomer) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                _selectedCustomer!.isCompany
                                                ? const Color(
                                                    0xFF8B5CF6,
                                                  ).withValues(alpha: 0.15)
                                                : AppColors.primary.withValues(
                                                    alpha: 0.15,
                                                  ),
                                            foregroundColor:
                                                _selectedCustomer!.isCompany
                                                ? const Color(0xFF8B5CF6)
                                                : AppColors.primary,
                                            child: Icon(
                                              _selectedCustomer!.isCompany
                                                  ? LucideIcons.building2
                                                  : LucideIcons.user,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedCustomer!.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  '${_selectedCustomer!.typeLabel} • ${_selectedCustomer!.customerCode}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : AppColors
                                                              .textSecondaryLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              final picked =
                                                  await showCustomerPickerSheet(
                                                    context,
                                                  );
                                              if (picked != null) {
                                                setState(
                                                  () => _selectedCustomer =
                                                      picked,
                                                );
                                              }
                                            },
                                            child: const Text('Đổi'),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            tooltip: 'Bỏ chọn',
                                            onPressed: () {
                                              setState(() {
                                                _selectedCustomer = null;
                                                _isManualCustomer = true;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      if (_selectedCustomer!.phone != null &&
                                          _selectedCustomer!
                                              .phone!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              LucideIcons.phone,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedCustomer!.phone!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: const BorderSide(
                                            color: AppColors.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                        icon: const Icon(
                                          LucideIcons.userCheck,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Chọn từ danh bạ khách hàng',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () async {
                                          final picked =
                                              await showCustomerPickerSheet(
                                                context,
                                              );
                                          if (picked != null) {
                                            setState(() {
                                              _selectedCustomer = picked;
                                              _isManualCustomer = false;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  context,
                                  controller: _customerNameController,
                                  label: 'Tên khách hàng lẻ',
                                  hint: 'Nhập tên khách hàng',
                                  icon: Icons.person_outline,
                                  required:
                                      _selectedCustomer == null ||
                                      _isManualCustomer,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  context,
                                  controller: _customerPhoneController,
                                  label: 'Số điện thoại',
                                  hint: '0901 234 567',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  required: false,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FormSectionCard(
                            isDark: isDark,
                            icon: Icons.devices_outlined,
                            title: '2. Thông tin thiết bị',
                            children: List.generate(_deviceEntries.length, (
                              index,
                            ) {
                              final entry = _deviceEntries[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < _deviceEntries.length - 1
                                      ? 16
                                      : 0,
                                ),
                                child: _DeviceFormCard(
                                  key: ValueKey(entry.id),
                                  index: index,
                                  entry: entry,
                                  isDark: isDark,
                                  canAssign: canAssign,
                                  technicians: technicians,
                                  canRemove: _deviceEntries.length > 1,
                                  onRemove: () => setState(
                                    () => _deviceEntries.removeAt(index),
                                  ),
                                  onChanged: () => setState(() {}),
                                  orderCreatedAt: null,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          _FormSectionCard(
                            isDark: isDark,
                            icon: Icons.engineering_outlined,
                            title: '3. Xử lý & Phân công',
                            children: [
                              if (canAssign) ...[
                                PermissionGate(
                                  permission: AppPermission.assignRepairOrders,
                                  child: _UnifiedTechnicianAssignmentField(
                                    isDark: isDark,
                                    canAssign: canAssign,
                                    selectedIds: _technicianIds,
                                    resolveName: (id) => technicians
                                        .firstWhere(
                                          (t) => t.id == id,
                                          orElse: () => User(
                                            id: id,
                                            name: 'Kỹ thuật viên',
                                            email: '',
                                            employeeId: '',
                                            role: UserRole.employee,
                                            status: UserStatus.active,
                                          ),
                                        )
                                        .name,
                                    onTapPick: () async {
                                      final selected =
                                          await showModalBottomSheet<
                                            Set<String>
                                          >(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) =>
                                                _TechnicianMultiSelectBottomSheet(
                                                  technicians: technicians,
                                                  initialSelected:
                                                      _technicianIds,
                                                  isDark: isDark,
                                                ),
                                          );
                                      if (selected != null) {
                                        setState(() {
                                          _technicianIds
                                            ..clear()
                                            ..addAll(selected);
                                        });
                                      }
                                    },
                                    onRemoveId: (id) => setState(
                                      () => _technicianIds.remove(id),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              PermissionGate(
                                permission: AppPermission.uploadRepairMedia,
                                child: _UnifiedMediaPickerBox(
                                  isDark: isDark,
                                  newMediaFiles: _selectedMedias,
                                  isVideoPath: _isVideo,
                                  onRemoveNewAt: (idx) => setState(
                                    () => _selectedMedias.removeAt(idx),
                                  ),
                                  onCamera: () =>
                                      _pickImage(ImageSource.camera),
                                  onGallery: _pickMultiImages,
                                  onVideo: _pickVideo,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Sticky Bottom Bar: Ghim cố định nút "Tạo đơn hàng" ──
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.06,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createOrder,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_circle_outline, size: 18),
                      label: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Tạo đơn hàng',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSuffixIcon = suffixIcon ??
        (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number
            ? IconButton(
                icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                tooltip: 'Ẩn bàn phím',
                onPressed: () => FocusScope.of(context).unfocus(),
              )
            : null);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction ??
          (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: effectiveSuffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Trường này không được để trống';
        }
        return null;
      },
    );
  }
}

class _KeyboardBottomPadding extends StatelessWidget {
  final Widget child;

  const _KeyboardBottomPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

class _TechnicianMultiSelectBottomSheet extends StatefulWidget {
  final List<User> technicians;
  final Set<String> initialSelected;
  final bool isDark;

  const _TechnicianMultiSelectBottomSheet({
    required this.technicians,
    required this.initialSelected,
    required this.isDark,
  });

  @override
  State<_TechnicianMultiSelectBottomSheet> createState() =>
      _TechnicianMultiSelectBottomSheetState();
}

class _TechnicianMultiSelectBottomSheetState
    extends State<_TechnicianMultiSelectBottomSheet> {
  final Set<String> _selected = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> get _filteredTechnicians {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return widget.technicians;
    return widget.technicians.where((tech) {
      return tech.name.toLowerCase().contains(q) ||
          tech.employeeId.toLowerCase().contains(q) ||
          tech.role.label.toLowerCase().contains(q);
    }).toList();
  }

  void _toggleTechnician(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = _filteredTechnicians;
    final allFilteredSelected =
        filtered.isNotEmpty &&
        filtered.every((tech) => _selected.contains(tech.id));
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return _KeyboardBottomPadding(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModalTopBar(
                  title: 'Chọn kỹ thuật viên',
                  trailing: Container(
                    key: const ValueKey('technician-picker-selected-count'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Đã chọn (${_selected.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // ── Thanh tìm kiếm & Nút Chọn tất cả / Bỏ chọn tất cả ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('technician-picker-search-field'),
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên hoặc mã nhân viên...',
                          prefixIcon: const Icon(Icons.search, size: 19),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 17),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                        ),
                      ),
                      if (filtered.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Danh sách kỹ thuật viên (${filtered.length})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              key: const ValueKey(
                                'technician-picker-toggle-all',
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (allFilteredSelected) {
                                    for (final tech in filtered) {
                                      _selected.remove(tech.id);
                                    }
                                  } else {
                                    for (final tech in filtered) {
                                      _selected.add(tech.id);
                                    }
                                  }
                                });
                              },
                              icon: Icon(
                                allFilteredSelected
                                    ? Icons.deselect_outlined
                                    : Icons.select_all_rounded,
                                size: 16,
                              ),
                              label: Text(
                                allFilteredSelected
                                    ? 'Bỏ chọn tất cả'
                                    : 'Chọn tất cả',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Danh sách nhân viên: Avatar chữ cái đầu + chạm toàn bộ hàng ──
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 36,
                                color: secondaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.technicians.isEmpty
                                    ? 'Không có kỹ thuật viên khả dụng.'
                                    : 'Không tìm thấy nhân viên phù hợp.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tech = filtered[index];
                            final isChecked = _selected.contains(tech.id);
                            final subtitle = tech.employeeId.isNotEmpty
                                ? '${tech.employeeId} • ${tech.role.label}'
                                : tech.role.label;

                            return InkWell(
                              key: ValueKey('technician-picker-row-${tech.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _toggleTechnician(tech.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? AppColors.primary.withValues(
                                          alpha: isDark ? 0.16 : 0.07,
                                        )
                                      : (isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isChecked
                                        ? AppColors.primary
                                        : (isDark
                                              ? AppColors.borderDark
                                              : AppColors.borderLight),
                                    width: isChecked ? 1.4 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 19,
                                      backgroundColor: isChecked
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(
                                              alpha: 0.14,
                                            ),
                                      child: Text(
                                        _givenNameInitial(tech.name),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isChecked
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tech.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: isChecked,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      onChanged: (_) =>
                                          _toggleTechnician(tech.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // ── Sticky Footer: Hủy & Xác nhận ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          key: const ValueKey(
                            'technician-picker-confirm-button',
                          ),
                          onPressed: () => Navigator.pop(context, _selected),
                          child: Text('Chọn (${_selected.length})'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helper: State cho một thiết bị trong form ─────────────────────────────

class _DeviceFormEntry {
  final String id = UniqueKey().toString();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  bool underWarranty = false;
  DateTime? warrantyExpiry;
  DateTime? warrantyStartDate;
  String? assignedToId;
  String? assignedToName;

  _DeviceFormEntry({String? initialName}) {
    if (initialName != null) nameController.text = initialName;
  }

  void dispose() {
    nameController.dispose();
    serialController.dispose();
    descController.dispose();
  }
}

// ─── Widget: Card form cho một thiết bị ────────────────────────────────────

class _DeviceFormCard extends StatefulWidget {
  final int index;
  final _DeviceFormEntry entry;
  final bool isDark;
  final bool canAssign;
  final List<User> technicians;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final DateTime? orderCreatedAt;

  const _DeviceFormCard({
    super.key,
    required this.index,
    required this.entry,
    required this.isDark,
    required this.canAssign,
    required this.technicians,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.orderCreatedAt,
  });

  @override
  State<_DeviceFormCard> createState() => _DeviceFormCardState();
}

class _DeviceFormCardState extends State<_DeviceFormCard> {
  DateTime _calculateExpiry(DateTime startDate, int months) {
    int targetYear = startDate.year;
    int targetMonth = startDate.month + months;

    final tempDate = DateTime(targetYear, targetMonth);
    final actualYear = tempDate.year;
    final actualMonth = tempDate.month;

    final lastDay = DateTime(actualYear, actualMonth + 1, 0).day;
    final day = startDate.day > lastDay ? lastDay : startDate.day;

    return DateTime(actualYear, actualMonth, day);
  }

  bool _isMatchingShortcut(DateTime? expiry, DateTime startDate, int months) {
    if (expiry == null) return false;
    final expected = _calculateExpiry(startDate, months);
    return expiry.year == expected.year &&
        expiry.month == expected.month &&
        expiry.day == expected.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final entry = widget.entry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tên thiết bị
        TextFormField(
          controller: entry.nameController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Tên thiết bị *',
            hintText: 'Biến tần Yaskawa, Delta...',
            prefixIcon: const Icon(Icons.devices_outlined, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 12),
        // Số seri
        TextFormField(
          controller: entry.serialController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Số seri',
            hintText: 'Nhập số seri (nếu có)',
            prefixIcon: const Icon(Icons.tag, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 12),
        // Tình trạng lỗi
        TextFormField(
          controller: entry.descController,
          maxLines: 2,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: 'Tình trạng lỗi',
            hintText: 'Mô tả lỗi thiết bị',
            alignLabelWithHint: true,
            prefixIcon: const Icon(Icons.error_outline, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 8),
        // Bảo hành switch
        SwitchListTile(
          title: const Text('Bảo hành', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            entry.underWarranty ? 'Có bảo hành' : 'Không bảo hành',
            style: const TextStyle(fontSize: 12),
          ),
          value: entry.underWarranty,
          onChanged: (v) {
            setState(() {
              entry.underWarranty = v;
              if (!v) {
                entry.warrantyExpiry = null;
              }
            });
            widget.onChanged();
          },
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
        if (entry.underWarranty) ...[
          const SizedBox(height: 8),
          // Chọn ngày bắt đầu bảo hành
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    entry.warrantyStartDate ??
                    widget.orderCreatedAt ??
                    DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: isDark ? ThemeData.dark() : ThemeData.light(),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  entry.warrantyStartDate = picked;
                });
                widget.onChanged();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.warrantyStartDate != null
                          ? 'Ngày bảo hành: ${DateFormat('dd/MM/yyyy').format(entry.warrantyStartDate!)}'
                          : 'Ngày bảo hành: Ngày tạo đơn (${DateFormat('dd/MM/yyyy').format(widget.orderCreatedAt ?? DateTime.now())})',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (entry.warrantyStartDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          entry.warrantyStartDate = null;
                        });
                        widget.onChanged();
                      },
                      child: const Icon(
                        Icons.clear,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Nút chọn hạn
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.av_timer, size: 16),
                  label: const Text(
                    'Hạn 6 tháng',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color:
                          _isMatchingShortcut(
                            entry.warrantyExpiry,
                            entry.warrantyStartDate ??
                                widget.orderCreatedAt ??
                                DateTime.now(),
                            6,
                          )
                          ? AppColors.primary
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    foregroundColor:
                        _isMatchingShortcut(
                          entry.warrantyExpiry,
                          entry.warrantyStartDate ??
                              widget.orderCreatedAt ??
                              DateTime.now(),
                          6,
                        )
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : Colors.black87),
                    backgroundColor:
                        _isMatchingShortcut(
                          entry.warrantyExpiry,
                          entry.warrantyStartDate ??
                              widget.orderCreatedAt ??
                              DateTime.now(),
                          6,
                        )
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  onPressed: () {
                    setState(() {
                      entry.warrantyExpiry = _calculateExpiry(
                        entry.warrantyStartDate ??
                            widget.orderCreatedAt ??
                            DateTime.now(),
                        6,
                      );
                    });
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text(
                    'Hạn 12 tháng',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color:
                          _isMatchingShortcut(
                            entry.warrantyExpiry,
                            entry.warrantyStartDate ??
                                widget.orderCreatedAt ??
                                DateTime.now(),
                            12,
                          )
                          ? AppColors.primary
                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    foregroundColor:
                        _isMatchingShortcut(
                          entry.warrantyExpiry,
                          entry.warrantyStartDate ??
                              widget.orderCreatedAt ??
                              DateTime.now(),
                          12,
                        )
                        ? AppColors.primary
                        : (isDark ? Colors.white70 : Colors.black87),
                    backgroundColor:
                        _isMatchingShortcut(
                          entry.warrantyExpiry,
                          entry.warrantyStartDate ??
                              widget.orderCreatedAt ??
                              DateTime.now(),
                          12,
                        )
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  onPressed: () {
                    setState(() {
                      entry.warrantyExpiry = _calculateExpiry(
                        entry.warrantyStartDate ??
                            widget.orderCreatedAt ??
                            DateTime.now(),
                        12,
                      );
                    });
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          if (entry.warrantyExpiry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: !_isWarrantyValid(entry.warrantyExpiry)
                      ? AppColors.error
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: !_isWarrantyValid(entry.warrantyExpiry)
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Hạn bảo hành: ${DateFormat('dd/MM/yyyy').format(entry.warrantyExpiry!)}',
                          style: TextStyle(
                            color: !_isWarrantyValid(entry.warrantyExpiry)
                                ? AppColors.error
                                : (isDark ? Colors.white : Colors.black87),
                            fontSize: 14,
                            fontWeight: !_isWarrantyValid(entry.warrantyExpiry)
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (!_isWarrantyValid(entry.warrantyExpiry)) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(Hết hạn)',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        entry.warrantyExpiry = null;
                      });
                      widget.onChanged();
                    },
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
