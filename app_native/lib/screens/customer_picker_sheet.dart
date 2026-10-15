import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_permission.dart';
import '../models/customer.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/modal_top_bar.dart';
import 'customer_form_sheet.dart';

Future<Customer?> showCustomerPickerSheet(
  BuildContext context, {
  String? initialQuery,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomerPickerSheet(initialQuery: initialQuery),
  );
}

class CustomerPickerSheet extends StatefulWidget {
  final String? initialQuery;

  const CustomerPickerSheet({super.key, this.initialQuery});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<Customer> _customers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchCtrl.text = widget.initialQuery!;
    }
    _fetchCustomers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchCustomers();
    });
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final backend = context.read<BackendDataProvider>();
      final page = await backend.searchCustomers(
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        active: true,
        page: 0,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _customers = page.content;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewCustomer() async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(AppPermission.manageCustomers)) return;

    final query = _searchCtrl.text.trim();
    final isPhone = RegExp(r'^[0-9+ ]+$').hasMatch(query);

    final created = await showCustomerFormSheet(
      context,
      initialName: isPhone ? null : (query.isNotEmpty ? query : null),
      initialPhone: isPhone ? query : null,
    );

    if (created != null && mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final canManage = auth.can(AppPermission.manageCustomers);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            ModalTopBar(
              title: 'Chọn khách hàng',
              trailing: canManage
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: const Text(
                        'Tạo mới',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _createNewCustomer,
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, SĐT, mã KH...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : AppColors.textTertiaryLight,
                  ),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.primary),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _fetchCustomers();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Lỗi tải danh sách: $_error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: _fetchCustomers,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _customers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.userX,
                                      size: 48,
                                      color: isDark ? Colors.white38 : AppColors.textTertiaryLight,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Không tìm thấy khách hàng nào',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    if (canManage) ...[
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(LucideIcons.plus, size: 16),
                                        label: const Text('Thêm khách hàng mới'),
                                        onPressed: _createNewCustomer,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _customers.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final customer = _customers[index];
                                final isCompany = customer.isCompany;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isCompany
                                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(alpha: 0.15),
                                    foregroundColor: isCompany ? const Color(0xFF8B5CF6) : AppColors.primary,
                                    child: Icon(
                                      isCompany ? LucideIcons.building2 : LucideIcons.user,
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          customer.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCompany
                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                              : AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          customer.typeLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isCompany ? const Color(0xFF8B5CF6) : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                                          const Icon(LucideIcons.phone, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            customer.phone!,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        Text(
                                          customer.customerCode,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: isDark ? Colors.white38 : AppColors.textTertiaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(context, customer),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
