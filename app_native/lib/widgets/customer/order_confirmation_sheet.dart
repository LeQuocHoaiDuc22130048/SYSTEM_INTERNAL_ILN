import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../utils/api_client.dart';
import '../../utils/auth_provider.dart';

/// Displays the two-step customer repair order quotation confirmation and
/// bank transfer payment proof upload bottom sheet modal.
class OrderConfirmationSheet extends StatefulWidget {
  const OrderConfirmationSheet({
    super.key,
    required this.orderId,
    required this.orderDetail,
    required this.hotlineNumber,
    required this.onMakeCall,
    this.imagePicker,
  });

  final String orderId;
  final Map<String, dynamic> orderDetail;
  final String hotlineNumber;
  final Future<void> Function(String) onMakeCall;
  final ImagePicker? imagePicker;

  @override
  State<OrderConfirmationSheet> createState() => _OrderConfirmationSheetState();
}

class _QuoteLineItem {
  const _QuoteLineItem({required this.label, required this.amount});

  final String label;
  final int amount;
}

class _SelectedProofFile {
  const _SelectedProofFile({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

class _OrderConfirmationSheetState extends State<OrderConfirmationSheet> {
  static const Color _navyPrimary = Color(0xFF25437A);
  static const Color _navyDark = Color(0xFF1A2F57);
  static const Color _navyDarker = Color(0xFF16284A);
  static const Color _navySoft = Color(0xFFEEF2F8);
  static const int _extendedWarrantyFee = 500000;
  static const int _maxProofBytes = 10 * 1024 * 1024;

  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  int _step = 0; // 0 = Báo giá & Xác nhận dịch vụ, 1 = Xác nhận & Thanh toán
  bool _paymentAccordionExpanded = true;

  String _confirmationStatus = 'PENDING_CUSTOMER';
  int _selectedWarrantyMonths = 6;
  int _baseAmount = 0;
  List<String> _diagnosisTags = const [];
  List<_QuoteLineItem> _quoteItems = const [];

  String _bankName = 'MB Bank (Quân Đội)';
  String _bankCode = 'MB';
  String _accountNumber = '9964266771';
  String _accountHolder = 'CONG TY TNHH KY THUAT CONG NGHE';
  String _transferContent = '';

  String? _uploadedProofFileName;
  _SelectedProofFile? _selectedProof;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initFromOrderDetail();
    _loadConfirmation();
  }

  void _initFromOrderDetail() {
    final detail = widget.orderDetail;
    final rawDesc = (detail['description'] ?? '').toString().trim();
    if (rawDesc.isNotEmpty) {
      _diagnosisTags = rawDesc
          .split(RegExp(r'[,;\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final orderCode = _orderCode;
    final serial = _serialNumber;
    _transferContent = serial.isNotEmpty && orderCode.isNotEmpty
        ? '$orderCode - $serial'
        : orderCode;
  }

  Future<void> _loadConfirmation() async {
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customer/orders/${widget.orderId}/confirmation');
      if (!mounted) return;
      final data = _unwrapData(res);
      if (data != null) {
        _applyConfirmationPayload(data);
      }
    } catch (_) {
      // Keep graceful defaults derived from order detail if confirmation API is unavailable.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic>? _unwrapData(dynamic res) {
    if (res is Map<String, dynamic>) {
      if (res['data'] is Map<String, dynamic>) {
        return res['data'] as Map<String, dynamic>;
      }
      return res;
    }
    return null;
  }

  void _applyConfirmationPayload(Map<String, dynamic> data) {
    final status = data['confirmationStatus']?.toString();
    final warrantyMonths = int.tryParse(data['warrantyMonths']?.toString() ?? '');
    final baseAmount = int.tryParse(data['baseAmount']?.toString() ?? '');
    final rawTags = data['diagnosisTags'];
    final rawItems = data['quoteItems'];

    setState(() {
      if (status != null && status.isNotEmpty) {
        _confirmationStatus = status;
      }
      if (warrantyMonths == 6 || warrantyMonths == 12) {
        _selectedWarrantyMonths = warrantyMonths!;
      }
      if (baseAmount != null && baseAmount >= 0) {
        _baseAmount = baseAmount;
      }
      if (rawTags is List && rawTags.isNotEmpty) {
        _diagnosisTags = rawTags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (rawItems is List) {
        _quoteItems = rawItems
            .whereType<Map>()
            .map((m) => _QuoteLineItem(
                  label: (m['label'] ?? '').toString(),
                  amount: int.tryParse((m['amount'] ?? 0).toString()) ?? 0,
                ))
            .where((item) => item.label.isNotEmpty)
            .toList();
      }
      if ((data['bankName'] ?? '').toString().trim().isNotEmpty) {
        _bankName = data['bankName'].toString().trim();
      }
      if ((data['bankCode'] ?? '').toString().trim().isNotEmpty) {
        _bankCode = data['bankCode'].toString().trim();
      }
      if ((data['accountNumber'] ?? '').toString().trim().isNotEmpty) {
        _accountNumber = data['accountNumber'].toString().trim();
      }
      if ((data['accountHolder'] ?? '').toString().trim().isNotEmpty) {
        _accountHolder = data['accountHolder'].toString().trim();
      }
      if ((data['transferContent'] ?? '').toString().trim().isNotEmpty) {
        _transferContent = data['transferContent'].toString().trim();
      }
      final proofName = (data['paymentProofFileName'] ?? '').toString().trim();
      if (proofName.isNotEmpty) {
        _uploadedProofFileName = proofName;
      }
    });
  }

  String get _orderCode => (widget.orderDetail['orderCode'] ?? '').toString().trim();

  String get _deviceName {
    final direct = (widget.orderDetail['deviceName'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final devices = widget.orderDetail['devices'];
    if (devices is List && devices.isNotEmpty && devices.first is Map) {
      final firstName = (devices.first['deviceName'] ?? '').toString().trim();
      if (firstName.isNotEmpty) return firstName;
    }
    return (widget.orderDetail['orderTitle'] ?? 'Thiết bị sửa chữa').toString().trim();
  }

  String get _serialNumber {
    final direct = (widget.orderDetail['serialNumber'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final devices = widget.orderDetail['devices'];
    if (devices is List && devices.isNotEmpty && devices.first is Map) {
      return (devices.first['serialNumber'] ?? '').toString().trim();
    }
    return '';
  }

  String get _customerName {
    final name = (widget.orderDetail['customerName'] ?? '').toString().trim();
    return name.isNotEmpty ? name : 'Khách hàng';
  }

  int get _warrantyExtraFee => _selectedWarrantyMonths == 12 ? _extendedWarrantyFee : 0;

  int get _totalAmount => _baseAmount + _warrantyExtraFee;

  String get _vietQrPayload {
    final memo = _transferContent.isNotEmpty ? _transferContent : _orderCode;
    return 'VIETQR|$_bankCode|$_accountNumber|$_totalAmount|$memo';
  }

  static String formatVnd(int amount) {
    final formatted = amount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
    return '$formatted đ';
  }

  static String formatVndNumber(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    final kb = (bytes / 1024).clamp(1, 1024).round();
    return '$kb KB';
  }

  void _copyText(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $value'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickProofImage(ImageSource source, {bool advanceToPayment = false}) async {
    if (_submitting) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() => _errorMessage = 'Tệp ảnh trống. Vui lòng chọn ảnh khác.');
        return;
      }
      if (bytes.lengthInBytes > _maxProofBytes) {
        setState(() => _errorMessage = 'Dung lượng ảnh chứng từ tối đa 10MB.');
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      setState(() {
        _errorMessage = null;
        _selectedProof = _SelectedProofFile(
          name: picked.name.isNotEmpty ? picked.name : 'chung-tu-thanh-toan.jpg',
          bytes: bytes,
          contentType: contentType,
        );
        if (advanceToPayment) {
          _step = 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể truy cập ảnh. Vui lòng thử lại.');
    }
  }

  Future<void> _handleApproveQuote() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.post(
        '/api/v1/customer/orders/${widget.orderId}/confirm',
        body: {
          'action': 'APPROVE',
          'warrantyMonths': _selectedWarrantyMonths,
        },
      );
      final data = _unwrapData(res);
      if (!mounted) return;
      if (data != null) {
        _applyConfirmationPayload(data);
      }
      setState(() {
        _confirmationStatus = 'APPROVED';
        _submitting = false;
        _step = 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Không thể gửi xác nhận báo giá. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _handleRejectQuote() async {
    if (_submitting) return;
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Từ chối báo giá sửa chữa?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kỹ thuật viên sẽ liên hệ lại để hỗ trợ phương án phù hợp hơn cho Quý khách.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                TextField(
                  maxLines: 2,
                  onChanged: (value) => reason = value,
                  decoration: InputDecoration(
                    hintText: 'Lý do từ chối (không bắt buộc)',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );

    reason = reason.trim();
    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final api = context.read<AuthProvider>().api;
    try {
      await api.post(
        '/api/v1/customer/orders/${widget.orderId}/confirm',
        body: {
          'action': 'REJECT',
          if (reason.isNotEmpty) 'rejectionReason': reason,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi phản hồi từ chối báo giá. Kỹ thuật viên sẽ liên hệ lại.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Không thể gửi phản hồi từ chối. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _handleSubmitPaymentProof() async {
    if (_submitting) return;
    if (_selectedProof == null) {
      setState(() {
        _errorMessage = 'Vui lòng tải lên ảnh chứng từ / ủy nhiệm chi trước khi gửi.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.postMultipart(
        '/api/v1/customer/orders/${widget.orderId}/payment-proof',
        fields: {
          'warrantyMonths': _selectedWarrantyMonths.toString(),
          if (_transferContent.isNotEmpty) 'transferReference': _transferContent,
        },
        filename: _selectedProof!.name,
        bytes: _selectedProof!.bytes,
        contentType: _selectedProof!.contentType,
      );
      final data = _unwrapData(res);
      if (!mounted) return;
      if (data != null) {
        _applyConfirmationPayload(data);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi chứng từ xác nhận thanh toán thành công!'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Không thể tải lên chứng từ thanh toán. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.92;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _navyPrimary))
                : _step == 0
                    ? _buildStepOneBody()
                    : _buildStepTwoBody(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isPaymentStep = _step == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _navySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaymentStep ? LucideIcons.creditCard : LucideIcons.fileText,
              size: 19,
              color: _navyPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaymentStep
                      ? 'Xác nhận & Thanh toán đơn hàng'
                      : 'Báo giá & Xác nhận dịch vụ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPaymentStep
                      ? 'Chuyển khoản thanh toán và tải lên biên lai / ảnh xác nhận'
                      : 'Xem xét và duyệt phương án sửa chữa kỹ thuật',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepOneBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _buildErrorBanner(_errorMessage!),
            const SizedBox(height: 12),
          ],
          _buildDeviceSummaryCard(),
          const SizedBox(height: 14),
          _buildDiagnosisAndCostCard(),
          const SizedBox(height: 14),
          _buildWarrantySelector(),
          const SizedBox(height: 14),
          _buildTotalSummaryBanner(),
          const SizedBox(height: 14),
          _buildCollapsiblePaymentCard(),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Kỹ thuật viên sẽ lập tức kích hoạt đơn hàng & tiến hành thay thế linh kiện ngay khi nhận được xác nhận đồng ý của Quý khách.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.45),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDeviceSummaryCard() {
    final statusBadge = _statusBadgeMeta(_confirmationStatus);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(LucideIcons.cpu, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _deviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (_customerName.isNotEmpty)
                            TextSpan(
                              text: ' ($_customerName)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Mã đơn: ',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _navySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _orderCode.isNotEmpty ? _orderCode : widget.orderId,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _navyPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBadge.$2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBadge.$3),
                ),
                child: Text(
                  statusBadge.$1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusBadge.$4,
                  ),
                ),
              ),
            ],
          ),
          if (_serialNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số Sê-ri (S/N):',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _serialNumber,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _copyText(_serialNumber, 'S/N'),
                        child: const Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (String, Color, Color, Color) _statusBadgeMeta(String status) {
    switch (status) {
      case 'APPROVED':
        return (
          'Đã duyệt báo giá',
          const Color(0xFFEEF2F8),
          const Color(0xFFBFDBFE),
          _navyPrimary,
        );
      case 'PAYMENT_SUBMITTED':
        return (
          'Đã gửi chứng từ',
          const Color(0xFFECFDF5),
          const Color(0xFFA7F3D0),
          const Color(0xFF047857),
        );
      case 'REJECTED':
        return (
          'Đã từ chối',
          const Color(0xFFFFF1F2),
          const Color(0xFFFECDD3),
          const Color(0xFFBE123C),
        );
      default:
        return (
          'Chờ khách duyệt',
          const Color(0xFFFEF3C7),
          const Color(0xFFFDE68A),
          const Color(0xFF92400E),
        );
    }
  }

  Widget _buildDiagnosisAndCostCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 14, color: Color(0xFFF43F5E)),
              SizedBox(width: 6),
              Text(
                'LỖI KỸ THUẬT CHẨN ĐOÁN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_diagnosisTags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _diagnosisTags.asMap().entries.map((entry) {
                final palette = entry.key % 3 == 0
                    ? (const Color(0xFFFFF1F2), const Color(0xFFBE123C), const Color(0xFFFECDD3))
                    : entry.key % 3 == 1
                        ? (const Color(0xFFFFF7ED), const Color(0xFFC2410C), const Color(0xFFFED7AA))
                        : (const Color(0xFFFEF2F2), const Color(0xFF991B1B), const Color(0xFFFECACA));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.$1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.$3),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: palette.$2,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            const Text(
              'Kỹ thuật viên đang cập nhật chẩn đoán chi tiết từ bàn kiểm tra.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                if (_quoteItems.isNotEmpty) ...[
                  ..._quoteItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatVnd(item.amount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Chi phí dự kiến:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatVnd(_baseAmount),
                      key: const ValueKey('quote_subtotal_text'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _navyPrimary,
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

  Widget _buildWarrantySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHỌN GÓI THỜI HẠN BẢO HÀNH:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildWarrantyOptionCard(
                  cardKey: const ValueKey('warranty_option_6m'),
                  months: 6,
                  title: 'Bảo hành 6 tháng',
                  subtitle: 'Gói tiêu chuẩn',
                  priceLabel: 'Đã bao gồm',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWarrantyOptionCard(
                  cardKey: const ValueKey('warranty_option_12m'),
                  months: 12,
                  title: 'Bảo hành 1 năm',
                  subtitle: 'Bảo vệ toàn diện linh kiện',
                  priceLabel: '+500.000 đ',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarrantyOptionCard({
    required Key cardKey,
    required int months,
    required String title,
    required String subtitle,
    required String priceLabel,
  }) {
    final selected = _selectedWarrantyMonths == months;
    return InkWell(
      key: cardKey,
      onTap: () => setState(() => _selectedWarrantyMonths = months),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _navySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _navyPrimary : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected ? _navyPrimary : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: selected ? _navyPrimary : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? _navyPrimary : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              priceLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? _navyPrimary : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSummaryBanner() {
    final warrantySubtitle = _selectedWarrantyMonths == 12
        ? 'Gói mở rộng: Bảo hành 1 năm toàn diện'
        : 'Gói bảo hành 6 tháng tiêu chuẩn';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navyPrimary, _navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x3325437A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TỔNG THANH TOÁN BÁO GIÁ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  warrantySubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE2E8F0),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatVnd(_totalAmount),
            key: const ValueKey('quote_final_total_text'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsiblePaymentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _paymentAccordionExpanded = !_paymentAccordionExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _navySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.creditCard, size: 15, color: _navyPrimary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin & Mã QR chuyển khoản',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Quét mã nhanh qua VietQR 24/7',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _paymentAccordionExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_paymentAccordionExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildResponsiveQrAndBankSection(
                    qrLabel: 'VIETQR TỰ ĐỘNG',
                    bankDetails: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ngân hàng:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          _bankName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Số tài khoản:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          _accountNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _navyPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Chủ tài khoản:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          _accountHolder,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Nội dung chuyển:', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            _transferContent,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Đã chuyển khoản xong?',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _pickProofImage(
                          ImageSource.gallery,
                          advanceToPayment: true,
                        ),
                        icon: const Icon(LucideIcons.image, size: 14, color: _navyPrimary),
                        label: const Text(
                          'Tải ảnh ủy nhiệm chi',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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

  Widget _buildStepTwoBody() {
    final warrantyShort = _selectedWarrantyMonths == 12 ? '1 năm' : '6 tháng';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_navyPrimary, _navyDarker],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x3325437A), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ĐÃ DUYỆT BÁO GIÁ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_orderCode.isNotEmpty ? _orderCode : widget.orderId} · $_deviceName',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Khách hàng: $_customerName (Gói BH $warrantyShort)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'SỐ TIỀN THANH TOÁN',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatVndNumber(_totalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'đ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildStepTwoBankCard(),
        const SizedBox(height: 14),
        _buildUploadProofCard(),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Hệ thống kỹ thuật sẽ đối soát chứng từ và xác nhận tiến độ sửa chữa cho Quý khách trong vòng 5-10 phút.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.45),
          ),
        ),
        const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStepTwoBankCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _navySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.qrCode, size: 15, color: _navyPrimary),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'MÃ QR & CHUYỂN KHOẢN NGÂN HÀNG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _navySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navyPrimary.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Napas247 Tự động',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _navyPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _buildResponsiveQrAndBankSection(
            qrLabel: 'Quét mã VietQR 24/7',
            bankDetails: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ngân hàng:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _bankName,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text('Số tài khoản:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _accountNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _navyPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          key: const ValueKey('copy_account_number_btn'),
                          onTap: () => _copyText(_accountNumber, 'số tài khoản'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(LucideIcons.copy, size: 13, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chủ tài khoản:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _accountHolder,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text('Nội dung CK:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Bắt buộc chính xác',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _transferContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        key: const ValueKey('copy_transfer_content_btn'),
                        onTap: () => _copyText(_transferContent, 'nội dung CK'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.copy, size: 13, color: Color(0xFF92400E)),
                            SizedBox(width: 3),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
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
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProofCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _navySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.image, size: 15, color: _navyPrimary),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'TẢI LÊN ẢNH CHỨNG TỪ THANH TOÁN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '* Bắt buộc',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE11D48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _navyPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _navyPrimary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _navySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.cloudUpload, size: 20, color: _navyPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tải lên ảnh chụp màn hình / biên lai chuyển khoản',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hỗ trợ định dạng JPG, PNG (tối đa 10MB)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('pick_proof_gallery_btn'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickProofImage(ImageSource.gallery),
                      icon: const Icon(LucideIcons.image, size: 14, color: _navyPrimary),
                      label: const Text(
                        'Chọn từ thư viện',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('pick_proof_camera_btn'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _pickProofImage(ImageSource.camera),
                      icon: const Icon(LucideIcons.camera, size: 14, color: _navyPrimary),
                      label: const Text(
                        'Chụp ảnh ngay',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedProof != null || _uploadedProofFileName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _navySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _navyPrimary.withValues(alpha: 0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedProof != null
                        ? Image.memory(
                            _selectedProof!.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              LucideIcons.circleCheck,
                              size: 20,
                              color: _navyPrimary,
                            ),
                          )
                        : const Icon(
                            LucideIcons.circleCheck,
                            size: 20,
                            color: _navyPrimary,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProof?.name ?? _uploadedProofFileName ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedProof != null
                              ? '${_formatFileSize(_selectedProof!.bytes.lengthInBytes)} · Đã sẵn sàng tải lên'
                              : 'Chứng từ đã gửi trước đó',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _navyPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedProof != null)
                    IconButton(
                      key: const ValueKey('remove_proof_btn'),
                      tooltip: 'Xóa ảnh',
                      onPressed: () => setState(() => _selectedProof = null),
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveQrAndBankSection({
    required String qrLabel,
    required Widget bankDetails,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildQrBox(label: qrLabel)),
              const SizedBox(height: 12),
              bankDetails,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQrBox(label: qrLabel),
            const SizedBox(width: 12),
            Expanded(child: bankDetails),
          ],
        );
      },
    );
  }

  Widget _buildQrBox({required String label}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _navyPrimary.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        children: [
          QrImageView(
            data: _vietQrPayload,
            version: QrVersions.auto,
            size: 104,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _navyPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleAlert, size: 16, color: Color(0xFFE11D48)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBE123C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isPaymentStep = _step == 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    key: ValueKey(isPaymentStep ? 'confirm_back_btn' : 'quote_reject_btn'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isPaymentStep ? Colors.white : const Color(0xFFFFF1F2),
                      foregroundColor: isPaymentStep ? const Color(0xFF334155) : const Color(0xFFBE123C),
                      side: BorderSide(
                        color: isPaymentStep ? const Color(0xFFE2E8F0) : const Color(0xFFFECDD3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting
                        ? null
                        : isPaymentStep
                            ? () => setState(() {
                                  _errorMessage = null;
                                  _step = 0;
                                })
                            : _handleRejectQuote,
                    icon: Icon(
                      isPaymentStep ? LucideIcons.arrowLeft : LucideIcons.x,
                      size: 16,
                    ),
                    label: Text(
                      isPaymentStep ? 'Quay lại' : 'Từ chối',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 8,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    key: ValueKey(isPaymentStep ? 'submit_payment_proof_btn' : 'quote_approve_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navyPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting
                        ? null
                        : isPaymentStep
                            ? _handleSubmitPaymentProof
                            : _handleApproveQuote,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(LucideIcons.check, size: 17),
                    label: Text(
                      isPaymentStep ? 'Gửi chứng từ xác nhận' : 'Đồng ý & Bắt đầu sửa',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => widget.onMakeCall(widget.hotlineNumber),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.phone, size: 13, color: _navyPrimary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: isPaymentStep
                            ? 'Cần hỗ trợ? Hotline: '
                            : 'Cần trao đổi thêm? Hotline Kỹ thuật: ',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(
                            text: widget.hotlineNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
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
    );
  }
}
