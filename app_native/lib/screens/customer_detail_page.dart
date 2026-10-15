import '../widgets/permission_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_permission.dart';
import '../models/customer.dart';
import '../models/repair_order.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/navigation/app_back_button.dart';
import '../widgets/status_badge.dart';
import 'customer_form_sheet.dart';
import 'customer_order_link_dialog.dart';
import 'repair_orders_page.dart';

class CustomerDetailPage extends StatefulWidget {
  final Customer customer;

  const CustomerDetailPage({super.key, required this.customer});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Customer _customer;
  List<RepairOrder> _orders = [];
  bool _isLoadingOrders = false;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!context.read<AuthProvider>().can(AppPermission.viewCustomerOrders)) {
      return;
    }
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });

    try {
      final backend = context.read<BackendDataProvider>();
      final orders = await backend.getRepairOrdersByCustomer(_customer.id);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ordersError = e.toString();
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _refreshCustomer() async {
    try {
      final backend = context.read<BackendDataProvider>();
      final updated = await backend.getCustomer(_customer.id);
      if (!mounted) return;
      setState(() => _customer = updated);
    } catch (_) {}
    await _loadOrders();
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: clean));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã sao chép số điện thoại vào bộ nhớ tạm'),
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: email));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã sao chép địa chỉ email vào bộ nhớ tạm'),
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus() async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(AppPermission.updateCustomerStatus)) return;

    final targetActive = !_customer.active;
    final actionText = targetActive ? 'kích hoạt lại' : 'ngừng hoạt động';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text('Xác nhận $actionText'),
        content: Text(
          targetActive
              ? 'Khách hàng này sẽ được kích hoạt lại và có thể chọn khi tạo/liên kết đơn hàng mới.'
              : 'Khách hàng bị ngừng hoạt động sẽ không thể chọn khi tạo đơn hàng mới. Các đơn hàng cũ vẫn giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetActive
                  ? AppColors.success
                  : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(targetActive ? 'Kích hoạt' : 'Ngừng hoạt động'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final backend = context.read<BackendDataProvider>();
      final updated = await backend.updateCustomerStatus(
        _customer.id,
        targetActive,
      );
      if (!mounted) return;
      setState(() => _customer = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetActive
                ? 'Đã kích hoạt lại khách hàng!'
                : 'Đã ngừng hoạt động khách hàng!',
          ),
          backgroundColor: targetActive ? AppColors.success : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _editCustomer() async {
    final updated = await showCustomerFormSheet(context, customer: _customer);
    if (updated != null && mounted) {
      setState(() => _customer = updated);
    }
  }

  Future<void> _linkExistingOrder() async {
    if (!context.read<AuthProvider>().can(AppPermission.manageCustomers) ||
        !_customer.active) {
      return;
    }
    final backend = context.read<BackendDataProvider>();
    final linked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CustomerOrderLinkDialog(customer: _customer, backend: backend),
    );
    if (linked != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã gán đơn và cập nhật tên khách hàng trên đơn'),
      ),
    );
    await _loadOrders();
    await backend.loadRepairOrders();
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    bool isDark = false,
    Widget? trailing,
    bool copyable = false,
  }) {
    final displayVal = (value != null && value.trim().isNotEmpty)
        ? value
        : 'Chưa có thông tin';
    final hasVal = value != null && value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayVal,
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasVal ? FontWeight.w500 : FontWeight.normal,
                color: hasVal
                    ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                    : (isDark ? Colors.white38 : AppColors.textTertiaryLight),
              ),
            ),
          ),
          if (copyable && hasVal)
            InkWell(
              onTap: () => _copyToClipboard(value, 'Đã sao chép $label'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  LucideIcons.copy,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final canManage = auth.can(AppPermission.manageCustomers);
    final isCompany = _customer.isCompany;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Hồ sơ khách hàng'),
        actions: [
          if (canManage)
            PermissionGate(
              permission: AppPermission.updateCustomers,
              child: IconButton(
                icon: const Icon(LucideIcons.pencil, size: 20),
                tooltip: 'Chỉnh sửa',
                onPressed: _editCustomer,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCustomer,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isCompany
                          ? const Color(0xFF8B5CF6)
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Icon(
                        isCompany ? LucideIcons.building2 : LucideIcons.user,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _customer.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _copyToClipboard(
                        _customer.customerCode,
                        'Đã sao chép mã khách hàng',
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                              ? Colors.black26
                              : Colors.white.withValues(alpha: 0.8)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _customer.customerCode,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              LucideIcons.copy,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCompany
                                ? const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _customer.typeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompany
                                  ? const Color(0xFF8B5CF6)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _customer.active
                                ? AppColors.success.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _customer.active
                                      ? AppColors.success
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _customer.active
                                    ? 'Đang hoạt động'
                                    : 'Ngừng hoạt động',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _customer.active
                                      ? AppColors.success
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Contact & Detailed Info Card
              _buildCard(
                isDark: isDark,
                title: 'Thông tin liên hệ & Pháp lý',
                icon: LucideIcons.contact,
                children: [
                  _buildInfoRow(
                    'Số điện thoại',
                    _customer.phone,
                    isDark: isDark,
                    copyable: true,
                    trailing:
                        (_customer.phone != null && _customer.phone!.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: IconButton(
                              icon: const Icon(
                                LucideIcons.phoneCall,
                                size: 16,
                                color: AppColors.success,
                              ),
                              tooltip: 'Gọi điện',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _callPhone(_customer.phone!),
                            ),
                          )
                        : null,
                  ),
                  _buildInfoRow(
                    'Email',
                    _customer.email,
                    isDark: isDark,
                    copyable: true,
                    trailing:
                        (_customer.email != null && _customer.email!.isNotEmpty)
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: IconButton(
                              icon: const Icon(
                                LucideIcons.mail,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Gửi email',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _sendEmail(_customer.email!),
                            ),
                          )
                        : null,
                  ),
                  if (_customer.taxCode != null &&
                      _customer.taxCode!.isNotEmpty)
                    _buildInfoRow(
                      'Mã số thuế',
                      _customer.taxCode,
                      isDark: isDark,
                      copyable: true,
                    ),
                  _buildInfoRow(
                    'Địa chỉ',
                    _customer.address,
                    isDark: isDark,
                    copyable: true,
                  ),
                  if (_customer.notes != null && _customer.notes!.isNotEmpty)
                    _buildInfoRow('Ghi chú', _customer.notes, isDark: isDark),
                  if (_customer.createdAt != null)
                    _buildInfoRow(
                      'Ngày tạo',
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(_customer.createdAt!),
                      isDark: isDark,
                    ),
                  if (_customer.updatedAt != null)
                    _buildInfoRow(
                      'Cập nhật cuối',
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(_customer.updatedAt!),
                      isDark: isDark,
                    ),
                ],
              ),

              // Management actions card
              if (canManage)
                _buildCard(
                  isDark: isDark,
                  title: 'Thao tác quản trị',
                  icon: LucideIcons.settings,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PermissionGate(
                            permission: AppPermission.updateCustomers,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(LucideIcons.pencil, size: 16),
                              label: const Text('Sửa thông tin'),
                              onPressed: _editCustomer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PermissionGate(
                            permission: AppPermission.updateCustomerStatus,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _customer.active
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                foregroundColor: _customer.active
                                    ? AppColors.error
                                    : AppColors.success,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: _customer.active
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                              icon: Icon(
                                _customer.active
                                    ? LucideIcons.userX
                                    : LucideIcons.userCheck,
                                size: 16,
                              ),
                              label: Text(
                                _customer.active
                                    ? 'Ngừng hoạt động'
                                    : 'Kích hoạt lại',
                              ),
                              onPressed: _toggleStatus,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              if (auth.canAny([
                    AppPermission.assignOrderCustomer,
                    AppPermission.transferOrderCustomer,
                  ]) &&
                  _customer.active)
                TextButton.icon(
                  onPressed: _linkExistingOrder,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Gán đơn đã có'),
                ),

              // Linked Repair Orders Section
              PermissionGate(
                permission: AppPermission.viewCustomerOrders,
                child: _buildCard(
                  isDark: isDark,
                  title: 'Lịch sử đơn sửa chữa (${_orders.length})',
                  icon: LucideIcons.wrench,
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    tooltip: 'Tải lại đơn',
                    onPressed: _loadOrders,
                  ),
                  children: [
                    if (_isLoadingOrders)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else if (_ordersError != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Lỗi tải đơn hàng: $_ordersError',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadOrders,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    else if (_orders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.clipboardList,
                                size: 36,
                                color: isDark
                                    ? Colors.white30
                                    : AppColors.textTertiaryLight,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Khách hàng này chưa có đơn sửa chữa nào',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _orders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final dateStr = DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(order.createdAt);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.wrench,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    order.orderNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                StatusBadge(status: order.status),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.deviceName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (dateStr.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : AppColors.textTertiaryLight,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            onTap: () {
                              showRepairOrderDetails(context, order.id);
                            },
                          );
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
  }
}
