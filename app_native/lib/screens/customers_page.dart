import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_permission.dart';
import '../models/customer.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import 'customer_detail_page.dart';
import 'customer_form_sheet.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  List<Customer> _customers = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;

  bool? _statusFilter; // null: all, true: active, false: inactive
  CustomerType? _typeFilter; // null: all, individual, company

  @override
  void initState() {
    super.initState();
    _fetchCustomers(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage + 1 < _totalPages) {
        _loadMore();
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchCustomers(reset: true);
    });
  }

  Future<void> _fetchCustomers({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
      });
    }

    try {
      final backend = context.read<BackendDataProvider>();
      final page = await backend.searchCustomers(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        type: _typeFilter,
        active: _statusFilter,
        page: reset ? 0 : _currentPage,
        size: 20,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _customers = page.content;
        } else {
          _customers.addAll(page.content);
        }
        _currentPage = page.number;
        _totalPages = page.totalPages;
        _totalElements = page.totalElements;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final backend = context.read<BackendDataProvider>();
      final nextPage = _currentPage + 1;
      final page = await backend.searchCustomers(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        type: _typeFilter,
        active: _statusFilter,
        page: nextPage,
        size: 20,
      );

      if (!mounted) return;
      setState(() {
        _customers.addAll(page.content);
        _currentPage = page.number;
        _totalPages = page.totalPages;
        _totalElements = page.totalElements;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openCreateCustomer() async {
    final created = await showCustomerFormSheet(context);
    if (created != null && mounted) {
      _fetchCustomers(reset: true);
    }
  }

  void _openCustomerDetail(Customer customer) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CustomerDetailPage(customer: customer),
          ),
        )
        .then((_) {
          if (mounted) {
            _fetchCustomers(reset: true);
          }
        });
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final canManage = auth.can(AppPermission.createCustomers);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Khách hàng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Tổng cộng $_totalElements khách hàng',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(LucideIcons.userPlus, size: 20),
              tooltip: 'Thêm khách hàng',
              onPressed: _openCreateCustomer,
            ),
        ],
      ),
      floatingActionButton: canManage && _customers.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text(
                'Thêm khách hàng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _openCreateCustomer,
            )
          : null,
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, SĐT, mã KH...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white38
                          : AppColors.textTertiaryLight,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _fetchCustomers(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filters
                      FilterChip(
                        label: const Text('Tất cả trạng thái'),
                        selected: _statusFilter == null,
                        onSelected: (_) {
                          setState(() => _statusFilter = null);
                          _fetchCustomers(reset: true);
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Đang hoạt động'),
                        selected: _statusFilter == true,
                        onSelected: (_) {
                          setState(() => _statusFilter = true);
                          _fetchCustomers(reset: true);
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Ngừng hoạt động'),
                        selected: _statusFilter == false,
                        onSelected: (_) {
                          setState(() => _statusFilter = false);
                          _fetchCustomers(reset: true);
                        },
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 20,
                        width: 1,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(width: 12),

                      // Type filters
                      FilterChip(
                        label: const Text('Tất cả loại'),
                        selected: _typeFilter == null,
                        onSelected: (_) {
                          setState(() => _typeFilter = null);
                          _fetchCustomers(reset: true);
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Cá nhân'),
                        selected: _typeFilter == CustomerType.individual,
                        onSelected: (_) {
                          setState(() => _typeFilter = CustomerType.individual);
                          _fetchCustomers(reset: true);
                        },
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: const Text('Doanh nghiệp'),
                        selected: _typeFilter == CustomerType.company,
                        onSelected: (_) {
                          setState(() => _typeFilter = CustomerType.company);
                          _fetchCustomers(reset: true);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchCustomers(reset: true),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.alertCircle,
                              size: 42,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Lỗi tải dữ liệu: $_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _fetchCustomers(reset: true),
                              icon: const Icon(LucideIcons.refreshCw, size: 16),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _customers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.users,
                              size: 54,
                              color: isDark
                                  ? Colors.white30
                                  : AppColors.textTertiaryLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có khách hàng nào phù hợp',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thử thay đổi bộ lọc tìm kiếm hoặc tạo hồ sơ khách hàng mới.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white38
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('Thêm khách hàng'),
                                onPressed: _openCreateCustomer,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _customers.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final customer = _customers[index];
                        final isCompany = customer.isCompany;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openCustomerDetail(customer),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isCompany
                                            ? const Color(
                                                0xFF8B5CF6,
                                              ).withValues(alpha: 0.15)
                                            : AppColors.primary.withValues(
                                                alpha: 0.15,
                                              ),
                                        foregroundColor: isCompany
                                            ? const Color(0xFF8B5CF6)
                                            : AppColors.primary,
                                        child: Icon(
                                          isCompany
                                              ? LucideIcons.building2
                                              : LucideIcons.user,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.textPrimaryDark
                                                    : AppColors
                                                          .textPrimaryLight,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            InkWell(
                                              onTap: () => _copyToClipboard(
                                                customer.customerCode,
                                                'Đã sao chép mã KH',
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      customer.customerCode,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontFamily: 'monospace',
                                                        color: isDark
                                                            ? Colors.white54
                                                            : AppColors
                                                                  .textSecondaryLight,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    LucideIcons.copy,
                                                    size: 11,
                                                    color: isDark
                                                        ? Colors.white38
                                                        : Colors.grey,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: customer.active
                                              ? AppColors.success.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.2,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          customer.active
                                              ? 'Hoạt động'
                                              : 'Ngừng',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: customer.active
                                                ? AppColors.success
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCompany
                                              ? const Color(
                                                  0xFF8B5CF6,
                                                ).withValues(alpha: 0.1)
                                              : AppColors.primary.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          customer.typeLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isCompany
                                                ? const Color(0xFF8B5CF6)
                                                : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (customer.phone != null &&
                                          customer.phone!.isNotEmpty) ...[
                                        const Icon(
                                          LucideIcons.phone,
                                          size: 13,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          customer.phone!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      if (customer.email != null &&
                                          customer.email!.isNotEmpty) ...[
                                        const Icon(
                                          LucideIcons.mail,
                                          size: 13,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            customer.email!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white70
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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
    );
  }
}
