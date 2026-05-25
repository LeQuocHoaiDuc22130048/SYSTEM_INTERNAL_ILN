import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/repair_order.dart';
import '../theme/app_colors.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/status_badge.dart';

class RepairOrdersPage extends StatefulWidget {
  final String? targetOrderId;
  const RepairOrdersPage({super.key, this.targetOrderId});

  @override
  State<RepairOrdersPage> createState() => _RepairOrdersPageState();
}

class _RepairOrdersPageState extends State<RepairOrdersPage> {
  final ValueNotifier<RepairOrderStatus?> _filter = ValueNotifier(null);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BackendDataProvider>().loadRepairOrders();
      if (widget.targetOrderId != null) {
        _showOrderById(widget.targetOrderId!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RepairOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != null && widget.targetOrderId != oldWidget.targetOrderId) {
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
    }
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    _filter.dispose();
    super.dispose();
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
    final query = _searchQuery.value.toLowerCase();
    final currentFilter = _filter.value;
    final orders = context.read<BackendDataProvider>().repairOrders;
    return orders.where((order) {
      final matchesFilter = currentFilter == null || order.status == currentFilter;
      final matchesSearch =
          query.isEmpty ||
          order.deviceName.toLowerCase().contains(query) ||
          order.orderNumber.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          (order.assignedToName ?? '').toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final orders = backend.repairOrders;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Column(
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
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${orders.length} đơn tổng cộng',
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
                              ElevatedButton.icon(
                                onPressed: () => _showCreateOrderSheet(context),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tạo đơn'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (value) =>
                                      _searchQuery.value = value,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tìm theo mã đơn, thiết bị, khách hàng...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.surfaceDark
                                        : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceDark : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(LucideIcons.listFilter, size: 20),
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                        _buildFilterChip('Tất cả', null),
                                        _buildFilterChip(
                                          'Chờ xử lý',
                                          RepairOrderStatus.pending,
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
                                      ]
                                      .map(
                                        (child) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: child,
                                        ),
                                      )
                                      .toList(),
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
                          onRetry: () => context
                              .read<BackendDataProvider>()
                              .loadRepairOrders(),
                          isDark: isDark,
                        )
                      : AnimatedBuilder(
                    animation: Listenable.merge([_searchQuery, _filter]),
                    builder: (context, _) {
                      final filtered = _filteredOrders;
                      if (filtered.isEmpty) {
                        return _EmptyOrders(isDark: isDark);
                      }
                      return ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            wide ? 20 : 22,
                            4,
                            wide ? 20 : 22,
                            24,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 980,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child:
                                      _OrderCard(
                                            order: filtered[index],
                                            isDark: isDark,
                                          )
                                          .animate(target: 1)
                                          .fadeIn(
                                            duration: 320.ms,
                                            delay: (index * 45).ms,
                                          )
                                          .slideY(
                                            begin: 0.08,
                                            end: 0,
                                            duration: 320.ms,
                                            delay: (index * 45).ms,
                                          ),
                                ),
                              ),
                            );
                          },
                        );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RepairOrderStatus? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orders = context.watch<BackendDataProvider>().repairOrders;
    final count = status == null
        ? orders.length
        : orders.where((order) => order.status == status).length;

    return ValueListenableBuilder<RepairOrderStatus?>(
      valueListenable: _filter,
      builder: (context, currentFilter, _) {
        final isSelected = currentFilter == status;
        return FilterChip(
          label: Text('$label  $count'),
          selected: isSelected,
          onSelected: (selected) => _filter.value = selected ? status : null,
          backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
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
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RepairOrder order;
  final bool isDark;

  const _OrderCard({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showOrderDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.wrench,
                    size: 19,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                StatusBadge(status: order.status, size: 'sm'),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 560;
                final children = [
                  _InfoLine(
                    icon: Icons.person_outline,
                    label: 'Khách hàng',
                    value: order.customerName,
                    isDark: isDark,
                  ),
                  _InfoLine(
                    icon: Icons.phone_outlined,
                    label: 'SĐT khách',
                    value: order.customerPhone ?? 'Chưa có',
                    isDark: isDark,
                  ),
                  _InfoLine(
                    icon: Icons.engineering_outlined,
                    label: 'Người sửa',
                    value: order.assignedToName ?? 'Chưa phân công',
                    isDark: isDark,
                  ),
                  _InfoLine(
                    icon: Icons.schedule,
                    label: 'Tiếp nhận',
                    value: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(order.createdAt),
                    isDark: isDark,
                  ),
                ];

                if (!twoColumns) {
                  return Column(children: children);
                }

                return Wrap(
                  runSpacing: 10,
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: constraints.maxWidth / 2,
                          child: child,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            if (order.description != null) ...[
              const SizedBox(height: 12),
              Text(
                order.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                children: [
                  TextSpan(text: '$label: '),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final RepairOrder order;

  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.wrench,
                      size: 24,
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
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
              const SizedBox(height: 22),
              _DetailRow('Khách hàng', order.customerName),
              _DetailRow('SĐT khách', order.customerPhone ?? 'Chưa có'),
              _DetailRow('Người sửa', order.assignedToName ?? 'Chưa phân công'),
              _DetailRow(
                'Ngày tạo',
                DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
              ),
              if (order.updatedAt != null)
                _DetailRow(
                  'Cập nhật',
                  DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt!),
                ),
              if (order.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Mô tả',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Chỉnh sửa'),
                    ),
                  ),
                ],
              ),
            ],
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
        children: [
          Expanded(
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
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

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet();

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _KeyboardBottomPadding(
      child: Container(
        decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tạo đơn sửa chữa mới',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  context,
                  label: 'Tên khách hàng',
                  hint: 'Nhập tên khách hàng',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  label: 'Số điện thoại',
                  hint: '0901 234 567',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  label: 'Tên thiết bị',
                  hint: 'iPhone 15 Pro Max, MacBook Pro...',
                  icon: Icons.smartphone_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  context,
                  label: 'Tình trạng lỗi',
                  hint: 'Mô tả chi tiết lỗi thiết bị',
                  icon: Icons.error_outline,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Đính kèm hình ảnh',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Chụp ảnh'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Thư viện'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isLoading = true);
                              await Future.delayed(
                                  const Duration(milliseconds: 1500));
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tạo đơn sửa chữa thành công!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Tạo đơn hàng'),
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

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
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
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Trường này không được để trống';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _KeyboardBottomPadding extends StatelessWidget {
  final Widget child;

  const _KeyboardBottomPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
