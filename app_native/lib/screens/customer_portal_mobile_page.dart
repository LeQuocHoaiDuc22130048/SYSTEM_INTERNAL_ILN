import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
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
  Map<String, dynamic>? _accountProfile;
  final ImagePicker _imagePicker = ImagePicker();

  // Filter & Search states
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'IN_PROGRESS', 'COMPLETED', 'HISTORY'
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

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
    _fetchAccountProfile();
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
    } catch (_) {
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
      // Giữ thông tin hỗ trợ mặc định nếu endpoint không phản hồi
    }
  }

  Future<void> _fetchAccountProfile() async {
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/account-profile');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final data = res.containsKey('data') && res['data'] is Map<String, dynamic>
            ? res['data'] as Map<String, dynamic>
            : res;
        setState(() {
          _accountProfile = data;
        });
      }
    } catch (_) {
      // Giữ thông tin cơ bản từ auth nếu không tải được profile mở rộng
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
      } else if (_selectedFilter == 'HISTORY') {
        return status == 'DELIVERED' || status == 'COMPLETED' || status == 'CANCELLED';
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
    if (name.trim().isEmpty) return 'CT';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đăng xuất tài khoản',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi Cổng Khách Hàng theo dõi sửa chữa thiết bị?',
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // Warranty book dialog
  void _showWarrantyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.shieldCheck, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sổ bảo hành điện tử',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.checkCircle2, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bảo hành chính hãng Like New 06 - 12 tháng theo từng hạng mục sửa chữa.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Toàn bộ thiết bị sau khi nghiệm thu và bàn giao được lưu mã QR bảo hành điện tử trên hệ thống trung tâm.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  // QR Code scan dialog
  void _showQrScannerDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.qrCode, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Quét mã QR', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
              ),
              child: const Center(
                child: Icon(LucideIcons.scanLine, size: 64, color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hướng camera về phía mã QR trên tem bảo hành hoặc biên bản tiếp nhận để tra cứu nhanh.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // New repair request sheet
  void _showNewRequestDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(LucideIcons.plusCircle, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Tạo yêu cầu gửi sửa thiết bị',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Kỹ thuật viên của trung tâm Inverter Like New sẽ tiếp nhận thông tin và bố trí nhận máy cấp tốc.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _makePhoneCall(_hotlineNumber);
                  },
                  icon: const Icon(LucideIcons.phoneCall, size: 18),
                  label: Text('Gọi hotline tiếp nhận ($_hotlineNumber)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openZaloSupport();
                  },
                  icon: const Icon(LucideIcons.messageSquare, size: 18),
                  label: const Text('Gửi thông tin qua Zalo Tiếp Nhận', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Support & hotline information bottom sheet
  void _showSupportInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(LucideIcons.headset, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Trung tâm dịch vụ & Hỗ trợ kỹ thuật',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.phoneCall, color: Color(0xFF059669), size: 20),
                ),
                title: Text(_hotlineLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(_hotlineNumber, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _makePhoneCall(_hotlineNumber),
                  child: const Text('Gọi ngay'),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.messageSquare, color: Color(0xFF2563EB), size: 20),
                ),
                title: Text(_zaloLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Tư vấn & Báo giá kỹ thuật nhanh', style: TextStyle(fontSize: 12)),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openZaloSupport,
                  child: const Text('Mở Zalo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Profile Modal / Dialog - Redesigned per Stitch Screen 3
  Future<void> _showProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final api = auth.api;

    if (_accountProfile == null) {
      await _fetchAccountProfile();
    }
    if (!mounted) return;

    final user = auth.currentUser;
    final contactNameController = TextEditingController(
      text: _accountProfile?['contactName']?.toString() ?? user?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: _accountProfile?['phone']?.toString() ?? user?.phone ?? '',
    );
    final emailController = TextEditingController(
      text: _accountProfile?['email']?.toString() ?? user?.email ?? '',
    );

    String? currentAvatarUrl = _accountProfile?['avatarUrl']?.toString() ?? user?.avatar;
    final customerName = _accountProfile?['customerName']?.toString() ?? user?.name ?? 'Khách hàng';
    final customerCode = _accountProfile?['customerCode']?.toString() ?? '';
    final companyTaxCode = _accountProfile?['companyTaxCode']?.toString() ?? '';
    final companyAddress = _accountProfile?['companyAddress']?.toString() ?? '';
    final username = _accountProfile?['username']?.toString() ?? user?.username ?? '';

    bool isSaving = false;
    bool isUploadingAvatar = false;
    String? dialogError;
    String? dialogSuccess;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isSaving && !isUploadingAvatar,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final initials = _getInitials(
            contactNameController.text.trim().isNotEmpty
                ? contactNameController.text.trim()
                : customerName,
          );

          Future<void> pickAndUploadAvatar(ImageSource source) async {
            try {
              final picked = await _imagePicker.pickImage(
                source: source,
                imageQuality: 85,
                maxWidth: 1024,
                maxHeight: 1024,
              );
              if (picked == null) return;

              final bytes = await picked.readAsBytes();
              if (bytes.lengthInBytes > 10 * 1024 * 1024) {
                setDialogState(() => dialogError = 'Dung lượng ảnh đại diện tối đa 10MB.');
                return;
              }

              setDialogState(() {
                isUploadingAvatar = true;
                dialogError = null;
                dialogSuccess = null;
              });

              final ext = picked.name.split('.').last.toLowerCase();
              final contentType = ext == 'png'
                  ? 'image/png'
                  : ext == 'webp'
                      ? 'image/webp'
                      : 'image/jpeg';
              final res = await api.postMultipart(
                '/api/v1/customer/avatar',
                fields: {},
                filename: picked.name,
                bytes: bytes,
                contentType: contentType,
              );

              final updatedData = res is Map<String, dynamic>
                  ? (res.containsKey('data') && res['data'] is Map<String, dynamic>
                      ? res['data'] as Map<String, dynamic>
                      : res)
                  : null;

              if (updatedData != null) {
                final newAvatar = updatedData['avatarUrl']?.toString();
                setState(() {
                  _accountProfile = updatedData;
                });
                auth.updateCurrentUser(
                  avatar: newAvatar,
                  name: updatedData['contactName']?.toString(),
                  phone: updatedData['phone']?.toString(),
                  email: updatedData['email']?.toString(),
                );
                setDialogState(() {
                  currentAvatarUrl = newAvatar;
                  isUploadingAvatar = false;
                  dialogSuccess = 'Cập nhật ảnh đại diện thành công!';
                });
              } else {
                setDialogState(() {
                  isUploadingAvatar = false;
                  dialogError = 'Phản hồi tải lên ảnh không hợp lệ.';
                });
              }
            } on ApiException catch (e) {
              setDialogState(() {
                isUploadingAvatar = false;
                dialogError = e.message;
              });
            } catch (_) {
              setDialogState(() {
                isUploadingAvatar = false;
                dialogError = 'Không thể tải lên ảnh đại diện. Vui lòng thử lại.';
              });
            }
          }

          void showSourceSelection() {
            if (isSaving || isUploadingAvatar) return;
            showModalBottomSheet<void>(
              context: ctx,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (sheetCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cập nhật ảnh đại diện',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.camera, color: Color(0xFF2563EB)),
                        ),
                        title: const Text('Chụp ảnh mới từ máy ảnh'),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          pickAndUploadAvatar(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.image, color: Color(0xFF334155)),
                        ),
                        title: const Text('Chọn ảnh từ thư viện'),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          pickAndUploadAvatar(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final sheetHeight = MediaQuery.of(ctx).size.height * 0.92;

          return Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: const Icon(LucideIcons.userCog, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thông tin tài khoản',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Cổng giám sát sửa chữa thiết bị tự động hoá',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                        onPressed: isSaving || isUploadingAvatar ? null : () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      if (dialogError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.alertCircle, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(dialogError!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      if (dialogSuccess != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(dialogSuccess!, style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                      // Avatar & Identity Section
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: showSourceSelection,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF38BDF8)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          (currentAvatarUrl != null && currentAvatarUrl!.isNotEmpty)
                                              ? Image.network(
                                                  context.read<AuthProvider>().api.resolveUrl(currentAvatarUrl!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) => Container(
                                                    color: const Color(0xFF0F172A),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      initials,
                                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: const Color(0xFF0F172A),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                                                  ),
                                                ),
                                          if (isUploadingAvatar)
                                            Container(
                                              color: Colors.black45,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    username.isNotEmpty ? '@$username' : '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.check, size: 10, color: Color(0xFF059669)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Xác thực',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: isSaving || isUploadingAvatar ? null : showSourceSelection,
                              icon: const Icon(LucideIcons.camera, size: 13, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Cập nhật ảnh đại diện logo',
                                style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact info section
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'THÔNG TIN LIÊN HỆ TRỰC TIẾP',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '* Bắt buộc',
                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Field 1: Contact name
                      TextField(
                        controller: contactNameController,
                        decoration: InputDecoration(
                          labelText: 'Tên người liên hệ *',
                          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          prefixIcon: const Icon(LucideIcons.user, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Field 2: Phone with VN flag
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại nhận tin Zalo / SMS tiến độ',
                          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          prefixIcon: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🇻🇳', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 4),
                                Text('+84', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ],
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Field 3: Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email nhận biên bản & hóa đơn VAT',
                          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          prefixIcon: const Icon(LucideIcons.mail, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Đã xác minh', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Enterprise Legal Information Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.building2, size: 16, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Thông tin doanh nghiệp đối tác',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildProfileInfoRow('Doanh nghiệp:', customerName),
                            if (customerCode.isNotEmpty)
                              _buildProfileInfoRow('Mã khách hàng:', customerCode),
                            if (companyTaxCode.isNotEmpty)
                              _buildProfileInfoRow('Mã số thuế:', companyTaxCode),
                            _buildProfileInfoRow('Hợp đồng:', 'HD-2026/VIP-09'),
                            if (companyAddress.isNotEmpty)
                              _buildProfileInfoRow('Địa chỉ:', companyAddress),
                            const SizedBox(height: 6),
                            const Text(
                              '* Thông tin pháp nhân doanh nghiệp do Admin quản lý. Để thay đổi vui lòng liên hệ Hotline.',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Security options buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _showChangePasswordDialog(context);
                              },
                              icon: const Icon(LucideIcons.keyRound, size: 14),
                              label: const Text('Đổi mật khẩu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEF2F2),
                                foregroundColor: const Color(0xFFDC2626),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _confirmLogout(context);
                              },
                              icon: const Icon(LucideIcons.logOut, size: 14),
                              label: const Text('Đăng xuất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sticky Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSaving || isUploadingAvatar ? null : () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSaving || isUploadingAvatar
                              ? null
                              : () async {
                                  final contactName = contactNameController.text.trim();
                                  final phone = phoneController.text.trim();
                                  final email = emailController.text.trim();

                                  if (contactName.isEmpty) {
                                    setDialogState(() => dialogError = 'Tên người liên hệ không được để trống.');
                                    return;
                                  }
                                  if (contactName.length > 100) {
                                    setDialogState(() => dialogError = 'Tên người liên hệ tối đa 100 ký tự.');
                                    return;
                                  }
                                  if (phone.isNotEmpty && !RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(phone)) {
                                    setDialogState(() => dialogError = 'Số điện thoại không hợp lệ (9-10 chữ số).');
                                    return;
                                  }
                                  if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                                    setDialogState(() => dialogError = 'Email không hợp lệ.');
                                    return;
                                  }

                                  setDialogState(() {
                                    isSaving = true;
                                    dialogError = null;
                                    dialogSuccess = null;
                                  });

                                  try {
                                    final res = await api.put(
                                      '/api/v1/customer/account-profile',
                                      body: {
                                        'contactName': contactName,
                                        'phone': phone,
                                        'email': email,
                                      },
                                    );

                                    final updatedData = res is Map<String, dynamic>
                                        ? (res.containsKey('data') && res['data'] is Map<String, dynamic>
                                            ? res['data'] as Map<String, dynamic>
                                            : res)
                                        : null;

                                    if (updatedData != null) {
                                      setState(() {
                                        _accountProfile = updatedData;
                                      });
                                      auth.updateCurrentUser(
                                        name: updatedData['contactName']?.toString(),
                                        phone: updatedData['phone']?.toString(),
                                        email: updatedData['email']?.toString(),
                                        avatar: updatedData['avatarUrl']?.toString(),
                                      );
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Cập nhật thông tin tài khoản thành công!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  } on ApiException catch (e) {
                                    setDialogState(() {
                                      isSaving = false;
                                      dialogError = e.message;
                                    });
                                  } catch (_) {
                                    setDialogState(() {
                                      isSaving = false;
                                      dialogError = 'Không thể cập nhật thông tin. Vui lòng thử lại.';
                                    });
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(LucideIcons.check, size: 16),
                          label: const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      } catch (_) {
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
      builder: (ctx) => _OrderDetailSheet(
        orderId: orderId,
        hotlineNumber: _hotlineNumber,
        onMakeCall: _makePhoneCall,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFD97706);
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return const Color(0xFF4F46E5);
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB);
      case 'COMPLETED':
        return const Color(0xFF059669);
      case 'DELIVERED':
        return const Color(0xFF0D9488);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
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
        return LucideIcons.settings;
      case 'COMPLETED':
        return LucideIcons.checkCircle2;
      case 'DELIVERED':
        return LucideIcons.packageCheck;
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
        return 2; // Sửa chữa
      case 'COMPLETED':
        return 3; // K.Tra tải / Nghiệm thu
      case 'DELIVERED':
        return 4; // Bàn giao
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final companyName = _accountProfile?['customerName']?.toString() ?? user?.name ?? 'Khách hàng';
    final contactName = _accountProfile?['contactName']?.toString() ?? '';
    final avatarUrl = _accountProfile?['avatarUrl']?.toString() ?? user?.avatar;
    final initials = _getInitials(contactName.isNotEmpty ? contactName : companyName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            // Microchip Logo Chip (Stitch Design)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
              ),
              child: const Icon(LucideIcons.cpu, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'CỔNG KHÁCH HÀNG',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Text(
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
          // Profile Circular Button with Red Notification Dot Badge
          PopupMenuButton<String>(
            tooltip: 'Tài khoản & Cài đặt',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipOval(
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(
                            context.read<AuthProvider>().api.resolveUrl(avatarUrl),
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(
                              LucideIcons.userRound,
                              size: 18,
                              color: Color(0xFF334155),
                            ),
                          )
                        : const Icon(
                            LucideIcons.userRound,
                            size: 18,
                            color: Color(0xFF334155),
                          ),
                  ),
                ),
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            onSelected: (value) {
              if (value == 'profile') {
                _showProfileDialog();
              } else if (value == 'change_pwd') {
                _showChangePasswordDialog(context);
              } else if (value == 'warranty') {
                _showWarrantyDialog();
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
                    Text(
                      companyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contactName.isNotEmpty && contactName != companyName)
                      Text(
                        contactName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                      ),
                    Text(
                      user?.username ?? '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(LucideIcons.userCog, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Text('Hồ sơ cá nhân', style: TextStyle(fontSize: 14)),
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
                    Icon(LucideIcons.logOut, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Text('Đăng xuất', style: TextStyle(fontSize: 14, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchOrders(),
            _fetchSupportConfig(),
            _fetchAccountProfile(),
          ]);
        },
        color: const Color(0xFF2563EB),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // 1. VIP MEMBERSHIP CARD (Gradient Enterprise Hero Card from Stitch)
            _buildVipMembershipCard(companyName, contactName, initials, user?.username, avatarUrl),
            const SizedBox(height: 16),

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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filteredOrders.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF2563EB),
                  ),
                  onPressed: _fetchOrders,
                  icon: const Icon(LucideIcons.refreshCw, size: 13),
                  label: const Text('Làm mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),

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

            const SizedBox(height: 14),

            // 5. FAST SUPPORT BANNER (Bottom Banner from Stitch)
            _buildFastSupportBanner(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // VIP Enterprise Hero Card (Redesigned matching Stitch Screen 1)
  Widget _buildVipMembershipCard(
    String companyName,
    String contactName,
    String initials,
    String? username,
    String? avatarUrl,
  ) {
    final customerCode = _accountProfile?['customerCode']?.toString() ?? '';
    final codeDisplay = customerCode.isNotEmpty ? customerCode : (username ?? 'DN-84920');

    final completed = _completedCount;
    final inProgress = _inProgressCount;
    final total = _orders.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF172554), // Blue 950
            Color(0xFF1E1B4B), // Indigo 950
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.4)),
      ),
      child: Stack(
        children: [
          // Ambient blurred glow circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: VIP Badge & Realtime Monitoring Beacon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x26FBBF24),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x4DFBBF24)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.crown, size: 11, color: Color(0xFFFBBF24)),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'ĐỐI TÁC DOANH NGHIỆP',
                                style: TextStyle(
                                  color: Color(0xFFFCD34D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x80064E3B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x4D10B981)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '24/7',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Company Identity Block
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showProfileDialog(),
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? Image.network(
                                    context.read<AuthProvider>().api.resolveUrl(avatarUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Color(0xFF60A5FA),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showProfileDialog(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  'Mã: ',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '#$codeDisplay',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (contactName.isNotEmpty && contactName != companyName) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Đại diện: $contactName',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Hotline 1-Touch Contact Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.headset, size: 16, color: Color(0xFF34D399)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kỹ thuật viên quản lý chuyên trách',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Cty TNHH DV Inverter Like New',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 1-Touch call button
                      Flexible(
                        child: InkWell(
                          onTap: () => _makePhoneCall(_hotlineNumber),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.phoneCall, size: 11, color: Color(0xFF022C22)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _hotlineLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF022C22),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
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
                const SizedBox(height: 10),

                // Secondary Zalo action touch
                InkWell(
                  onTap: _openZaloSupport,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.messageSquare, size: 12, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _zaloLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Metrics Bar (3 columns)
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                total < 10 ? '0$total' : '$total',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đơn sửa chữa',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                completed < 10 ? '0$completed' : '$completed',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF34D399),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sẵn sàng nhận',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                inProgress < 10 ? '0$inProgress' : '$inProgress',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF60A5FA),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đang thực hiện',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // Search Bar with QR scanner button (Stitch Design)
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              GestureDetector(
                onTap: _showQrScannerDialog,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.qrCode, size: 16, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  // Quick Filter Tabs (Pill chips from Stitch)
  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', 'Tất cả (${_orders.length})', LucideIcons.layers, null),
          const SizedBox(width: 8),
          _buildFilterChip('IN_PROGRESS', 'Đang xử lý ($_inProgressCount)', LucideIcons.wrench, const Color(0xFFD97706)),
          const SizedBox(width: 8),
          _buildFilterChip('COMPLETED', 'Sẵn sàng nhận ($_completedCount)', LucideIcons.checkCircle, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildFilterChip('HISTORY', 'Lịch sử trả hàng', LucideIcons.archive, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String title, IconData icon, Color? iconTint) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
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
              size: 13,
              color: isSelected ? Colors.white : (iconTint ?? const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Order Card with Inline 5-Step Stepper (Stitch Screen 1)
  Widget _buildOrderCard(Map<String, dynamic> ord) {
    final orderCode = ord['orderCode']?.toString() ?? '';
    final orderTitle = ord['orderTitle']?.toString() ?? 'Đơn sửa chữa';
    final status = ord['status']?.toString() ?? 'PENDING';
    final friendlyStatus = ord['friendlyStatus']?.toString() ?? status;
    final deviceCount = ord['deviceCount'] ?? 1;
    final receivedDate = ord['receivedDate']?.toString() ?? '';

    final isCompleted = status == 'COMPLETED' || status == 'DELIVERED';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final timelineStep = _getTimelineStep(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFD1FAE5)
              : (status == 'IN_PROGRESS' ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Indicator Line
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [const Color(0xFF34D399), const Color(0xFF14B8A6)]
                      : [const Color(0xFF3B82F6), const Color(0xFF4F46E5)],
                ),
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openOrderDetail(ord['id']?.toString() ?? ''),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Order Code & Status Badge Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.fileText, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 12, color: statusColor),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      friendlyStatus,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
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
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tags Row (Equipment count & Times)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.cpu, size: 11, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  '$deviceCount thiết bị',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (receivedDate.isNotEmpty) ...[
                            const Icon(LucideIcons.clock, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Cập nhật: ${receivedDate.split("T").first}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5-Step Process Stepper (Stitch Design)
                      _buildMiniProgressTimeline(timelineStep, isCompleted),
                      const SizedBox(height: 14),

                      // Bottom CTA Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? LucideIcons.image : LucideIcons.search,
                              size: 14,
                              color: isCompleted ? const Color(0xFF059669) : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isCompleted
                                    ? 'Xem chi tiết tiến độ & ảnh nghiệm thu'
                                    : 'Xem chi tiết tiến độ & nhật ký kỹ thuật',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: isCompleted ? const Color(0xFF059669) : const Color(0xFF2563EB),
                            ),
                          ],
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
    );
  }

  // 5-Step Stepper inside card (Stitch Design)
  Widget _buildMiniProgressTimeline(int currentStep, bool isCompleted) {
    final stages = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'K.Tra Tải', 'Bàn giao'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          // Stepper Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'TIẾN TRÌNH KỸ THUẬT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted ? 'đã kiểm định 100%' : 'bước ${currentStep + 1}/5',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? const Color(0xFF059669) : const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stepper Nodes
          Row(
            children: List.generate(stages.length, (stepIdx) {
              final isDone = stepIdx < currentStep || isCompleted;
              final isCurrent = stepIdx == currentStep && !isCompleted;

              Color bg;
              if (isDone) {
                bg = const Color(0xFF10B981);
              } else if (isCurrent) {
                bg = const Color(0xFF2563EB);
              } else {
                bg = const Color(0xFFE2E8F0);
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
                                : (isDone || isCurrent ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: bg,
                          child: isDone
                              ? const Icon(LucideIcons.check, size: 10, color: Colors.white)
                              : (isCurrent
                                  ? const Icon(LucideIcons.clock, size: 9, color: Colors.white)
                                  : Text('${stepIdx + 1}', style: const TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: stepIdx == stages.length - 1
                                ? Colors.transparent
                                : (isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stages[stepIdx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: (isDone || isCurrent) ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent
                            ? const Color(0xFF1D4ED8)
                            : (isDone ? const Color(0xFF065F46) : const Color(0xFF94A3B8)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Fast Support Banner (Stitch Screen 1)
  Widget _buildFastSupportBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: const Icon(LucideIcons.fileQuestion, color: Color(0xFF93C5FD), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cần gửi thêm thiết bị sửa mới?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Tạo phiếu nhận máy tận nơi cấp tốc',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showNewRequestDialog,
            child: const Text('Gửi yêu cầu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Modern Bottom Navigation Bar (Stitch Screen 1)
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              _buildNavItem(0, LucideIcons.receipt, 'Đơn hàng', () {
                setState(() {
                  _currentNavIndex = 0;
                  _selectedFilter = 'ALL';
                });
              }),
              _buildNavItem(1, LucideIcons.cpu, 'Thiết bị', () {
                setState(() => _currentNavIndex = 1);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tổng cộng ${_orders.fold<int>(0, (acc, o) => acc + (o['deviceCount'] as int? ?? 1))} thiết bị đang được giám sát tại xưởng.'),
                  ),
                );
              }),
              // Center Action Button "+ Yêu cầu mới"
              Expanded(
                child: GestureDetector(
                  onTap: _showNewRequestDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5)],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tạo đơn',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              _buildNavItem(3, LucideIcons.history, 'Lịch sử', () {
                setState(() {
                  _currentNavIndex = 3;
                  _selectedFilter = 'HISTORY';
                });
              }),
              _buildNavItem(4, LucideIcons.circleHelp, 'Hỗ trợ', () {
                setState(() => _currentNavIndex = 4);
                _showSupportInfoSheet();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, VoidCallback onTap) {
    final isSelected = _currentNavIndex == index;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                  ),
                  if (isSelected)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vibrant Empty State
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
            ),
            child: const Icon(LucideIcons.packageOpen, size: 32, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có đơn sửa chữa nào',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _fetchOrders,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
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
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
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

// Order Detail Bottom Sheet - Redesigned per Stitch Screen 2
class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({
    required this.orderId,
    required this.hotlineNumber,
    required this.onMakeCall,
  });

  final String orderId;
  final String hotlineNumber;
  final Future<void> Function(String) onMakeCall;

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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmAcceptance() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.checkCheck, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('Nghiệm thu thiết bị', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Quý khách xác nhận đã hoàn tất nghiệm thu kỹ thuật và muốn đặt lịch bàn giao / nhận máy?',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã ghi nhận nghiệm thu. Kỹ thuật viên sẽ liên hệ bàn giao ngay!'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
            },
            child: const Text('Xác nhận & Đặt lịch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final status = _detail?['status']?.toString() ?? 'PENDING';
    final isCompleted = status == 'COMPLETED' || status == 'DELIVERED';
    final orderCode = _detail?['orderCode']?.toString() ?? '';
    final orderTitle = _detail?['orderTitle']?.toString() ?? '';
    final devices = (_detail?['devices'] as List?) ?? [];
    final updates = (_detail?['updates'] as List?) ?? [];
    final media = (_detail?['media'] as List?) ?? [];

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle pill
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Modal Header (Stitch Design)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFF2563EB)),
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
                              orderCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'Sẵn sàng bàn giao' : 'Đang xử lý kỹ thuật',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (orderTitle.isNotEmpty)
                        Text(
                          orderTitle,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // 1. 5-Stage Stepper Card
                          _buildStepperCard(status),
                          const SizedBox(height: 20),

                          // 2. Equipment Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.cpu, size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Thiết bị (${devices.length})',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đã kiểm thử QC',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...devices.map((dev) {
                            final serial = dev['serialNumber']?.toString() ?? 'Chưa rõ';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE0E7FF)),
                                    ),
                                    child: const Icon(LucideIcons.memoryStick, color: Color(0xFF4F46E5), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                dev['modelName']?.toString() ?? 'Thiết bị kỹ thuật',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Tải 100% OK',
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Text('Serial: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                serial,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF1E293B)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _copyToClipboard(serial),
                                              child: const Padding(
                                                padding: EdgeInsets.all(2),
                                                child: Icon(LucideIcons.copy, size: 13, color: Color(0xFF2563EB)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((dev['issueDescription'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Lỗi: ${dev["issueDescription"]}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 18),

                          // 3. Technical Log Section (Nhật ký kỹ thuật & Thao tác)
                          const Row(
                            children: [
                              Icon(LucideIcons.fileCheck2, size: 16, color: Color(0xFF059669)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nhật ký kỹ thuật & Thao tác',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (updates.isEmpty)
                                  const Text(
                                    'Kỹ thuật viên đang kiểm tra và sẽ sớm cập nhật kết quả.',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic),
                                  )
                                else
                                  ...updates.map((up) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(top: 2),
                                              width: 14,
                                              height: 14,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(LucideIcons.check, size: 8, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Expanded(
                                                        child: Text(
                                                          'Ghi nhận tiến độ',
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        (up['publishedAt'] ?? up['createdAt'])?.toString().split("T").first ?? '',
                                                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    up['content']?.toString() ?? up['message']?.toString() ?? '',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),

                                // Lead Technician Profile Box (Stitch Design)
                                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Center(
                                        child: Text('NA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'KTV. Nguyễn Văn An',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Mã kỹ thuật: ENG-4820',
                                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.checkCheck, size: 10, color: Color(0xFF059669)),
                                          SizedBox(width: 4),
                                          Text('Duyệt QC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 4. Evidence Media Photos (Hình ảnh kiểm tra & Nghiệm thu)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.camera, size: 16, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Hình ảnh kiểm tra & Đo đạc (${media.length})',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (media.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Text('Xem tất cả', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (media.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Text('Chưa có hình ảnh nghiệm thu được công khai cho đơn này.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            )
                          else
                            SizedBox(
                              height: 120,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: media.map((med) {
                                  final rawUrl = med['mediaUrl']?.toString() ?? med['fileUrl']?.toString() ?? '';
                                  final api = context.read<AuthProvider>().api;
                                  final resolvedUrl = api.resolveUrl(rawUrl);
                                  final headers = api.mediaHeadersFor(resolvedUrl);

                                  return GestureDetector(
                                    onTap: () => _showFullImage(resolvedUrl),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        color: const Color(0xFFF1F5F9),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.network(
                                            resolvedUrl,
                                            headers: headers.isNotEmpty ? headers : null,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Center(
                                              child: Icon(LucideIcons.imageOff, size: 24, color: Color(0xFF94A3B8)),
                                            ),
                                          ),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'QC PASS',
                                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
          ),

          // Sticky Footer Actions (Stitch Design)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _confirmAcceptance,
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    label: const Text('Xác Nhận Nghiệm Thu & Đặt Lịch Nhận Máy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => widget.onMakeCall(widget.hotlineNumber),
                    icon: const Icon(LucideIcons.headset, size: 15),
                    label: const Text('Trao đổi thêm với Kỹ thuật viên (Hotline 24/7)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5-Stage Stepper Card inside Sheet (Stitch Screen 2)
  Widget _buildStepperCard(String status) {
    final currentStep = _getStepIndex(status);
    final steps = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'Nghiệm thu', 'Bàn giao'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(steps.length, (stepIdx) {
              final isDone = stepIdx < currentStep;
              final isCurrent = stepIdx == currentStep;

              Color bg;
              if (isDone) {
                bg = const Color(0xFF10B981);
              } else if (isCurrent) {
                bg = const Color(0xFF2563EB);
              } else {
                bg = const Color(0xFFE2E8F0);
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
                                : (isDone || isCurrent ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: bg,
                          child: isDone
                              ? const Icon(LucideIcons.check, size: 11, color: Colors.white)
                              : (isCurrent
                                  ? const Icon(LucideIcons.clock, size: 10, color: Colors.white)
                                  : Text('${stepIdx + 1}', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: stepIdx == steps.length - 1
                                ? Colors.transparent
                                : (isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[stepIdx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: (isCurrent || isDone) ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent
                            ? const Color(0xFF1D4ED8)
                            : (isDone ? const Color(0xFF047857) : const Color(0xFF94A3B8)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
