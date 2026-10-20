import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';

class CustomerPortalMobilePage extends StatefulWidget {
  const CustomerPortalMobilePage({
    super.key,
    required this.onLogout,
  });

  final Future<void> Function() onLogout;

  @override
  State<CustomerPortalMobilePage> createState() => _CustomerPortalMobilePageState();
}

class _CustomerPortalMobilePageState extends State<CustomerPortalMobilePage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  // Filter & Search states
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'IN_PROGRESS', 'COMPLETED'
  final TextEditingController _searchController = TextEditingController();

  static const String defaultHotlinePhone = '0909000000'; // Hotline CSKH tiếp nhận mặc định
  static const String defaultZaloOaUrl = 'https://zalo.me'; // Zalo OA hỗ trợ kỹ thuật mặc định

  String _hotlineNumber = defaultHotlinePhone;
  String _hotlineLabel = 'Hotline Kỹ Thuật';
  String _zaloUrl = defaultZaloOaUrl;
  String _zaloLabel = 'Chat Zalo Tiếp Nhận';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchSupportConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/orders');
      if (!mounted) return;

      if (res is Map<String, dynamic> && res['content'] is List) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(res['content'] as List);
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải danh sách đơn hàng. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSupportConfig() async {
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/support-info');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          final hNum = res['hotlineNumber']?.toString().trim();
          if (hNum != null && hNum.isNotEmpty) {
            _hotlineNumber = hNum;
          }
          final hLbl = res['hotlineLabel']?.toString().trim();
          if (hLbl != null && hLbl.isNotEmpty) {
            _hotlineLabel = hLbl;
          }
          final zUrl = res['zaloUrl']?.toString().trim();
          if (zUrl != null && zUrl.isNotEmpty) {
            _zaloUrl = zUrl;
          }
          final zLbl = res['zaloLabel']?.toString().trim();
          if (zLbl != null && zLbl.isNotEmpty) {
            _zaloLabel = zLbl;
          }
        });
      }
    } catch (_) {
      // Giữ giá trị mặc định an toàn nếu offline hoặc lỗi mạng
    }
  }

  // Phone Call Launcher
  Future<void> _makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[\s().-]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể thực hiện cuộc gọi tới $phoneNumber')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi kết nối cuộc gọi tới $phoneNumber')),
        );
      }
    }
  }

  // Zalo Support Launcher
  Future<void> _openZaloSupport() async {
    final targetUrl = _zaloUrl.isNotEmpty ? _zaloUrl : defaultZaloOaUrl;
    final uri = Uri.parse(targetUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết Zalo Hỗ trợ')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối tới ứng dụng Zalo')),
        );
      }
    }
  }

  // Filtered orders getter
  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((ord) {
      final code = (ord['orderCode'] ?? '').toString().toLowerCase();
      final title = (ord['orderTitle'] ?? '').toString().toLowerCase();
      final status = (ord['status'] ?? '').toString().toUpperCase();
      final q = _searchQuery.trim().toLowerCase();

      if (q.isNotEmpty && !code.contains(q) && !title.contains(q)) {
        return false;
      }

      if (_selectedFilter == 'IN_PROGRESS') {
        return status == 'PENDING' ||
            status == 'WAITING_FOR_CHECK' ||
            status == 'CHECKING' ||
            status == 'CHECKED' ||
            status == 'IN_PROGRESS';
      } else if (_selectedFilter == 'COMPLETED') {
        return status == 'COMPLETED' || status == 'DELIVERED';
      }
      return true;
    }).toList();
  }

  int get _inProgressCount => _orders.where((o) {
        final s = (o['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' ||
            s == 'WAITING_FOR_CHECK' ||
            s == 'CHECKING' ||
            s == 'CHECKED' ||
            s == 'IN_PROGRESS';
      }).length;

  int get _completedCount => _orders.where((o) {
        final s = (o['status'] ?? '').toString().toUpperCase();
        return s == 'COMPLETED' || s == 'DELIVERED';
      }).length;

  // Extract initials for business avatar
  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'KH';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text('Đăng xuất tài khoản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi Cổng Khách Hàng theo dõi sửa chữa thiết bị?',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.onLogout();
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool showPassword = false;
    bool isSubmitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(LucideIcons.keyRound, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Đổi mật khẩu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(dialogError!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: currentPwdController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPwdController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới *',
                    helperText: 'Tối thiểu 8 ký tự, gồm chữ hoa, thường & số',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPwdController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: showPassword,
                      onChanged: (val) => setDialogState(() => showPassword = val ?? false),
                    ),
                    const Text('Hiện mật khẩu', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final currentPwd = currentPwdController.text;
                      final newPwd = newPwdController.text;
                      final confirmPwd = confirmPwdController.text;

                      if (currentPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
                        setDialogState(() => dialogError = 'Vui lòng nhập đầy đủ các trường.');
                        return;
                      }
                      if (newPwd.length < 8) {
                        setDialogState(() => dialogError = 'Mật khẩu mới tối thiểu 8 ký tự.');
                        return;
                      }
                      if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(newPwd)) {
                        setDialogState(() => dialogError = 'Mật khẩu phải gồm chữ hoa, chữ thường và chữ số.');
                        return;
                      }
                      if (newPwd != confirmPwd) {
                        setDialogState(() => dialogError = 'Xác nhận mật khẩu mới không khớp.');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      final api = context.read<AuthProvider>().api;
                      try {
                        await api.post(
                          '/api/v1/customer/change-password',
                          body: {
                            'currentPassword': currentPwd,
                            'newPassword': newPwd,
                            'confirmPassword': confirmPwd,
                          },
                        );
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đổi mật khẩu thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = e.message;
                        });
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = 'Không thể đổi mật khẩu. Vui lòng thử lại.';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOrderDetail(String orderId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderDetailSheet(orderId: orderId),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return Colors.indigo;
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'COMPLETED':
        return Colors.green;
      case 'DELIVERED':
        return Colors.blueGrey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return LucideIcons.clock;
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return LucideIcons.search;
      case 'IN_PROGRESS':
        return LucideIcons.wrench;
      case 'COMPLETED':
        return LucideIcons.checkCheck;
      case 'DELIVERED':
        return LucideIcons.truck;
      case 'CANCELLED':
        return LucideIcons.xCircle;
      default:
        return LucideIcons.activity;
    }
  }

  int _getTimelineStep(String status) {
    switch (status) {
      case 'PENDING':
        return 0; // Tiếp nhận
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return 1; // Kiểm tra
      case 'IN_PROGRESS':
        return 2; // Đang sửa
      case 'COMPLETED':
      case 'DELIVERED':
        return 3; // Hoàn tất
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final companyName = user?.name ?? 'Khách hàng';
    final initials = _getInitials(companyName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.cpu, color: Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CỔNG KHÁCH HÀNG',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Theo dõi tiến độ sửa chữa thiết bị',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Elegant user menu button
          PopupMenuButton<String>(
            tooltip: 'Tài khoản & Cài đặt',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(LucideIcons.userRound, size: 20, color: Color(0xFF334155)),
            ),
            onSelected: (value) {
              if (value == 'change_pwd') {
                _showChangePasswordDialog(context);
              } else if (value == 'logout') {
                _confirmLogout(context);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(user?.username ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Divider(),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'change_pwd',
                child: Row(
                  children: [
                    Icon(LucideIcons.keyRound, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Text('Đổi mật khẩu', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(LucideIcons.logOut, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Đăng xuất', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchOrders(),
            _fetchSupportConfig(),
          ]);
        },
        color: const Color(0xFF2563EB),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // 1. VIP MEMBERSHIP CARD (Gradient Enterprise Card)
            _buildVipMembershipCard(companyName, initials, user?.username),
            const SizedBox(height: 18),

            // 2. SEARCH BAR & QUICK FILTERS
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilterTabs(),
            const SizedBox(height: 16),

            // 3. SECTION HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Đơn hàng sửa chữa',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filteredOrders.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  onPressed: _fetchOrders,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Làm mới', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4. ORDER LIST / EMPTY STATE / LOADING
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else if (_error != null)
              _buildErrorCard()
            else if (_filteredOrders.isEmpty)
              _buildEmptyState()
            else
              ..._filteredOrders.map(_buildOrderCard),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // VIP Enterprise Membership Card
  Widget _buildVipMembershipCard(String companyName, String initials, String? username) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Dark Slate
            Color(0xFF1E3A8A), // Deep Navy
            Color(0xFF2563EB), // Royal Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient circle decoration
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Badge & Security Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 13, color: Color(0xFFFDE047)),
                          SizedBox(width: 5),
                          Text(
                            'ĐỐI TÁC DOANH NGHIỆP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tài khoản: ${username ?? ""}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Middle: Avatar + Company Name
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80), // Active green
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Cổng theo dõi trực tuyến 24/7',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                const SizedBox(height: 12),

                // Bottom: 1-Tap Quick Action Row (Hotline & Zalo)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _makePhoneCall(_hotlineNumber),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.phoneCall, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _hotlineLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _openZaloSupport,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.messageSquare, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _zaloLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  // Search Bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm mã đơn, tên máy hoặc serial...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // Quick Filter Tabs (Chips)
  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', 'Tất cả (${_orders.length})', LucideIcons.layers),
          const SizedBox(width: 8),
          _buildFilterChip('IN_PROGRESS', 'Đang xử lý ($_inProgressCount)', LucideIcons.wrench),
          const SizedBox(width: 8),
          _buildFilterChip('COMPLETED', 'Sẵn sàng nhận ($_completedCount)', LucideIcons.checkCircle),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String title, IconData icon) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Order Card
  Widget _buildOrderCard(Map<String, dynamic> ord) {
    final orderCode = ord['orderCode']?.toString() ?? '';
    final orderTitle = ord['orderTitle']?.toString() ?? 'Đơn sửa chữa';
    final status = ord['status']?.toString() ?? 'PENDING';
    final friendlyStatus = ord['friendlyStatus']?.toString() ?? status;
    final deviceCount = ord['deviceCount'] ?? 1;
    final receivedDate = ord['receivedDate']?.toString() ?? '';
    final expectedDate = ord['expectedDeliveryDate']?.toString();

    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final timelineStep = _getTimelineStep(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openOrderDetail(ord['id']?.toString() ?? ''),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Code & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.fileText, size: 13, color: Color(0xFF475569)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                orderCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                friendlyStatus,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Order Title
                Text(
                  orderTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Mini Progress Indicator (4-stage overview)
                _buildMiniProgressTimeline(timelineStep),
                const SizedBox(height: 14),

                // Metadata: Device count & Dates
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.cpu, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 5),
                          Text(
                            '$deviceCount thiết bị',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (receivedDate.isNotEmpty) ...[
                      const Icon(LucideIcons.calendar, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Nhận: ${receivedDate.split("T").first}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                if (expectedDate != null && expectedDate.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.clockAlert, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Dự kiến bàn giao: ${expectedDate.split("T").first}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(color: const Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 8),

                // Footer CTA: View detail
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        'Xem chi tiết tiến độ & ảnh nghiệm thu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight, size: 15, color: Color(0xFF2563EB)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mini progress timeline directly on card
  Widget _buildMiniProgressTimeline(int currentStep) {
    final stages = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'Hoàn tất'];
    return Row(
      children: List.generate(stages.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIdx = index ~/ 2;
          final isPast = stepIdx < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isPast ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
            ),
          );
        }
        final stepIdx = index ~/ 2;
        final isDone = stepIdx < currentStep;
        final isCurrent = stepIdx == currentStep;

        Color dotColor;
        if (isDone) {
          dotColor = const Color(0xFF22C55E); // Green completed
        } else if (isCurrent) {
          dotColor = const Color(0xFF2563EB); // Blue active
        } else {
          dotColor = const Color(0xFFCBD5E1); // Grey pending
        }

        return Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? const Color(0xFFBFDBFE) : Colors.transparent,
                  width: 3,
                ),
              ),
              child: isDone
                  ? const Center(child: Icon(LucideIcons.check, size: 8, color: Colors.white))
                  : null,
            ),
            const SizedBox(height: 3),
            Text(
              stages[stepIdx],
              style: TextStyle(
                fontSize: 9,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isCurrent
                    ? const Color(0xFF1E293B)
                    : (isDone ? const Color(0xFF15803D) : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Vibrant Empty State with actions
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
            ),
            child: const Icon(LucideIcons.packageOpen, size: 36, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có đơn sửa chữa nào',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Khi Quý khách gửi thiết bị tới trung tâm kỹ thuật, toàn bộ quy trình kiểm tra, tiến độ sửa chữa và hình ảnh nghiệm thu sẽ tự động hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _makePhoneCall(_hotlineNumber),
                  icon: const Icon(LucideIcons.phoneCall, size: 16),
                  label: const Text('Liên hệ gửi máy mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _fetchOrders,
                icon: const Icon(LucideIcons.refreshCw, size: 15),
                label: const Text('Làm mới', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Error Card
  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _fetchOrders,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Tải lại dữ liệu'),
            ),
          ),
        ],
      ),
    );
  }
}

// Order Detail Bottom Sheet
class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.orderId});
  final String orderId;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/orders/${widget.orderId}');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải chi tiết đơn hàng';
        _loading = false;
      });
    }
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return 1;
      case 'IN_PROGRESS':
        return 2;
      case 'COMPLETED':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 1;
    }
  }

  void _showFullImage(String imageUrl) {
    final api = context.read<AuthProvider>().api;
    final resolvedUrl = api.resolveUrl(imageUrl);
    final headers = api.mediaHeadersFor(resolvedUrl);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.network(
                resolvedUrl,
                headers: headers.isNotEmpty ? headers : null,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('Không thể tải hình ảnh', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.fileSpreadsheet, size: 18, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _detail?['orderCode']?.toString() ?? 'Chi tiết đơn hàng',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          // Title & Status
                          Text(
                            _detail?['orderTitle']?.toString() ?? '',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 18),

                          // 5-STAGE STEPPER
                          _buildStepper(_detail?['status']?.toString() ?? 'PENDING'),
                          const SizedBox(height: 24),

                          // DEVICES LIST
                          Row(
                            children: [
                              const Icon(LucideIcons.cpu, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Thiết bị bàn giao',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...?(_detail?['devices'] as List?)?.map((dev) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(LucideIcons.memoryStick, color: Color(0xFF2563EB), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dev['modelName']?.toString() ?? 'Thiết bị kỹ thuật',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Text('Serial: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  dev['serialNumber']?.toString() ?? 'Chưa rõ',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if ((dev['issueDescription'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Lỗi: ${dev["issueDescription"]}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 20),

                          // WORKSHOP UPDATES
                          Row(
                            children: [
                              const Icon(LucideIcons.gitCommitVertical, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Nhật ký tiến độ kỹ thuật',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if ((_detail?['updates'] as List?)?.isEmpty ?? true)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text('Chưa có ghi nhận tiến độ mới từ kỹ thuật viên.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else
                            ...?(_detail?['updates'] as List?)?.map((up) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF16A34A)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              up['content']?.toString() ?? up['message']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (up['publishedAt'] ?? up['createdAt'])?.toString().split("T").first ?? '',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),

                          const SizedBox(height: 20),

                          // ACCEPTANCE MEDIA PHOTOS
                          Row(
                            children: [
                              const Icon(LucideIcons.camera, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Hình ảnh kiểm tra & nghiệm thu',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if ((_detail?['media'] as List?)?.isEmpty ?? true)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text('Chưa có hình ảnh nghiệm thu được công khai cho đơn này.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else
                            SizedBox(
                              height: 110,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ...?(_detail?['media'] as List?)?.map((med) {
                                    final rawUrl = med['mediaUrl']?.toString() ?? med['fileUrl']?.toString() ?? '';
                                    final api = context.read<AuthProvider>().api;
                                    final resolvedUrl = api.resolveUrl(rawUrl);
                                    final headers = api.mediaHeadersFor(resolvedUrl);

                                    return GestureDetector(
                                      onTap: () => _showFullImage(resolvedUrl),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 10),
                                        width: 110,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.network(
                                          resolvedUrl,
                                          headers: headers.isNotEmpty ? headers : null,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Center(
                                            child: Icon(LucideIcons.imageOff, size: 24, color: Color(0xFF94A3B8)),
                                          ),
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          const SizedBox(height: 30),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(String status) {
    final currentStep = _getStepIndex(status);
    final steps = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'Nghiệm thu', 'Bàn giao'];

    return Row(
      children: List.generate(steps.length, (stepIdx) {
        final isDone = stepIdx < currentStep;
        final isCurrent = stepIdx == currentStep;

        Color bg;
        if (isDone) {
          bg = const Color(0xFF16A34A);
        } else if (isCurrent) {
          bg = const Color(0xFF2563EB);
        } else {
          bg = const Color(0xFFCBD5E1);
        }

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stepIdx == 0
                          ? Colors.transparent
                          : (isDone || isCurrent ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: bg,
                    child: isDone
                        ? const Icon(LucideIcons.check, size: 11, color: Colors.white)
                        : (isCurrent
                            ? const Icon(LucideIcons.clock, size: 10, color: Colors.white)
                            : const SizedBox()),
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stepIdx == steps.length - 1
                          ? Colors.transparent
                          : (isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                steps[stepIdx],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? const Color(0xFF0F172A)
                      : (isDone ? const Color(0xFF15803D) : const Color(0xFF94A3B8)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }),
    );
  }
}
