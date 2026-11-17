import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/repair_quotation.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/media_auth_headers.dart';

Future<void> showCustomerQuotationSheet({
  required BuildContext context,
  required RepairQuotationModel quotation,
  required String hotlineNumber,
  String? initialOrderId,
  Future<void> Function(String phone)? onMakeCall,
  required void Function(RepairQuotationModel updated) onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomerQuotationSheet(
      quotation: quotation,
      hotlineNumber: hotlineNumber,
      initialOrderId: initialOrderId,
      onMakeCall: onMakeCall,
      onUpdated: onUpdated,
    ),
  );
}

class CustomerQuotationSheet extends StatefulWidget {
  final RepairQuotationModel quotation;
  final String hotlineNumber;
  final String? initialOrderId;
  final Future<void> Function(String phone)? onMakeCall;
  final void Function(RepairQuotationModel updated) onUpdated;

  const CustomerQuotationSheet({
    super.key,
    required this.quotation,
    required this.hotlineNumber,
    this.initialOrderId,
    this.onMakeCall,
    required this.onUpdated,
  });

  @override
  State<CustomerQuotationSheet> createState() => _CustomerQuotationSheetState();
}

class _CustomerQuotationSheetState extends State<CustomerQuotationSheet> {
  static const Color _navy = Color(0xFF143266);

  late RepairQuotationModel _quotation;
  late String _step; // 'REVIEW' | 'PAYMENT'
  int _activeIndex = 0;

  final Map<String, String> _selectedWarranties = {};
  final Map<String, String> _decisions = {}; // 'APPROVED' | 'REJECTED'
  final Map<String, TextEditingController> _rejectReasonCtrls = {};

  bool _submittingDecision = false;
  String? _errorMsg;

  // Screen 2 payment proof upload state
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _proofNoteCtrl = TextEditingController();
  String? _pickedFileName;
  Uint8List? _pickedBytes;
  String? _pickedContentType;
  bool _uploadingProof = false;
  String? _proofSuccessMsg;

  @override
  void initState() {
    super.initState();
    _quotation = widget.quotation;
    final canPayAlready =
        (_quotation.status == 'APPROVED' ||
            _quotation.status == 'PARTIAL_APPROVED') &&
        _quotation.totalApprovedAmount > 0;
    _step = canPayAlready ? 'PAYMENT' : 'REVIEW';

    if (widget.initialOrderId != null) {
      final idx = _quotation.items.indexWhere(
        (i) => i.repairOrderId == widget.initialOrderId,
      );
      if (idx >= 0) _activeIndex = idx;
    }

    _syncDraftSelectionsFromQuotation();
  }

  void _syncDraftSelectionsFromQuotation() {
    for (final item in _quotation.items) {
      _selectedWarranties.putIfAbsent(item.repairOrderId, () {
        if (item.selectedWarrantyCode != null &&
            item.selectedWarrantyCode!.isNotEmpty) {
          return item.selectedWarrantyCode!;
        }
        return item.warrantyOptions.isNotEmpty
            ? item.warrantyOptions.first.code
            : '6M';
      });
      _decisions.putIfAbsent(item.repairOrderId, () {
        if (item.decision == 'APPROVED' || item.decision == 'REJECTED') {
          return item.decision;
        }
        return 'APPROVED';
      });
      _rejectReasonCtrls.putIfAbsent(
        item.repairOrderId,
        () => TextEditingController(text: item.rejectReason ?? ''),
      );
    }
  }

