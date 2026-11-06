import 'dart:io';
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
  String _selectedFilter = 'ALL'; // 'ALL', 'IN_PROGRESS', 'PENDING', 'CHECKING', 'REPAIRING', 'COMPLETED', 'DELIVERED', 'HISTORY'
  String _selectedTimeFilter = 'ALL'; // 'ALL', '30_DAYS', 'THIS_MONTH', '3_MONTHS', 'THIS_YEAR'
  String _selectedDeviceType = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  int _currentNavIndex = 0;

  // Feedback System States
  String _feedbackViewMode = 'CREATE'; // 'CREATE' or 'HISTORY'
  String? _feedbackSelectedOrderCode;
  int _feedbackRating = 5;
  String _feedbackType = 'SERVICE_QUALITY'; // 'SERVICE_QUALITY', 'WARRANTY_ISSUE', 'SUGGESTION'
  bool _feedbackIsUrgent = false;
  final Set<String> _feedbackSelectedTags = {};
  final TextEditingController _feedbackContentController = TextEditingController();
  final List<XFile> _feedbackImages = [];
  bool _isSubmittingFeedback = false;

  List<Map<String, dynamic>> _myFeedbacks = [];

  static const String defaultHotlinePhone = '0964 266 771'; // Số điện thoại hỗ trợ kỹ thuật
  static const String defaultWorkshopAddress =
      '243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh, Việt Nam';
  static const double workshopLatitude = 10.854611;
  static const double workshopLongitude = 106.703212;

  String _hotlineNumber = defaultHotlinePhone;
  String _hotlineLabel = 'Liên hệ kỹ thuật';
  String _workshopAddress = defaultWorkshopAddress;
  String? _workshopMapUrl;
  double _workshopLat = workshopLatitude;
  double _workshopLng = workshopLongitude;
  String? _workshopMapImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchSupportConfig();
    _fetchAccountProfile();
    _fetchMyFeedbacks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedbackContentController.dispose();
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
          if (hNum != null && hNum.isNotEmpty && hNum != '0909000000') {
            _hotlineNumber = hNum;
          } else {
            _hotlineNumber = defaultHotlinePhone;
          }
          final hLbl = res['hotlineLabel']?.toString().trim();
          if (hLbl != null &&
              hLbl.isNotEmpty &&
              !hLbl.toLowerCase().contains('hotline')) {
            _hotlineLabel = hLbl;
          } else {
            _hotlineLabel = 'Liên hệ kỹ thuật';
          }
          final addr = res['workshopAddress']?.toString().trim();
          if (addr != null &&
              addr.isNotEmpty &&
              !addr.contains('Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp') &&
              !addr.contains('Văn Khê')) {
            _workshopAddress = addr;
          } else {
            _workshopAddress = defaultWorkshopAddress;
          }

          final mUrl = res['mapUrl']?.toString().trim();
          if (mUrl != null && mUrl.isNotEmpty) {
            _workshopMapUrl = mUrl;
          }
          final latVal = res['latitude'];
          if (latVal is num) {
            _workshopLat = latVal.toDouble();
          }
          final lngVal = res['longitude'];
          if (lngVal is num) {
            _workshopLng = lngVal.toDouble();
          }
          final mImg = res['mapImageUrl']?.toString().trim();
          if (mImg != null && mImg.isNotEmpty) {
            _workshopMapImageUrl = mImg;
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

  // Google Maps Navigation & Directions
  Future<void> _openGoogleMaps({bool directions = true}) async {
    // If admin configured a direct mapUrl and user wants to view map:
    if (!directions && _workshopMapUrl != null && _workshopMapUrl!.isNotEmpty) {
      final customUri = Uri.parse(_workshopMapUrl!);
      try {
        if (await canLaunchUrl(customUri)) {
          await launchUrl(customUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    final destination = Uri.encodeComponent(_workshopAddress);
    final urlString = directions
        ? 'https://www.google.com/maps/dir/?api=1&destination=$_workshopLat,$_workshopLng'
        : (_workshopMapUrl != null && _workshopMapUrl!.isNotEmpty
            ? _workshopMapUrl!
            : 'https://www.google.com/maps/search/?api=1&query=$destination');
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final geoUri = Uri.parse('geo:$_workshopLat,$_workshopLng?q=$destination');
        if (await canLaunchUrl(geoUri)) {
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở ứng dụng bản đồ.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi mở bản đồ dẫn đường.')),
        );
      }
    }
  }

  // Google Street View Panorama
  Future<void> _openStreetView() async {
    final uri = Uri.parse('https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$_workshopLat,$_workshopLng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _openGoogleMaps(directions: false);
      }
    } catch (_) {
      _openGoogleMaps(directions: false);
    }
  }

  // Copy Workshop Address
  void _copyWorkshopAddress() {
    Clipboard.setData(ClipboardData(text: _workshopAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.checkCheck, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Đã sao chép địa chỉ xưởng vào bộ nhớ tạm')),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _translateStatusToVietnamese(String status, [String? rawLabel]) {
    final normalizedStatus = status.trim().toUpperCase();
    if (rawLabel != null && rawLabel.trim().isNotEmpty) {
      final cleanLabel = rawLabel.trim();
      final upperLabel = cleanLabel.toUpperCase();
      const rawCodes = {
        'PENDING',
        'WAITING_FOR_CHECK',
        'CHECKING',
        'CHECKED',
        'IN_PROGRESS',
        'COMPLETED',
        'DELIVERED',
        'CANCELLED',
      };
      if (!rawCodes.contains(upperLabel)) {
        return cleanLabel.replaceAll('test', 'kiểm tra');
      }
    }
    switch (normalizedStatus) {
      case 'PENDING':
        return 'Đã tiếp nhận';
      case 'WAITING_FOR_CHECK':
        return 'Chờ kiểm tra';
      case 'CHECKING':
        return 'Đang kiểm tra & chẩn đoán';
      case 'CHECKED':
        return 'Đã kiểm tra';
      case 'IN_PROGRESS':
        return 'Đang tiến hành sửa chữa';
      case 'COMPLETED':
        return 'Đã sửa xong & kiểm tra thành công';
      case 'DELIVERED':
        return 'Đã bàn giao cho khách';
      case 'CANCELLED':
        return 'Đã trả thiết bị / Hủy đơn';
      default:
        return 'Đang xử lý';
    }
  }

  static String _resolveOrderTitle(Map<String, dynamic> ord) {
    final deviceName = (ord['deviceName'] ?? '').toString().trim();
    final deviceType = (ord['deviceType'] ?? '').toString().trim();
    if (deviceName.isNotEmpty) {
      if (deviceType.isNotEmpty && !deviceName.toLowerCase().contains(deviceType.toLowerCase())) {
        return '$deviceName ($deviceType)';
      }
      return deviceName;
    }
    if (deviceType.isNotEmpty) {
      return deviceType;
    }
    final orderTitle = (ord['orderTitle'] ?? '').toString().trim();
    if (orderTitle.isNotEmpty && orderTitle != 'Đơn sửa chữa') {
      return orderTitle;
    }
    final devices = ord['devices'];
    if (devices is List && devices.isNotEmpty && devices.first is Map) {
      final firstDev = devices.first as Map;
      final firstDevName = (firstDev['deviceName'] ?? firstDev['modelName'] ?? '').toString().trim();
      final firstDevType = (firstDev['deviceType'] ?? firstDev['model'] ?? '').toString().trim();
      if (firstDevName.isNotEmpty) {
        return firstDevType.isNotEmpty && !firstDevName.toLowerCase().contains(firstDevType.toLowerCase())
            ? '$firstDevName ($firstDevType)'
            : firstDevName;
      }
      if (firstDevType.isNotEmpty) {
        return firstDevType;
      }
    }
    final desc = (ord['description'] ?? '').toString().trim();
    if (desc.isNotEmpty) {
      return desc;
    }
    if (orderTitle.isNotEmpty) {
      return orderTitle;
    }
    return 'Đơn sửa chữa thiết bị';
  }

  static String _formatVietnameseDate(String? raw, {bool includeTime = false}) {
    if (raw == null || raw.trim().isEmpty) return '';
    final clean = raw.trim();
    String timeStr = '';
    if (includeTime && clean.contains('T')) {
      final timePart = clean.split('T')[1].split('+')[0].split('Z')[0];
      final timeSegments = timePart.split(':');
      if (timeSegments.length >= 2) {
        timeStr = '${timeSegments[0]}:${timeSegments[1]} ';
      }
    }
    final datePart = clean.split('T').first.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '$timeStr${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return '$timeStr$datePart';
  }

  // Filtered orders getter
  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((ord) {
      final code = (ord['orderCode'] ?? '').toString().toLowerCase();
      final title = _resolveOrderTitle(ord).toLowerCase();
      final serial = (ord['serialNumber'] ?? '').toString().toLowerCase();
      final desc = (ord['description'] ?? '').toString().toLowerCase();
      final devType = (ord['deviceType'] ?? '').toString().toLowerCase();
      final devName = (ord['deviceName'] ?? '').toString().toLowerCase();
      final status = (ord['status'] ?? '').toString().toUpperCase();
      final q = _searchQuery.trim().toLowerCase();

      // Search query filter
      if (q.isNotEmpty &&
          !code.contains(q) &&
          !title.contains(q) &&
          !serial.contains(q) &&
          !devType.contains(q) &&
          !devName.contains(q) &&
          !desc.contains(q)) {
        return false;
      }

      // Status filter
      if (_selectedFilter == 'IN_PROGRESS') {
        final match = status == 'PENDING' ||
            status == 'WAITING_FOR_CHECK' ||
            status == 'CHECKING' ||
            status == 'CHECKED' ||
            status == 'IN_PROGRESS';
        if (!match) return false;
      } else if (_selectedFilter == 'PENDING') {
        if (status != 'PENDING' && status != 'WAITING_FOR_CHECK') return false;
      } else if (_selectedFilter == 'CHECKING') {
        if (status != 'CHECKING' && status != 'CHECKED') return false;
      } else if (_selectedFilter == 'REPAIRING') {
        if (status != 'IN_PROGRESS') return false;
      } else if (_selectedFilter == 'COMPLETED') {
        if (status != 'COMPLETED' && status != 'DELIVERED') return false;
      } else if (_selectedFilter == 'DELIVERED') {
        if (status != 'DELIVERED') return false;
      } else if (_selectedFilter == 'HISTORY') {
        final match = status == 'DELIVERED' || status == 'COMPLETED' || status == 'CANCELLED';
        if (!match) return false;
      }

      // Time filter
      if (_selectedTimeFilter != 'ALL') {
        final rawDate = (ord['receivedAt'] ?? ord['receivedDate'] ?? ord['updatedAt'] ?? '').toString();
        if (rawDate.isNotEmpty) {
          final dt = DateTime.tryParse(rawDate);
          if (dt != null) {
            final now = DateTime.now();
            if (_selectedTimeFilter == '30_DAYS') {
              final diff = now.difference(dt).inDays;
              if (diff < 0 || diff > 30) return false;
            } else if (_selectedTimeFilter == 'THIS_MONTH') {
              if (dt.month != now.month || dt.year != now.year) return false;
            } else if (_selectedTimeFilter == '3_MONTHS') {
              final diff = now.difference(dt).inDays;
              if (diff < 0 || diff > 90) return false;
            } else if (_selectedTimeFilter == 'THIS_YEAR') {
              if (dt.year != now.year) return false;
            }
          }
        }
      }

      // Device type filter
      if (_selectedDeviceType != 'ALL') {
        final dt = (ord['deviceType'] ?? ord['deviceName'] ?? '').toString().trim().toLowerCase();
        if (dt != _selectedDeviceType.toLowerCase()) return false;
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

  int get _deliveredCount => _orders.where((o) {
        final s = (o['status'] ?? '').toString().toUpperCase();
        return s == 'DELIVERED';
      }).length;

  List<String> get _availableDeviceTypes {
    final set = <String>{};
    for (final ord in _orders) {
      final t = (ord['deviceType'] ?? ord['deviceName'] ?? '').toString().trim();
      if (t.isNotEmpty) set.add(t);
    }
    return set.toList();
  }

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

  // New repair request sheet with 2 choices: Form entry & Hotline call
  void _showNewRequestDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                  Icon(LucideIcons.wrench, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tạo yêu cầu gửi sửa thiết bị',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn phương thức tiếp nhận máy thuận tiện nhất cho Quý khách:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Option 1: Điền form gửi máy sửa chữa
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateOrderFormSheet();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.fileSpreadsheet, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điền form gửi máy sửa chữa',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nhập model, số serial và mô tả lỗi để kỹ thuật viên chuẩn bị linh kiện tiếp nhận.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Gọi hotline hỗ trợ nhanh
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _makePhoneCall(_hotlineNumber);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.phoneCall, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gọi hotline hỗ trợ nhanh (24/7)',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_hotlineLabel: $_hotlineNumber\nKết nối trực tiếp kỹ sư chuyên trách để tư vấn bắt bệnh từ xa.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF059669), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Interactive Form Sheet for online machine repair request
  void _showCreateOrderFormSheet() {
    final modelController = TextEditingController();
    final serialController = TextEditingController();
    final issueController = TextEditingController();
    final addressController = TextEditingController(
      text: _accountProfile?['companyAddress']?.toString() ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SingleChildScrollView(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Điền form gửi máy sửa chữa',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Hệ thống tiếp nhận & bố trí nhận máy cấp tốc',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Model / Loại máy (*)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Schneider ATV310 7.5kW, Fuji Mega 15kW...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Số Sê-ri (Serial number)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: serialController,
                  decoration: InputDecoration(
                    hintText: 'Nhập số serial trên tem máy (nếu có)',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Mô tả hiện tượng lỗi / sự cố (*)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: issueController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Báo lỗi quá dòng OC, nổ bo công suất IGBT, mất nguồn điều khiển 24V...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Địa chỉ nhận thiết bị / Nhà xưởng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    hintText: 'Địa chỉ nhà xưởng hoặc ghi chú tự mang đến trung tâm',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final model = modelController.text.trim();
                      final issue = issueController.text.trim();
                      if (model.isEmpty || issue.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập Model máy và mô tả lỗi thiết bị.'),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop();
                      _showRequestSuccessDialog(model);
                    },
                    child: const Text('Gửi phiếu yêu cầu sửa chữa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRequestSuccessDialog(String model) {
    final ticketCode = 'YC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle2, color: Color(0xFF10B981), size: 32),
            ),
            const SizedBox(height: 14),
            const Text(
              'Gửi yêu cầu thành công!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mã phiếu: #$ticketCode',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thiết bị "$model" đã được ghi nhận. Kỹ thuật viên sẽ liên hệ Quý khách trong vòng 15 phút để xác nhận phương án nhận máy tận nơi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _makePhoneCall(_hotlineNumber);
                    },
                    icon: const Icon(LucideIcons.phoneCall, size: 14),
                    label: const Text('Gọi hotline', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Support & phone contact bottom sheet
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
                          labelText: 'Số điện thoại liên hệ',
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
                          labelText: 'Địa chỉ thư điện tử',
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
                            if (companyAddress.isNotEmpty)
                              _buildProfileInfoRow('Địa chỉ:', companyAddress),
                            const SizedBox(height: 6),
                            Text(
                              '* Thông tin doanh nghiệp do Quản trị viên quản lý. Để thay đổi vui lòng liên hệ số điện thoại $_hotlineNumber.',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
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

  static Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFD97706); // Amber
      case 'WAITING_FOR_CHECK':
        return const Color(0xFF4F46E5); // Indigo
      case 'CHECKING':
        return const Color(0xFF9333EA); // Purple
      case 'CHECKED':
        return const Color(0xFF0891B2); // Cyan
      case 'IN_PROGRESS':
        return const Color(0xFF2563EB); // Blue
      case 'COMPLETED':
        return const Color(0xFF059669); // Emerald
      case 'DELIVERED':
        return const Color(0xFF0D9488); // Teal
      case 'CANCELLED':
        return const Color(0xFFE11D48); // Rose
      default:
        return const Color(0xFF475569);
    }
  }

  static Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFEF3C7);
      case 'WAITING_FOR_CHECK':
        return const Color(0xFFEEF2FF);
      case 'CHECKING':
        return const Color(0xFFF3E8FF);
      case 'CHECKED':
        return const Color(0xFFCFFAFE);
      case 'IN_PROGRESS':
        return const Color(0xFFDBEAFE);
      case 'COMPLETED':
        return const Color(0xFFD1FAE5);
      case 'DELIVERED':
        return const Color(0xFFCCFBF1);
      case 'CANCELLED':
        return const Color(0xFFFFE4E6);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  static Color _getStatusBorderColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFDE68A);
      case 'WAITING_FOR_CHECK':
        return const Color(0xFFC7D2FE);
      case 'CHECKING':
        return const Color(0xFFE9D5FF);
      case 'CHECKED':
        return const Color(0xFFA5F3FC);
      case 'IN_PROGRESS':
        return const Color(0xFFBFDBFE);
      case 'COMPLETED':
        return const Color(0xFFA7F3D0);
      case 'DELIVERED':
        return const Color(0xFF99F6E4);
      case 'CANCELLED':
        return const Color(0xFFFECDD3);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  static IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'WAITING_FOR_CHECK':
        return LucideIcons.clock;
      case 'CHECKING':
        return LucideIcons.search;
      case 'CHECKED':
        return LucideIcons.checkCircle2;
      case 'IN_PROGRESS':
        return LucideIcons.wrench;
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
            // App Brand Logo
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    LucideIcons.wrench,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
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
          // Action Icon: Quick call technical support
          IconButton(
            tooltip: '$_hotlineLabel: $_hotlineNumber',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: const Icon(LucideIcons.phoneCall, size: 16, color: Color(0xFF059669)),
            ),
            onPressed: () => _makePhoneCall(_hotlineNumber),
          ),
          const SizedBox(width: 8),
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
      body: _buildCurrentBody(companyName, contactName, initials, user?.username, avatarUrl),
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
    final codeDisplay = customerCode.isNotEmpty ? customerCode : (username ?? 'Chưa cập nhật');

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
                // Top Row: Merged Single-Line Status Tag & VIP Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.crown, size: 11, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 5),
                      const Text(
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
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 1,
                        height: 10,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showProfileDialog(),
                                  child: Text(
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
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Action Button "Gọi kỹ thuật" tương phản cao trên nền navy (kính mờ + viền trắng)
                              InkWell(
                                onTap: () => _makePhoneCall(_hotlineNumber),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.phoneCall, size: 12, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text(
                                        'Gọi kỹ thuật',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: codeDisplay));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Đã sao chép mã khách hàng: #$codeDisplay'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
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
                                        const SizedBox(width: 5),
                                        Icon(
                                          LucideIcons.copy,
                                          size: 11,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (contactName.isNotEmpty && contactName != companyName) ...[
                            const SizedBox(height: 3),
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
                  ],
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
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = 'ALL'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedFilter == 'ALL'
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: _selectedFilter == 'ALL'
                                  ? Border.all(color: Colors.white.withValues(alpha: 0.4))
                                  : null,
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = 'COMPLETED'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedFilter == 'COMPLETED'
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: _selectedFilter == 'COMPLETED'
                                  ? Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6))
                                  : null,
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedFilter = 'IN_PROGRESS'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedFilter == 'IN_PROGRESS'
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: _selectedFilter == 'IN_PROGRESS'
                                  ? Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.6))
                                  : null,
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
          hintText: 'Tìm kiếm mã đơn, tên thiết bị hoặc số sê-ri...',
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

  // Unified Single-Row Horizontal Filter Chips
  Widget _buildFilterTabs() {
    final hasActiveSecondaryFilter = _selectedTimeFilter != 'ALL' || _selectedDeviceType != 'ALL';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('ALL', 'Tất cả (${_orders.length})', LucideIcons.layers, null),
          const SizedBox(width: 8),
          _buildFilterChip('IN_PROGRESS', 'Đang xử lý ($_inProgressCount)', LucideIcons.wrench, const Color(0xFFD97706)),
          const SizedBox(width: 8),
          _buildFilterChip('COMPLETED', 'Sẵn sàng nhận ($_completedCount)', LucideIcons.checkCircle, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildFilterChip('DELIVERED', 'Đã bàn giao ($_deliveredCount)', LucideIcons.packageCheck, const Color(0xFF0D9488)),
          const SizedBox(width: 8),
          _buildFilterChip('HISTORY', 'Lịch sử trả hàng', LucideIcons.archive, const Color(0xFF64748B)),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: _selectedTimeFilter == 'ALL' ? 'Thời gian' : _getTimeFilterLabel(_selectedTimeFilter),
            icon: LucideIcons.calendar,
            isActive: _selectedTimeFilter != 'ALL',
            onTap: _showTimeFilterPicker,
          ),
          const SizedBox(width: 8),
          _buildDropdownChip(
            label: _selectedDeviceType == 'ALL' ? 'Loại máy' : _selectedDeviceType,
            icon: LucideIcons.cpu,
            isActive: _selectedDeviceType != 'ALL',
            onTap: _showDeviceTypePicker,
          ),
          if (hasActiveSecondaryFilter) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _selectedTimeFilter = 'ALL';
                  _selectedDeviceType = 'ALL';
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.rotateCcw, size: 12, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text(
                      'Xóa lọc',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeFilterLabel(String key) {
    switch (key) {
      case '30_DAYS':
        return '30 ngày qua';
      case 'THIS_MONTH':
        return 'Tháng này';
      case '3_MONTHS':
        return '3 tháng qua';
      case 'THIS_YEAR':
        return 'Năm nay';
      default:
        return 'Tất cả thời gian';
    }
  }

  void _showTimeFilterPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Lọc theo khoảng thời gian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            _buildTimeOption(ctx, 'ALL', 'Tất cả thời gian'),
            _buildTimeOption(ctx, '30_DAYS', '30 ngày qua'),
            _buildTimeOption(ctx, 'THIS_MONTH', 'Trong tháng này'),
            _buildTimeOption(ctx, '3_MONTHS', '3 tháng qua'),
            _buildTimeOption(ctx, 'THIS_YEAR', 'Năm nay'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOption(BuildContext ctx, String key, String label) {
    final isSelected = _selectedTimeFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedTimeFilter = key);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceTypePicker() {
    final types = _availableDeviceTypes;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Lọc theo thiết bị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            _buildDeviceTypeOption(ctx, 'ALL', 'Tất cả thiết bị'),
            ...types.map((t) => _buildDeviceTypeOption(ctx, t, t)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeOption(BuildContext ctx, String key, String label) {
    final isSelected = _selectedDeviceType == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedDeviceType = key);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
    final orderTitle = _resolveOrderTitle(ord);
    final status = (ord['status'] ?? 'PENDING').toString();
    final friendlyStatus = _translateStatusToVietnamese(
      status,
      (ord['statusLabel'] ?? ord['friendlyStatus'])?.toString(),
    );
    final deviceCount = ord['deviceCount'] ?? ord['devicesCount'] ?? 1;
    final receivedRaw = (ord['receivedAt'] ?? ord['receivedDate'] ?? '').toString();
    final receivedDate = _formatVietnameseDate(receivedRaw);
    final estimatedRaw = (ord['estimatedDone'] ?? ord['expectedDeliveryDate'] ?? '').toString();
    final estimatedDate = _formatVietnameseDate(estimatedRaw);
    final serialNumber = (ord['serialNumber'] ?? '').toString().trim();
    final description = (ord['description'] ?? '').toString().trim();

    final isCompleted = status == 'COMPLETED' || status == 'DELIVERED';
    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusBorderColor = _getStatusBorderColor(status);
    final statusIcon = _getStatusIcon(status);
    final timelineStep = _getTimelineStep(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusBorderColor,
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
                color: statusColor,
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
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusBorderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
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
                      if (serialNumber.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Số sê-ri: ',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            Flexible(
                              child: Text(
                                serialNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (description.isNotEmpty && description != orderTitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tình trạng: $description',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Tags Row (Equipment count & Times)
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                          if (receivedDate.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.calendar, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  'Ngày nhận: $receivedDate',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          if (estimatedDate.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.clock, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  'Dự kiến: $estimatedDate',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5-Step Process Stepper (Stitch Design)
                      _buildMiniProgressTimeline(
                        timelineStep,
                        isCompleted: status == 'COMPLETED',
                        isDelivered: status == 'DELIVERED',
                      ),
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
                      if (isCompleted) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentNavIndex = 1;
                              _feedbackSelectedOrderCode = orderCode;
                              _feedbackType = 'SERVICE_QUALITY';
                              _feedbackViewMode = 'CREATE';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.star, size: 13, color: Color(0xFFD97706)),
                                SizedBox(width: 6),
                                Text(
                                  'Gửi phản hồi / Đánh giá chất lượng đơn này',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
  Widget _buildMiniProgressTimeline(
    int currentStep, {
    bool isCompleted = false,
    bool isDelivered = false,
  }) {
    final stages = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'Kiểm tra tải', 'Bàn giao'];
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
                isDelivered
                    ? 'đã bàn giao'
                    : (isCompleted ? 'đã kiểm tra tải' : 'bước ${currentStep + 1}/5'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: (isDelivered || isCompleted) ? const Color(0xFF059669) : const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stepper Nodes
          Row(
            children: List.generate(stages.length, (stepIdx) {
              final isDone = isDelivered || stepIdx < currentStep || (isCompleted && stepIdx <= 3);
              final isCurrent = !isDelivered && stepIdx == currentStep && !(isCompleted && stepIdx <= 3);

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
                                  : Text('${stepIdx + 1}',
                                      style: const TextStyle(
                                          fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
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
              _buildNavItem(1, LucideIcons.messageSquare, 'Phản hồi', () {
                setState(() => _currentNavIndex = 1);
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
              _buildNavItem(2, LucideIcons.shieldCheck, 'Bảo hành', () {
                setState(() => _currentNavIndex = 2);
              }),
              _buildNavItem(3, LucideIcons.circleHelp, 'Hỗ trợ', () {
                setState(() => _currentNavIndex = 3);
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


  // ==========================================================================
  // BODY SWITCHER & SUB-SCREENS (Orders, Feedback, Warranty, Support)
  // ==========================================================================

  Widget _buildCurrentBody(
    String companyName,
    String contactName,
    String initials,
    String? username,
    String? avatarUrl,
  ) {
    if (_currentNavIndex == 1) {
      return _buildFeedbackBody();
    }
    if (_currentNavIndex == 2) {
      return _buildWarrantyBody();
    }
    if (_currentNavIndex == 3) {
      return _buildSupportBody();
    }
    return _buildOrdersBody(companyName, contactName, initials, username, avatarUrl);
  }

  // 1. Orders Body
  Widget _buildOrdersBody(
    String companyName,
    String contactName,
    String initials,
    String? username,
    String? avatarUrl,
  ) {
    return RefreshIndicator(
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
          // VIP MEMBERSHIP CARD
          _buildVipMembershipCard(companyName, contactName, initials, username, avatarUrl),
          const SizedBox(height: 16),

          // SEARCH BAR & QUICK FILTERS
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterTabs(),
          const SizedBox(height: 16),

          // SECTION HEADER
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

          // ORDER LIST / EMPTY STATE / LOADING
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

          // PRIMARY CTA BANNER
          _buildFastSupportBanner(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 2. Feedback Body
  Widget _buildFeedbackBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchOrders(),
          _fetchMyFeedbacks(),
        ]);
      },
      color: const Color(0xFF2563EB),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          _buildFeedbackHeaderBanner(),
          const SizedBox(height: 16),
          _buildFeedbackTabSwitcher(),
          const SizedBox(height: 16),
          if (_feedbackViewMode == 'CREATE')
            _buildFeedbackCreateForm()
          else
            _buildFeedbackHistoryList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeedbackHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phản hồi & Đánh giá dịch vụ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Ý kiến của Quý khách là kim chỉ nam để LikeNew không ngừng nâng cao chất lượng.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _feedbackViewMode = 'CREATE'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _feedbackViewMode == 'CREATE' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _feedbackViewMode == 'CREATE'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.messageSquarePlus,
                      size: 16,
                      color: _feedbackViewMode == 'CREATE' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Gửi phản hồi mới',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _feedbackViewMode == 'CREATE' ? FontWeight.bold : FontWeight.w600,
                        color: _feedbackViewMode == 'CREATE' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _feedbackViewMode = 'HISTORY'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _feedbackViewMode == 'HISTORY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _feedbackViewMode == 'HISTORY'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.history,
                      size: 16,
                      color: _feedbackViewMode == 'HISTORY' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lịch sử phản hồi (${_myFeedbacks.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _feedbackViewMode == 'HISTORY' ? FontWeight.bold : FontWeight.w600,
                        color: _feedbackViewMode == 'HISTORY' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Phân loại phản hồi
        const Text(
          '1. Mục đích phản hồi*',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildFeedbackTypeCard(
              type: 'SERVICE_QUALITY',
              title: 'Đánh giá',
              subtitle: 'Chất lượng đơn',
              icon: LucideIcons.star,
              activeColor: const Color(0xFFEAB308),
            ),
            const SizedBox(width: 8),
            _buildFeedbackTypeCard(
              type: 'WARRANTY_ISSUE',
              title: 'Khiếu nại',
              subtitle: 'Bảo hành / Lỗi lại',
              icon: LucideIcons.alertTriangle,
              activeColor: const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            _buildFeedbackTypeCard(
              type: 'SUGGESTION',
              title: 'Góp ý',
              subtitle: 'Cải tiến dịch vụ',
              icon: LucideIcons.lightbulb,
              activeColor: const Color(0xFF3B82F6),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 2. Chọn đơn hàng liên quan
        const Text(
          '2. Chọn đơn hàng sửa chữa liên quan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _feedbackSelectedOrderCode,
              hint: const Text('Chọn đơn hàng (hoặc ý kiến chung)', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Ý kiến chung (Không thuộc đơn cụ thể)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                ),
                ..._orders.map((o) {
                  final code = (o['orderCode'] ?? '').toString();
                  final title = _resolveOrderTitle(o);
                  return DropdownMenuItem<String>(
                    value: code,
                    child: Text(
                      '$code - $title',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _feedbackSelectedOrderCode = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 3. Đánh giá số sao (Nếu không phải Góp ý thuần)
        if (_feedbackType != 'SUGGESTION') ...[
          const Text(
            '3. Mức độ hài lòng của Quý khách*',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _feedbackRating = star),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          LucideIcons.star,
                          size: 36,
                          color: star <= _feedbackRating ? const Color(0xFFEAB308) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  _getRatingLabel(_feedbackRating),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getRatingColor(_feedbackRating),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 4. Thẻ đánh giá nhanh
        Text(
          _feedbackType == 'SERVICE_QUALITY'
              ? '4. Điểm Quý khách ấn tượng nhất'
              : (_feedbackType == 'WARRANTY_ISSUE'
                  ? '4. Vấn đề thiết bị đang gặp phải*'
                  : '3. Chủ đề đóng góp ý kiến*'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getTagsForFeedbackType(_feedbackType).map((tag) {
            final isSelected = _feedbackSelectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _feedbackSelectedTags.add(tag);
                  } else {
                    _feedbackSelectedTags.remove(tag);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFDBEAFE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 5. Nội dung phản hồi chi tiết
        const Text(
          '5. Nội dung phản hồi / góp ý chi tiết*',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextFormField(
            controller: _feedbackContentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _feedbackType == 'SERVICE_QUALITY'
                  ? 'Chia sẻ trải nghiệm sửa chữa và vận hành thiết bị của Quý khách...'
                  : (_feedbackType == 'WARRANTY_ISSUE'
                      ? 'Mô tả chi tiết lỗi phát sinh, mã lỗi trên màn hình hoặc yêu cầu hỗ trợ...'
                      : 'Ý kiến đóng góp giúp cải tiến dịch vụ, quy trình hoặc phần mềm...'),
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 6. Đính kèm hình ảnh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '6. Đính kèm hình ảnh hiện trường (Tùy chọn)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Chụp ảnh',
                  icon: const Icon(LucideIcons.camera, size: 20, color: Color(0xFF2563EB)),
                  onPressed: () => _pickFeedbackImage(ImageSource.camera),
                ),
                IconButton(
                  tooltip: 'Chọn từ thư viện',
                  icon: const Icon(LucideIcons.image, size: 20, color: Color(0xFF2563EB)),
                  onPressed: () => _pickFeedbackImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
        if (_feedbackImages.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _feedbackImages.length,
              separatorBuilder: (_, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final file = _feedbackImages[i];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(file.path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _feedbackImages.removeAt(i));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 7. Yêu cầu khẩn cấp
        if (_feedbackType == 'WARRANTY_ISSUE') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _feedbackIsUrgent,
                  activeColor: const Color(0xFFDC2626),
                  onChanged: (v) => setState(() => _feedbackIsUrgent = v ?? false),
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yêu cầu kỹ sư gọi lại khẩn cấp',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                      Text(
                        'Đánh dấu nếu dây chuyền nhà máy đang ngừng trệ do thiết bị gặp sự cố.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const SizedBox(height: 10),
        ],

        // 8. Nút Gửi phản hồi
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSubmittingFeedback ? null : _submitFeedback,
            icon: _isSubmittingFeedback
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.send, size: 18),
            label: Text(
              _isSubmittingFeedback ? 'Đang gửi phản hồi...' : 'Gửi phản hồi ngay',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _feedbackType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _feedbackType = type;
            _feedbackSelectedTags.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isSelected ? activeColor : const Color(0xFF64748B)),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? activeColor.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
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

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return '🌟 Xuất sắc! Rất hài lòng';
      case 4:
        return '😊 Hài lòng, chất lượng tốt';
      case 3:
        return '😐 Bình thường / Tạm ổn';
      case 2:
        return '🙁 Chưa đạt kỳ vọng';
      case 1:
        return '😞 Rất không hài lòng';
      default:
        return 'Hài lòng';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return const Color(0xFF16A34A);
    if (rating == 3) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  List<String> _getTagsForFeedbackType(String type) {
    if (type == 'SERVICE_QUALITY') {
      return [
        'Sửa chữa nhanh chóng',
        'Máy chạy rất êm & ổn định',
        'Kỹ thuật nhiệt tình',
        'Đóng gói & Giao nhận chu đáo',
        'Báo giá minh bạch',
        'Tư vấn kỹ thuật chuẩn xác',
      ];
    }
    if (type == 'WARRANTY_ISSUE') {
      return [
        'Máy bị báo lỗi lại',
        'Quạt tản nhiệt kêu to',
        'Cần kỹ sư gọi lại gấp',
        'Cần căn chỉnh lại thông số',
        'Hư hại vỏ trong lúc vận chuyển',
        'Tem niêm phong có vấn đề',
      ];
    }
    return [
      'Thời gian báo giá nhanh hơn',
      'Đề xuất thêm tính năng app',
      'Quy trình giao nhận máy',
      'Chính sách giá linh kiện',
      'Bổ sung hướng dẫn cài đặt mã lỗi',
    ];
  }

  Future<void> _pickFeedbackImage(ImageSource source) async {
    try {
      final img = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (img != null) {
        setState(() {
          _feedbackImages.add(img);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _fetchMyFeedbacks() async {
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/feedbacks');
      if (!mounted) return;
      if (res is Map<String, dynamic> && res['content'] is List) {
        setState(() {
          _myFeedbacks = List<Map<String, dynamic>>.from(res['content'] as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _submitFeedback() async {
    final content = _feedbackContentController.text.trim();
    if (content.isEmpty && _feedbackSelectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFDC2626),
          content: Text('Vui lòng chọn đánh giá nhanh hoặc nhập nội dung phản hồi.'),
        ),
      );
      return;
    }

    setState(() => _isSubmittingFeedback = true);

    final selectedOrderModel = _feedbackSelectedOrderCode != null
        ? _orders
            .firstWhere(
              (o) => o['orderCode']?.toString() == _feedbackSelectedOrderCode,
              orElse: () => {},
            )['deviceName']
            ?.toString()
        : null;

    final api = context.read<AuthProvider>().api;
    try {
      final payload = {
        'orderCode': _feedbackSelectedOrderCode ?? 'Ý kiến chung',
        'deviceModel': selectedOrderModel,
        'rating': _feedbackRating,
        'type': _feedbackType,
        'typeName': _feedbackType == 'SERVICE_QUALITY'
            ? 'Đánh giá chất lượng'
            : (_feedbackType == 'WARRANTY_ISSUE' ? 'Khiếu nại / Bảo hành' : 'Đóng góp ý kiến'),
        'tags': _feedbackSelectedTags.toList(),
        'content': content,
        'isUrgent': _feedbackIsUrgent,
      };

      final res = await api.post('/api/v1/customer/feedbacks', body: payload);
      if (!mounted) return;

      if (res is Map<String, dynamic>) {
        setState(() {
          _myFeedbacks.insert(0, res);
        });
      } else {
        await _fetchMyFeedbacks();
      }

      if (!mounted) return;
      setState(() {
        _isSubmittingFeedback = false;
        _feedbackContentController.clear();
        _feedbackSelectedTags.clear();
        _feedbackImages.clear();
        _feedbackViewMode = 'HISTORY';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Gửi phản hồi thành công! Kỹ thuật LikeNew sẽ xử lý và liên hệ lại sớm nhất.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingFeedback = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Không thể gửi phản hồi: $e'),
        ),
      );
    }
  }

  Widget _buildFeedbackHistoryList() {
    if (_myFeedbacks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.messageSquare, size: 28, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chưa có phản hồi nào',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Các phản hồi, đánh giá và giải đáp của kỹ thuật viên sẽ được lưu trữ tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _feedbackViewMode = 'CREATE'),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Gửi phản hồi đầu tiên'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _myFeedbacks.map((fb) => _buildFeedbackHistoryCard(fb)).toList(),
    );
  }

  Widget _buildFeedbackHistoryCard(Map<String, dynamic> fb) {
    final status = (fb['status'] ?? 'PENDING').toString();
    final isResolved = status == 'RESOLVED';
    final isInProgress = status == 'IN_PROGRESS';
    final reply = fb['reply']?.toString();
    final rating = fb['rating'] as int? ?? 5;
    final tags = (fb['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);
    String statusText = 'Đã tiếp nhận';

    if (isResolved) {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF15803D);
      statusText = 'Đã giải quyết';
    } else if (isInProgress) {
      statusBg = const Color(0xFFDBEAFE);
      statusColor = const Color(0xFF1D4ED8);
      statusText = 'Đang xử lý';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fb['typeName'] ?? 'Phản hồi',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ),
                  if (fb['isUrgent'] == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('KHẨN CẤP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.receipt, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    fb['orderCode'] ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Text(
                fb['createdAt'] ?? '',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          if (fb['type'] != 'SUGGESTION') ...[
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  LucideIcons.star,
                  size: 16,
                  color: index < rating ? const Color(0xFFEAB308) : const Color(0xFFE2E8F0),
                );
              }),
            ),
          ],

          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ],

          if ((fb['content'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fb['content'] ?? '',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
          ],

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: reply != null ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      reply != null ? LucideIcons.messageSquareCheck : LucideIcons.clock,
                      size: 14,
                      color: reply != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      reply != null ? 'Bộ phận Kỹ thuật / CSKH LikeNew phản hồi:' : 'Đang chờ bộ phận kỹ thuật tiếp nhận...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: reply != null ? const Color(0xFF1E40AF) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (reply != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    reply,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.35),
                  ),
                  if (fb['replyAt'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      fb['replyAt'],
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Warranty Body
  Widget _buildWarrantyBody() {
    final underWarrantyOrders = _orders.where((o) {
      final isWarranty = o['underWarranty'] == true;
      final st = (o['status'] ?? '').toString().toUpperCase();
      return isWarranty || st == 'COMPLETED' || st == 'DELIVERED';
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchOrders();
      },
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sổ bảo hành điện tử',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tra cứu thời hạn bảo hành linh kiện và thiết bị sửa chữa tại LikeNew.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.info, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Chính sách bảo hành tiêu chuẩn',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Thời hạn bảo hành: 03 đến 06 tháng đối với linh kiện thay thế và bo mạch sửa chữa.\n'
                  '• Điều kiện: Tem niêm phong bảo hành của LikeNew còn nguyên vẹn, không bị rách vỡ.\n'
                  '• Hỗ trợ kỹ thuật: 24/7 qua Hotline kỹ thuật viên trưởng khi gặp sự cố tại nhà máy.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentNavIndex = 1;
                        _feedbackType = 'WARRANTY_ISSUE';
                        _feedbackViewMode = 'CREATE';
                      });
                    },
                    icon: const Icon(LucideIcons.alertTriangle, size: 15),
                    label: const Text('Báo sự cố bảo hành ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thiết bị trong thời hạn bảo hành (${underWarrantyOrders.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (underWarrantyOrders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Hiện chưa có thiết bị nào trong danh sách bảo hành.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            ...underWarrantyOrders.map((o) => _buildWarrantyOrderCard(o)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWarrantyOrderCard(Map<String, dynamic> ord) {
    final orderCode = ord['orderCode']?.toString() ?? '';
    final orderTitle = _resolveOrderTitle(ord);
    final serialNumber = (ord['serialNumber'] ?? '').toString().trim();
    final deliveredRaw = (ord['deliveredAt'] ?? ord['completedAt'] ?? ord['receivedAt'] ?? '').toString();
    final deliveredDate = _formatVietnameseDate(deliveredRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    orderCode,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Đang bảo hành',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            orderTitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          if (serialNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Số Serial: $serialNumber',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bàn giao: $deliveredDate',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0xFFEF4444),
                ),
                onPressed: () {
                  setState(() {
                    _currentNavIndex = 1;
                    _feedbackSelectedOrderCode = orderCode;
                    _feedbackType = 'WARRANTY_ISSUE';
                    _feedbackViewMode = 'CREATE';
                  });
                },
                child: const Text('Báo sự cố thiết bị', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Support Body
  Widget _buildSupportBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.phoneCall, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hỗ trợ Kỹ thuật & Tiếp nhận',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Đội ngũ kỹ sư LikeNew sẵn sàng hỗ trợ xử lý sự cố thiết bị 24/7.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hotlineLabel,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hotlineNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _makePhoneCall(_hotlineNumber),
                    icon: const Icon(LucideIcons.phoneCall, size: 16),
                    label: const Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Row(
                children: [
                  Icon(LucideIcons.clock, size: 15, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text('Giờ làm việc xưởng: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('08:00 - 18:00 (Thứ 2 - Thứ 7)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showSupportInfoSheet,
                  icon: const Icon(LucideIcons.circleHelp, size: 15),
                  label: const Text('Xem danh sách kênh liên hệ chi tiết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.mapPin, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Địa chỉ trung tâm kỹ thuật LikeNew',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      'Cơ sở TP.HCM',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _workshopAddress,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Tiếp nhận máy trực tiếp tại xưởng hoặc qua các dịch vụ chuyển phát nhanh (Viettel Post, GHTK, xe khách liên tỉnh).',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildWorkshopMapCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWorkshopMapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(LucideIcons.map, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bản đồ vị trí xưởng (Google Maps)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                InkWell(
                  onTap: () => _openGoogleMaps(directions: false),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mở toàn màn hình', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                        SizedBox(width: 4),
                        Icon(LucideIcons.externalLink, size: 12, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map interactive preview (Dark Google Maps aesthetic matching user screenshot)
          Material(
            color: const Color(0xFF171F2C),
            child: InkWell(
              onTap: () => _openGoogleMaps(directions: false),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  children: [
                    // Map Background Canvas or Custom Admin Map Image
                    if (_workshopMapImageUrl != null && _workshopMapImageUrl!.isNotEmpty)
                      Positioned.fill(
                        child: Image.network(
                          _workshopMapImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => CustomPaint(
                            painter: _WorkshopMapPainter(),
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _WorkshopMapPainter(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Details & Actions row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '243 QL1A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Khu phố 4, P. Tam Bình (giáp An Phú Đông), TP. Hồ Chí Minh',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Circular Directions button
                    Material(
                      color: const Color(0xFF2563EB),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _openGoogleMaps(directions: true),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(LucideIcons.navigation, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Circular Copy button
                    Material(
                      color: const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _copyWorkshopAddress,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(LucideIcons.copy, color: Color(0xFF475569), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _openGoogleMaps(directions: true),
                        icon: const Icon(LucideIcons.navigation, size: 16),
                        label: const Text(
                          'Chỉ đường',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openStreetView,
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: const Text(
                          'Xem phố',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  String _getStaffInitials(String name) {
    if (name.trim().isEmpty) return 'KT';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    final status = (_detail?['status'] ?? 'PENDING').toString();
    final friendlyStatus = _CustomerPortalMobilePageState._translateStatusToVietnamese(
      status,
      (_detail?['statusLabel'] ?? _detail?['friendlyStatus'])?.toString(),
    );
    final orderCode = _detail?['orderCode']?.toString() ?? '';
    final orderTitle = _detail != null
        ? _CustomerPortalMobilePageState._resolveOrderTitle(_detail!)
        : '';
    final orderDescription = (_detail?['description'] ?? '').toString().trim();
    final receivedDate = _CustomerPortalMobilePageState._formatVietnameseDate(
      (_detail?['receivedAt'] ?? _detail?['receivedDate'])?.toString(),
    );
    final estimatedDate = _CustomerPortalMobilePageState._formatVietnameseDate(
      (_detail?['estimatedDone'] ?? _detail?['expectedDeliveryDate'])?.toString(),
    );
    final completedDate = _CustomerPortalMobilePageState._formatVietnameseDate(
      _detail?['completedAt']?.toString(),
      includeTime: true,
    );
    final deliveredDate = _CustomerPortalMobilePageState._formatVietnameseDate(
      _detail?['deliveredAt']?.toString(),
      includeTime: true,
    );
    final underWarranty = _detail?['underWarranty'] == true;
    final assignedTechName = (_detail?['assignedTechnicianName'] ?? '').toString().trim();
    final assignedTechCode = (_detail?['assignedTechnicianCode'] ?? '').toString().trim();
    final receivedByName = (_detail?['receivedByName'] ?? '').toString().trim();
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
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _CustomerPortalMobilePageState._getStatusBgColor(status),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _CustomerPortalMobilePageState._getStatusBorderColor(status),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _CustomerPortalMobilePageState._getStatusIcon(status),
                                    size: 11,
                                    color: _CustomerPortalMobilePageState._getStatusColor(status),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      friendlyStatus,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: _CustomerPortalMobilePageState._getStatusColor(status),
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
                          _buildStepperCard(
                            status,
                            receivedDate: receivedDate,
                            completedDate: completedDate,
                            deliveredDate: deliveredDate,
                          ),
                          const SizedBox(height: 16),

                          // Order Metadata Summary Card from Database
                          if (receivedDate.isNotEmpty ||
                              estimatedDate.isNotEmpty ||
                              completedDate.isNotEmpty ||
                              deliveredDate.isNotEmpty ||
                              orderDescription.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Row(
                                          children: [
                                            Icon(LucideIcons.clipboardList, size: 15, color: Color(0xFF2563EB)),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Thông tin tiếp nhận',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                                          color: underWarranty ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          underWarranty ? 'Trong bảo hành' : 'Dịch vụ sửa chữa',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: underWarranty ? const Color(0xFF059669) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (receivedDate.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Ngày tiếp nhận: $receivedDate',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  if (estimatedDate.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Dự kiến hoàn thành: $estimatedDate',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  if (completedDate.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Ngày hoàn thành: $completedDate',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (deliveredDate.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Ngày bàn giao: $deliveredDate',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  if (orderDescription.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Ghi chú tình trạng: $orderDescription',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 2. Equipment Section
                          Row(
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
                          const SizedBox(height: 10),
                          ...devices.map((dev) {
                            final rawSerial = (dev['serialNumber'] ?? '').toString().trim();
                            final serial = rawSerial.isNotEmpty ? rawSerial : 'Chưa cập nhật';
                            final devName = (dev['deviceName'] ?? dev['modelName'] ?? '').toString().trim();
                            final devType = (dev['deviceType'] ?? dev['model'] ?? '').toString().trim();
                            final String devDisplayName;
                            if (devName.isNotEmpty) {
                              devDisplayName = (devType.isNotEmpty && !devName.toLowerCase().contains(devType.toLowerCase()))
                                  ? '$devName ($devType)'
                                  : devName;
                            } else if (devType.isNotEmpty) {
                              devDisplayName = devType;
                            } else {
                              devDisplayName = orderTitle.isNotEmpty ? orderTitle : 'Thiết bị sửa chữa';
                            }
                            final devStatus = (dev['status'] ?? status).toString();
                            final devStatusLabel = _CustomerPortalMobilePageState._translateStatusToVietnamese(
                              devStatus,
                              (dev['statusLabel'] ?? dev['friendlyStatus'])?.toString(),
                            );
                            final devIssue = (dev['description'] ?? dev['issueDescription'] ?? dev['symptom'] ?? '').toString().trim();
                            final devWarranty = dev['underWarranty'] == true;

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
                                                devDisplayName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  devStatusLabel,
                                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Text('Số sê-ri: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  serial,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF1E293B)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (rawSerial.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _copyToClipboard(rawSerial),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2),
                                                  child: Icon(LucideIcons.copy, size: 13, color: Color(0xFF2563EB)),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (devIssue.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tình trạng: $devIssue',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                          ),
                                        ],
                                        if (devWarranty) ...[
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Bảo hành: Thiết bị trong thời hạn bảo hành',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
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
                                Builder(
                                  builder: (context) {
                                    // Construct connected vertical timeline events from actual database records
                                    final List<Map<String, dynamic>> timelineEvents = [];

                                    // Event 1: Tiếp nhận đơn tại xưởng
                                    if (receivedDate.isNotEmpty) {
                                      timelineEvents.add({
                                        'title': 'Tiếp nhận thiết bị tại xưởng',
                                        'date': receivedDate,
                                        'message': orderDescription.isNotEmpty
                                            ? orderDescription
                                            : 'Tiếp nhận thiết bị, kiểm tra sơ bộ ngoại quan và lập phiếu kỹ thuật.',
                                        'actor': receivedByName.isNotEmpty
                                            ? 'Người tiếp nhận: $receivedByName'
                                            : (assignedTechName.isNotEmpty
                                                ? 'Tiếp nhận: $assignedTechName'
                                                : 'Chi nhánh Kỹ thuật Inverter Like-New'),
                                        'icon': LucideIcons.packageCheck,
                                        'color': const Color(0xFF2563EB),
                                      });
                                    }

                                    // Event 2..N: Updates from technical logs
                                    for (final up in updates) {
                                      final upTitle = (up['title'] ?? '').toString().trim();
                                      final upDate = _CustomerPortalMobilePageState._formatVietnameseDate(
                                        (up['publishedAt'] ?? up['createdAt'])?.toString(),
                                      );
                                      final upMessage = (up['message'] ?? up['content'] ?? '').toString().trim();
                                      final upActor = (up['author'] ?? up['authorName'] ?? up['staffName'])?.toString().trim();
                                      timelineEvents.add({
                                        'title': upTitle.isNotEmpty ? upTitle : 'Ghi nhận tiến độ kỹ thuật',
                                        'date': upDate,
                                        'message': upMessage,
                                        'actor': (upActor != null && upActor.isNotEmpty)
                                            ? 'KTV: $upActor'
                                            : (assignedTechName.isNotEmpty
                                                ? 'KTV: $assignedTechName'
                                                : 'Bộ phận Kỹ thuật & Đo kiểm'),
                                        'icon': LucideIcons.wrench,
                                        'color': const Color(0xFF10B981),
                                      });
                                    }

                                    // Milestone: Chạy thử tải & Nghiệm thu
                                    if ((status == 'COMPLETED' || status == 'DELIVERED') && completedDate.isNotEmpty) {
                                      final hasCompleted = updates.any((u) {
                                        final t = (u['title'] ?? '').toString().toLowerCase();
                                        return t.contains('hoàn thành') || t.contains('tải') || t.contains('nghiệm thu');
                                      });
                                      if (!hasCompleted) {
                                        timelineEvents.add({
                                          'title': 'Chạy thử tải 100% & Nghiệm thu xuất xưởng',
                                          'date': completedDate,
                                          'message': 'Đo xung PWM, kiểm tra dòng kích IGBT và thử tải công suất thực tế ổn định.',
                                          'actor': assignedTechName.isNotEmpty
                                              ? 'KTV nghiệm thu: $assignedTechName'
                                              : 'Phòng Đo kiểm & Nghiệm thu',
                                          'icon': LucideIcons.checkCircle2,
                                          'color': const Color(0xFF059669),
                                        });
                                      }
                                    }

                                    // Milestone: Bàn giao khách hàng
                                    if (status == 'DELIVERED' && deliveredDate.isNotEmpty) {
                                      final hasDelivered = updates.any((u) {
                                        final t = (u['title'] ?? '').toString().toLowerCase();
                                        return t.contains('bàn giao');
                                      });
                                      if (!hasDelivered) {
                                        timelineEvents.add({
                                          'title': 'Đã bàn giao cho khách hàng',
                                          'date': deliveredDate,
                                          'message': 'Thiết bị đã được bàn giao hoàn tất cho khách hàng kèm tem bảo hành kỹ thuật.',
                                          'actor': receivedByName.isNotEmpty
                                              ? 'Bàn giao: $receivedByName'
                                              : (assignedTechName.isNotEmpty
                                                  ? 'Bàn giao: $assignedTechName'
                                                  : 'Bộ phận Giao nhận & Khách hàng'),
                                          'icon': LucideIcons.badgeCheck,
                                          'color': const Color(0xFF0D9488),
                                        });
                                      }
                                    }

                                    if (timelineEvents.isEmpty) {
                                      return const Text(
                                        'Kỹ thuật viên đang kiểm tra và sẽ sớm cập nhật kết quả.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontStyle: FontStyle.italic),
                                      );
                                    }

                                    return Column(
                                      children: List.generate(timelineEvents.length, (idx) {
                                        final ev = timelineEvents[idx];
                                        final isLast = idx == timelineEvents.length - 1;
                                        final evTitle = ev['title'] as String;
                                        final evDate = ev['date'] as String;
                                        final evMessage = ev['message'] as String;
                                        final evActor = ev['actor'] as String;
                                        final evIcon = ev['icon'] as IconData;
                                        final evColor = ev['color'] as Color;

                                        return IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Connected Timeline Rail
                                              SizedBox(
                                                width: 24,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: evColor.withValues(alpha: 0.12),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: evColor, width: 2),
                                                      ),
                                                      child: Center(
                                                        child: Icon(evIcon, size: 10, color: evColor),
                                                      ),
                                                    ),
                                                    if (!isLast)
                                                      Expanded(
                                                        child: Container(
                                                          width: 2,
                                                          color: const Color(0xFFE2E8F0),
                                                          margin: const EdgeInsets.symmetric(vertical: 3),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),

                                              // Event Details
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              evTitle,
                                                              style: const TextStyle(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF1E293B),
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (evDate.isNotEmpty) ...[
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              evDate,
                                                              style: const TextStyle(
                                                                fontSize: 10.5,
                                                                color: Color(0xFF94A3B8),
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if (evMessage.isNotEmpty) ...[
                                                        const SizedBox(height: 3),
                                                        Text(
                                                          evMessage,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFF475569),
                                                            height: 1.35,
                                                          ),
                                                        ),
                                                      ],
                                                      if (evActor.isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            const Icon(LucideIcons.userCheck, size: 11, color: Color(0xFF64748B)),
                                                            const SizedBox(width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                evActor,
                                                                style: const TextStyle(
                                                                  fontSize: 10.5,
                                                                  color: Color(0xFF64748B),
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),

                                // Real Technician / Receiver Profile Box from Database (only if assigned/recorded)
                                if (assignedTechName.isNotEmpty || receivedByName.isNotEmpty) ...[
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
                                        child: Center(
                                          child: Text(
                                            _getStaffInitials(assignedTechName.isNotEmpty ? assignedTechName : receivedByName),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              assignedTechName.isNotEmpty
                                                  ? 'Kỹ thuật viên: $assignedTechName'
                                                  : 'Người tiếp nhận: $receivedByName',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (assignedTechCode.isNotEmpty)
                                              Text(
                                                'Mã nhân sự: $assignedTechCode',
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            else if (assignedTechName.isNotEmpty && receivedByName.isNotEmpty)
                                              Text(
                                                'Tiếp nhận bởi: $receivedByName',
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 4. Evidence Media Photos (Hình ảnh kiểm tra & Đo đạc)
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
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.camera,
                                      size: 22,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Kỹ thuật viên sẽ cập nhật ảnh sau khi đo kiểm',
                                    style: TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Hình ảnh bo mạch, xung kích IGBT và tem kiểm định tải sẽ xuất hiện tại đây khi nghiệm thu.',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              height: 120,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: media.map((med) {
                                  final rawUrl = med['mediaUrl']?.toString() ?? med['fileUrl']?.toString() ?? '';
                                  final caption = (med['caption'] ?? '').toString().trim();
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
                                          if (caption.isNotEmpty)
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                color: Colors.black54,
                                                child: Text(
                                                  caption,
                                                  style: const TextStyle(fontSize: 9, color: Colors.white),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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

          // Sticky Footer Actions (1 Contact Method: Phone Call)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => widget.onMakeCall(widget.hotlineNumber),
                icon: const Icon(LucideIcons.phoneCall, size: 16),
                label: Text(
                  'Liên hệ kỹ thuật (${widget.hotlineNumber})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5-Stage Stepper Card inside Sheet (Stitch Screen 2)
  Widget _buildStepperCard(
    String status, {
    String receivedDate = '',
    String completedDate = '',
    String deliveredDate = '',
  }) {
    final isDelivered = status == 'DELIVERED';
    final isCompleted = status == 'COMPLETED';
    final currentStep = _getStepIndex(status);
    final steps = ['Tiếp nhận', 'Kiểm tra', 'Sửa chữa', 'Kiểm tra tải', 'Bàn giao'];
    final deliveryTime = deliveredDate.isNotEmpty ? deliveredDate : completedDate;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'TIẾN TRÌNH KỸ THUẬT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? const Color(0xFFECFDF5)
                        : (isCompleted ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDelivered
                          ? const Color(0xFFA7F3D0)
                          : (isCompleted ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDelivered ? LucideIcons.checkCheck : LucideIcons.clock,
                        size: 11,
                        color: isDelivered ? const Color(0xFF059669) : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isDelivered
                              ? 'Đã bàn giao'
                              : (isCompleted ? 'Đã nghiệm thu tải' : 'Bước ${currentStep + 1}/5'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDelivered
                                ? const Color(0xFF065F46)
                                : (isCompleted ? const Color(0xFF1D4ED8) : const Color(0xFF475569)),
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
          const SizedBox(height: 14),
          Row(
            children: List.generate(steps.length, (stepIdx) {
              final isDone = isDelivered || stepIdx < currentStep || (isCompleted && stepIdx <= 3);
              final isCurrent = !isDelivered && stepIdx == currentStep && !(isCompleted && stepIdx <= 3);

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
                                  : Text('${stepIdx + 1}',
                                      style: const TextStyle(
                                          fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
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
                    if (stepIdx == 0 && receivedDate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        receivedDate,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (stepIdx == 4 && isDelivered && deliveryTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        deliveryTime,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _WorkshopMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF171F2C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // River (Sông Sài Gòn) on top-right corner
    final riverPaint = Paint()
      ..color = const Color(0xFF133854)
      ..style = PaintingStyle.fill;
    final riverPath = Path()
      ..moveTo(size.width * 0.72, 0)
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.25,
        size.width * 0.85,
        size.height * 0.45,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    // Sông Sài Gòn label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Sông Sài Gòn',
        style: TextStyle(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
          fontSize: 9.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(size.width * 0.81, 14);
    canvas.rotate(0.35);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Local road lines (Dark grey-blue)
    final minorRoadPaint = Paint()
      ..color = const Color(0xFF26354A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Cross roads
    // 1. Vo Thi Thua
    canvas.drawLine(
      Offset(size.width * 0.60, 0),
      Offset(size.width * 0.56, size.height * 0.44),
      minorRoadPaint,
    );
    // 2. An Phu Dong 3
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.43),
      Offset(size.width * 0.82, size.height),
      minorRoadPaint,
    );
    // 3. To 46 KP3
    canvas.drawLine(
      Offset(size.width * 0.65, size.height * 0.43),
      Offset(size.width * 0.72, size.height * 0.30),
      minorRoadPaint,
    );
    // 4. Đường nội QL1
    canvas.drawLine(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.35, size.height * 0.44),
      minorRoadPaint,
    );
    // 5. Vuon Lai / internal road
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.45),
      Offset(size.width * 0.10, size.height),
      minorRoadPaint,
    );
    // 6. Secondary horizontal connecting roads
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width * 0.55, size.height * 0.72),
      minorRoadPaint,
    );

    // Main Highway: QL1A (Running slightly angled horizontally across the canvas)
    final ql1aBasePaint = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final ql1aCenterPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final ql1aStart = Offset(0, size.height * 0.43);
    final ql1aEnd = Offset(size.width, size.height * 0.37);

    canvas.drawLine(ql1aStart, ql1aEnd, ql1aBasePaint);
    canvas.drawLine(ql1aStart, ql1aEnd, ql1aCenterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