  @override
  void dispose() {
    _proofNoteCtrl.dispose();
    for (final c in _rejectReasonCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isPendingResponse => _quotation.status == 'SENT';
  bool get _isMultiDevice => _quotation.items.length > 1;

  WarrantyOptionModel? _selectedWarrantyFor(QuotationItemModel item) {
    final code = _selectedWarranties[item.repairOrderId];
    for (final opt in item.warrantyOptions) {
      if (opt.code == code) return opt;
    }
    return item.warrantyOptions.isNotEmpty ? item.warrantyOptions.first : null;
  }

  double _itemTotalFor(QuotationItemModel item) {
    if (!_isPendingResponse) return item.finalAmount;
    final opt = _selectedWarrantyFor(item);
    return item.baseCost + (opt?.fee ?? 0);
  }

  double get _computedApprovedTotal {
    if (!_isPendingResponse) return _quotation.totalApprovedAmount;
    double sum = 0;
    for (final item in _quotation.items) {
      if ((_decisions[item.repairOrderId] ?? 'APPROVED') == 'APPROVED') {
        sum += _itemTotalFor(item);
      }
    }
    return sum;
  }

  int get _approvedCount {
    if (!_isPendingResponse) {
      return _quotation.items.where((i) => i.decision == 'APPROVED').length;
    }
    return _quotation.items
        .where((i) => (_decisions[i.repairOrderId] ?? 'APPROVED') == 'APPROVED')
        .length;
  }

  void _copyText(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $value'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitDecisions({String? singleDeviceDecision}) async {
    if (_submittingDecision) return;
    setState(() {
      _submittingDecision = true;
      _errorMsg = null;
    });

    try {
      final api = context.read<AuthProvider>().api;
      final payloadItems = _quotation.items.map((item) {
        final decision = !_isMultiDevice && singleDeviceDecision != null
            ? singleDeviceDecision
            : (_decisions[item.repairOrderId] ?? 'APPROVED');
        final reason = _rejectReasonCtrls[item.repairOrderId]?.text.trim();
        return {
          'repairOrderId': item.repairOrderId,
          'decision': decision,
          'selectedWarrantyCode':
              decision == 'APPROVED' ? _selectedWarranties[item.repairOrderId] : null,
          'rejectReason':
              decision == 'REJECTED' && reason != null && reason.isNotEmpty
                  ? reason
                  : null,
        };
      }).toList();

      final res = await api.post(
        '/api/v1/customer/quotations/${_quotation.id}/respond',
        body: {'items': payloadItems},
      );

      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final updated = RepairQuotationModel.fromJson(res);
        setState(() {
          _quotation = updated;
          _submittingDecision = false;
          if (updated.totalApprovedAmount > 0 &&
              (updated.status == 'APPROVED' ||
                  updated.status == 'PARTIAL_APPROVED')) {
            _step = 'PAYMENT';
          }
        });
        widget.onUpdated(updated);
        if (updated.status == 'REJECTED' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã ghi nhận phản hồi từ chối báo giá.')),
          );
          Navigator.pop(context);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _submittingDecision = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Không thể gửi xác nhận. Vui lòng thử lại.';
        _submittingDecision = false;
      });
    }
  }

  Future<void> _confirmSingleRejectDialog() async {
    final item = _quotation.items[_activeIndex];
    final ctrl = _rejectReasonCtrls[item.repairOrderId] ?? TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Từ chối sửa chữa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn chắc chắn muốn từ chối phương án sửa chữa cho thiết bị này?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối (tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Quay lại'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _submitDecisions(singleDeviceDecision: 'REJECTED');
    }
  }

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final lower = picked.name.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      setState(() {
        _pickedFileName = picked.name;
        _pickedBytes = bytes;
        _pickedContentType = mime;
        _errorMsg = null;
      });
    } catch (_) {
      setState(() {
        _errorMsg = 'Không thể chọn ảnh chứng từ.';
      });
    }
  }

  Future<void> _pickProofFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      if (file.bytes == null) return;
      final ext = (file.extension ?? '').toLowerCase();
      final mime = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';
      setState(() {
        _pickedFileName = file.name;
        _pickedBytes = file.bytes;
        _pickedContentType = mime;
        _errorMsg = null;
      });
    } catch (_) {
      setState(() {
        _errorMsg = 'Không thể chọn tệp chứng từ.';
      });
    }
  }

  Future<void> _uploadPaymentProof() async {
    if (_pickedBytes == null || _pickedFileName == null || _uploadingProof) {
      return;
    }
    setState(() {
      _uploadingProof = true;
      _errorMsg = null;
      _proofSuccessMsg = null;
    });

    try {
      final api = context.read<AuthProvider>().api;
      final fields = <String, String>{
        'amount': _quotation.totalApprovedAmount.round().toString(),
        if (_proofNoteCtrl.text.trim().isNotEmpty)
          'note': _proofNoteCtrl.text.trim(),
      };
      final res = await api.postMultipart(
        '/api/v1/customer/quotations/${_quotation.id}/payment-proofs',
        fields: fields,
        filename: _pickedFileName!,
        bytes: _pickedBytes!,
        contentType: _pickedContentType,
      );

      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final updated = RepairQuotationModel.fromJson(res);
        setState(() {
          _quotation = updated;
          _pickedBytes = null;
          _pickedFileName = null;
          _proofNoteCtrl.clear();
          _uploadingProof = false;
          _proofSuccessMsg =
              'Đã tải lên chứng từ thanh toán! Kỹ thuật & kế toán sẽ đối soát sớm.';
        });
        widget.onUpdated(updated);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _uploadingProof = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Tải lên chứng từ thất bại. Vui lòng thử lại.';
        _uploadingProof = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.94),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_step == 'REVIEW' &&
              (_quotation.status == 'APPROVED' ||
                  _quotation.status == 'PARTIAL_APPROVED'))
            _buildSwitchToPaymentBanner(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _step == 'REVIEW'
                  ? _buildReviewScreen()
                  : _buildPaymentScreen(),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isReview = _step == 'REVIEW';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Icon(
              isReview ? LucideIcons.fileText : LucideIcons.qrCode,
              size: 20,
              color: _navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReview
                      ? 'Báo giá & Xác nhận dịch vụ'
                      : 'Xác nhận thanh toán & Chứng từ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReview
                      ? 'Xem xét và duyệt phương án sửa chữa (${_quotation.quoteCode})'
                      : 'Quét mã VietQR hoặc tải lên ảnh chuyển khoản (${_quotation.quoteCode})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (!isReview && _quotation.items.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _step = 'REVIEW'),
              child: const Text(
                'Xem báo giá',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchToPaymentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFECFDF5),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bạn đã duyệt phương án sửa chữa.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _step = 'PAYMENT'),
            child: const Text('Mở thanh toán QR →'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewScreen() {
    if (_quotation.items.isEmpty) {
      return const Center(child: Text('Không có thiết bị nào trong báo giá.'));
    }
    final activeItem = _quotation.items[_activeIndex];
    final currentDecision = _isPendingResponse
        ? (_decisions[activeItem.repairOrderId] ?? 'APPROVED')
        : activeItem.decision;
    final selectedWarranty = _selectedWarrantyFor(activeItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMsg != null) ...[
          _buildAlertBox(_errorMsg!, isError: true),
          const SizedBox(height: 12),
        ],

        // MULTI-DEVICE PILL TABS (Shown when >= 2 orders)
        if (_isMultiDevice) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THIẾT BỊ TRONG BÁO GIÁ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFF475569),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Đồng ý $_approvedCount/${_quotation.items.length} máy',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quotation.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final it = _quotation.items[idx];
                final isSelected = idx == _activeIndex;
                final dec = _isPendingResponse
                    ? (_decisions[it.repairOrderId] ?? 'APPROVED')
                    : it.decision;
                final isApproved = dec == 'APPROVED';
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) => setState(() => _activeIndex = idx),
                  selectedColor: _navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? _navy : const Color(0xFFCBD5E1),
                  ),
                  avatar: Icon(
                    isApproved ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                    size: 15,
                    color: isSelected
                        ? Colors.white
                        : (isApproved
                            ? const Color(0xFF059669)
                            : const Color(0xFFE11D48)),
                  ),
                  label: Text(
                    'Máy ${idx + 1}: ${it.deviceName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // DEVICE SUMMARY CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.cpu, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activeItem.deviceName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            _buildStatusPill(
                              _isPendingResponse
                                  ? 'Chờ khách duyệt'
                                  : activeItem.decisionLabel,
                              isApproved: currentDecision == 'APPROVED' && !_isPendingResponse,
                              isRejected: currentDecision == 'REJECTED',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Mã đơn: ',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                activeItem.orderCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
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
              if (activeItem.serialNumber != null &&
                  activeItem.serialNumber!.isNotEmpty) ...[
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Số Sê-ri (S/N):',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    InkWell(
                      onTap: () => _copyText(activeItem.serialNumber!, 'Serial'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeItem.serialNumber!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.copy, size: 13, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DIAGNOSED ERRORS + BREAKDOWN CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeItem.diagnosedErrors.isNotEmpty) ...[
                const Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Text(
                      'LỖI KỸ THUẬT CHẨN ĐOÁN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeItem.diagnosedErrors.map((err) {
                    final sev = err.severity.toUpperCase();
                    final isMedium = sev == 'MEDIUM';
                    final bg = isMedium
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFFEE2E2);
                    final fg = isMedium
                        ? const Color(0xFFB45309)
                        : const Color(0xFFB91C1C);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        err.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ...activeItem.lineItems.map(
                      (li) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                li.quantity > 1
                                    ? '${li.description} (x${li.quantity}):'
                                    : '${li.description}:',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            Text(
                              formatVnd(li.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chi phí dự kiến:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          formatVnd(activeItem.baseCost),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _navy,
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
        const SizedBox(height: 14),

        // WARRANTY SELECTION
        const Text(
          'CHỌN GÓI THỜI HẠN BẢO HÀNH:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: activeItem.warrantyOptions.map((opt) {
            final isSelected = selectedWarranty?.code == opt.code;
            final enabled = _isPendingResponse;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: opt == activeItem.warrantyOptions.last ? 0 : 8,
                ),
                child: InkWell(
                  onTap: enabled
                      ? () => setState(() {
                            _selectedWarranties[activeItem.repairOrderId] =
                                opt.code;
                          })
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? _navy : const Color(0xFFCBD5E1),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? _navy : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                        if (opt.description != null &&
                            opt.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            opt.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          opt.fee <= 0
                              ? 'Đã bao gồm'
                              : '+${formatVnd(opt.fee)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: opt.fee <= 0
                                ? const Color(0xFF059669)
                                : _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // PER-DEVICE DECISION SWITCH (Multi-device mode)
        if (_isMultiDevice) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUYẾT ĐỊNH CHO THIẾT BỊ NÀY:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: currentDecision == 'APPROVED'
                              ? const Color(0xFFECFDF5)
                              : Colors.white,
                          foregroundColor: currentDecision == 'APPROVED'
                              ? const Color(0xFF065F46)
                              : const Color(0xFF475569),
                          side: BorderSide(
                            color: currentDecision == 'APPROVED'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: _isPendingResponse
                            ? () => setState(() {
                                  _decisions[activeItem.repairOrderId] = 'APPROVED';
                                })
                            : null,
                        icon: const Icon(LucideIcons.check, size: 15),
                        label: const Text('Đồng ý sửa'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: currentDecision == 'REJECTED'
                              ? const Color(0xFFFFF1F2)
                              : Colors.white,
                          foregroundColor: currentDecision == 'REJECTED'
                              ? const Color(0xFFBE123C)
                              : const Color(0xFF475569),
                          side: BorderSide(
                            color: currentDecision == 'REJECTED'
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: _isPendingResponse
                            ? () => setState(() {
                                  _decisions[activeItem.repairOrderId] = 'REJECTED';
                                })
                            : null,
                        icon: const Icon(LucideIcons.x, size: 15),
                        label: const Text('Từ chối sửa'),
                      ),
                    ),
                  ],
                ),
                if (currentDecision == 'REJECTED' && _isPendingResponse) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rejectReasonCtrls[activeItem.repairOrderId],
                    decoration: const InputDecoration(
                      hintText: 'Lý do từ chối thiết bị này (tùy chọn)...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (currentDecision == 'REJECTED' &&
                    !_isPendingResponse &&
                    activeItem.rejectReason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Lý do từ chối: ${activeItem.rejectReason}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // STICKY DARK-NAVY TOTAL SUMMARY BAR (Matching Stitch Screen 1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(16),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMultiDevice
                          ? 'Đã chọn $_approvedCount/${_quotation.items.length} thiết bị đồng ý sửa'
                          : (selectedWarranty != null &&
                                    selectedWarranty.description != null
                                ? '${selectedWarranty.label} ${selectedWarranty.description!.toLowerCase()}'
                                : selectedWarranty?.label ?? 'Gói tiêu chuẩn'),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Text(
                formatVnd(_computedApprovedTotal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentScreen() {
    final bank = _quotation.bankInfo;
    final transferContent = bank?.transferContent ?? _quotation.quoteCode;
    final transferAmount =
        (bank?.transferAmount ?? _quotation.totalApprovedAmount) > 0
            ? (bank?.transferAmount ?? _quotation.totalApprovedAmount)
            : _quotation.totalApprovedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMsg != null) ...[
          _buildAlertBox(_errorMsg!, isError: true),
          const SizedBox(height: 12),
        ],
        if (_proofSuccessMsg != null) ...[
          _buildAlertBox(_proofSuccessMsg!, isError: false),
          const SizedBox(height: 12),
        ],

        // APPROVED IN-PROGRESS INFO BANNER
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.wrench, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã xác nhận sửa $_approvedCount/${_quotation.items.length} thiết bị (trạng thái Đang sửa). Bạn có thể chuyển khoản & tải chứng từ ngay hoặc nhấn "Thanh toán sau" bên dưới.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // VIETQR + BANK INFO CARD
        if (bank != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (bank.vietQrPayload.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
                    ),
                    child: QrImageView(
                      data: bank.vietQrPayload,
                      version: QrVersions.auto,
                      size: 190,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Quét mã VietQR bằng ứng dụng Ngân hàng',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const Divider(height: 22, color: Color(0xFFF1F5F9)),
                ],
                _buildBankRow('Ngân hàng', bank.bankName),
                _buildBankRow(
                  'Số tài khoản',
                  bank.bankAccountNumber,
                  canCopy: true,
                ),
                _buildBankRow('Chủ tài khoản', bank.bankAccountHolder),
                _buildBankRow('Số tiền', formatVnd(transferAmount), bold: true),
                _buildBankRow(
                  'Nội dung CK',
                  transferContent,
                  canCopy: true,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // UPLOAD PAYMENT PROOF CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TẢI LÊN CHỨNG TỪ CHUYỂN KHOẢN (TÙY CHỌN)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickProofImage(ImageSource.gallery),
                      icon: const Icon(LucideIcons.image, size: 16),
                      label: const Text('Thư viện ảnh'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickProofFile,
                      icon: const Icon(LucideIcons.paperclip, size: 16),
                      label: const Text('Chọn file / PDF'),
                    ),
                  ),
                ],
              ),
              if (_pickedBytes != null && _pickedFileName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileCheck, size: 18, color: _navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pickedFileName!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _pickedBytes = null;
                          _pickedFileName = null;
                        }),
                        icon: const Icon(LucideIcons.x, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _proofNoteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ghi chú (tên người chuyển, ngân hàng...)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _uploadingProof ? null : _uploadPaymentProof,
                    icon: _uploadingProof
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.upload, size: 16),
                    label: Text(
                      _uploadingProof ? 'Đang tải lên...' : 'Gửi chứng từ xác nhận',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // PAYMENT PROOFS HISTORY
        if (_quotation.paymentProofs.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'LỊCH SỬ CHỨNG TỪ ĐÃ TẢI LÊN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          ..._quotation.paymentProofs.map((proof) {
            final isVerified = proof.status == 'VERIFIED';
            final isRejected = proof.status == 'REJECTED';
            final api = context.read<AuthProvider>().api;
            final resolvedUrl = api.resolveUrl(proof.proofFileUrl);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  if (!proof.proofFileUrl.toLowerCase().endsWith('.pdf'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        resolvedUrl,
                        headers: mediaAuthHeaders(context, resolvedUrl),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          LucideIcons.image,
                          size: 26,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  else
                    const Icon(LucideIcons.fileText, size: 32, color: _navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatVnd(proof.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            _buildStatusPill(
                              proof.statusLabel.isNotEmpty
                                  ? proof.statusLabel
                                  : proof.status,
                              isApproved: isVerified,
                              isRejected: isRejected,
                            ),
                          ],
                        ),
                        if (proof.note != null && proof.note!.isNotEmpty)
                          Text(
                            proof.note!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                          ),
                        if (proof.rejectionReason != null &&
                            proof.rejectionReason!.isNotEmpty)
                          Text(
                            'Lý do từ chối: ${proof.rejectionReason}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildBankRow(
    String label,
    String value, {
    bool canCopy = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _copyText(value, label.toLowerCase()),
              child: const Icon(LucideIcons.copy, size: 14, color: Color(0xFF2563EB)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_step == 'REVIEW' && _isPendingResponse) ...[
            if (!_isMultiDevice)
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                        backgroundColor: const Color(0xFFFFF1F2),
                        side: const BorderSide(color: Color(0xFFFECDD3)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submittingDecision
                          ? null
                          : _confirmSingleRejectDialog,
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text(
                        'Từ chối',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 7,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submittingDecision
                          ? null
                          : () => _submitDecisions(singleDeviceDecision: 'APPROVED'),
                      icon: _submittingDecision
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.check, size: 17),
                      label: const Text(
                        'Đồng ý & Bắt đầu sửa',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submittingDecision ? null : () => _submitDecisions(),
                  icon: _submittingDecision
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.checkCircle2, size: 17),
                  label: Text(
                    'Xác nhận phương án ($_approvedCount máy đồng ý)',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ] else if (_step == 'PAYMENT') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Thanh toán sau / Đóng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.onMakeCall != null
                ? () => widget.onMakeCall!(widget.hotlineNumber)
                : () => _copyText(widget.hotlineNumber, 'Hotline'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.phoneCall, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Cần trao đổi thêm? Hotline Kỹ thuật: ',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Text(
                  widget.hotlineNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(
    String text, {
    bool isApproved = false,
    bool isRejected = false,
  }) {
    final bg = isApproved
        ? const Color(0xFFD1FAE5)
        : isRejected
            ? const Color(0xFFFFE4E6)
            : const Color(0xFFFEF3C7);
    final fg = isApproved
        ? const Color(0xFF065F46)
        : isRejected
            ? const Color(0xFFBE123C)
            : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildAlertBox(String message, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isError ? const Color(0xFFBE123C) : const Color(0xFF065F46),
        ),
      ),
    );
  }
}

