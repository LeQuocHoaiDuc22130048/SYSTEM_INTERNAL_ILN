import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/repair_order.dart';
import '../models/repair_quotation.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/media_auth_headers.dart';

class StaffOrderQuotationCard extends StatefulWidget {
  final RepairOrder order;
  final VoidCallback? onOrderStatusChanged;

  const StaffOrderQuotationCard({
    super.key,
    required this.order,
    this.onOrderStatusChanged,
  });

  @override
  State<StaffOrderQuotationCard> createState() =>
      _StaffOrderQuotationCardState();
}

class _StaffOrderQuotationCardState extends State<StaffOrderQuotationCard> {
  static const Color _navy = Color(0xFF143266);

  bool _loading = true;
  bool _actionLoading = false;
  List<RepairQuotationModel> _quotations = [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get(
        '/api/v1/repair-quotations/by-order/${widget.order.id}',
      );
      if (!mounted) return;
      final list = res is List
          ? res
              .whereType<Map<String, dynamic>>()
              .map(RepairQuotationModel.fromJson)
              .toList()
          : <RepairQuotationModel>[];
      setState(() {
        _quotations = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Không thể tải báo giá cho đơn này.';
        _loading = false;
      });
    }
  }

  RepairQuotationModel? get _activeQuotation {
    if (_quotations.isEmpty) return null;
    for (final q in _quotations) {
      if (q.status != 'CANCELLED' && q.status != 'REJECTED') {
        return q;
      }
    }
    return _quotations.first;
  }

  Future<void> _sendQuotation(RepairQuotationModel quotation) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/api/v1/repair-quotations/${quotation.id}/send');
      await _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi báo giá ${quotation.quoteCode} cho khách.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelQuotation(RepairQuotationModel quotation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Hủy báo giá'),
        content: Text('Hủy báo giá ${quotation.quoteCode}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: const Text('Hủy báo giá'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/api/v1/repair-quotations/${quotation.id}/cancel');
      await _loadQuotations();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _verifyProof(PaymentProofModel proof, bool approved) async {
    String? rejectReason;
    if (!approved) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: const Text('Từ chối chứng từ'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      rejectReason = ctrl.text.trim();
    }

    setState(() => _actionLoading = true);
    try {
      final api = context.read<AuthProvider>().api;
      await api.post(
        '/api/v1/repair-quotations/payment-proofs/${proof.id}/verify',
        body: {
          'approved': approved,
          if (rejectReason != null && rejectReason.isNotEmpty)
            'rejectionReason': rejectReason,
        },
      );
      await _loadQuotations();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _openCreateModal() async {
    if (widget.order.customerId == null || widget.order.customerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng liên kết khách hàng với đơn hàng trước khi tạo báo giá.'),
        ),
      );
      return;
    }

    final created = await showModalBottomSheet<RepairQuotationModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffCreateQuotationSheet(order: widget.order),
    );
    if (created != null && mounted) {
      await _loadQuotations();
      widget.onOrderStatusChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeQuotation;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileSpreadsheet, size: 17, color: _navy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Báo giá & Thanh toán khách hàng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (active == null ||
                  active.status == 'CANCELLED' ||
                  active.status == 'REJECTED')
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _loading ? null : _openCreateModal,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text(
                    'Tạo báo giá',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorMsg != null)
            Text(
              _errorMsg!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
            )
          else if (active == null)
            const Text(
              'Chưa có báo giá nào cho đơn này. Nhấn "Tạo báo giá" để lập chi phí và ghép nhiều máy của cùng khách hàng (nếu có).',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            )
          else
            _buildQuotationDetails(active),
        ],
      ),
    );
  }

  Widget _buildQuotationDetails(RepairQuotationModel q) {
    final api = context.read<AuthProvider>().api;
    final statusColor = switch (q.status) {
      'APPROVED' => const Color(0xFF059669),
      'PARTIAL_APPROVED' => const Color(0xFF0284C7),
      'SENT' => const Color(0xFFD97706),
      'REJECTED' || 'CANCELLED' => const Color(0xFFE11D48),
      _ => const Color(0xFF475569),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                q.quoteCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                q.statusLabel.isNotEmpty ? q.statusLabel : q.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const Spacer(),
            Text(
              formatVnd(
                q.totalApprovedAmount > 0
                    ? q.totalApprovedAmount
                    : q.totalEstimatedAmount,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...q.items.map((it) {
          final isCurrent = it.repairOrderId == widget.order.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.white : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${it.orderCode} • ${it.deviceName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${it.decisionLabel}${it.selectedWarrantyLabel != null ? ' • ${it.selectedWarrantyLabel}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatVnd(it.finalAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        }),

        if (q.status == 'DRAFT' || q.status == 'SENT') ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (q.status == 'DRAFT')
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _actionLoading ? null : () => _sendQuotation(q),
                    icon: const Icon(LucideIcons.send, size: 14),
                    label: const Text('Gửi khách hàng'),
                  ),
                ),
              if (q.status == 'DRAFT') const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _actionLoading ? null : () => _cancelQuotation(q),
                child: const Text('Hủy báo giá'),
              ),
            ],
          ),
        ],

        if (q.paymentProofs.isNotEmpty) ...[
          const Divider(height: 16),
          const Text(
            'Chứng từ thanh toán từ khách:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          ...q.paymentProofs.map((proof) {
            final url = api.resolveUrl(proof.proofFileUrl);
            final isPending = proof.status == 'PENDING_VERIFY';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          url,
                          headers: mediaAuthHeaders(context, url),
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(LucideIcons.fileText, size: 24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatVnd(proof.amount)} • ${proof.statusLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (proof.note != null && proof.note!.isNotEmpty)
                              Text(
                                proof.note!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _actionLoading
                                ? null
                                : () => _verifyProof(proof, true),
                            child: const Text('Xác nhận đã nhận tiền'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE11D48),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _actionLoading
                              ? null
                              : () => _verifyProof(proof, false),
                          child: const Text('Từ chối'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _DraftLineRow {
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController(text: '0');

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _DraftDeviceForm {
  final String repairOrderId;
  final String orderCode;
  final String deviceName;
  final TextEditingController errorsCtrl = TextEditingController();
  final List<_DraftLineRow> lines = [_DraftLineRow()];
  bool include6M = true;
  bool include12M = true;

  _DraftDeviceForm({
    required this.repairOrderId,
    required this.orderCode,
    required this.deviceName,
  });

  void dispose() {
    errorsCtrl.dispose();
    for (final l in lines) {
      l.dispose();
    }
  }
}

class StaffCreateQuotationSheet extends StatefulWidget {
  final RepairOrder order;

  const StaffCreateQuotationSheet({super.key, required this.order});

  @override
  State<StaffCreateQuotationSheet> createState() =>
      _StaffCreateQuotationSheetState();
}

class _StaffCreateQuotationSheetState extends State<StaffCreateQuotationSheet> {
  static const Color _navy = Color(0xFF143266);

  bool _loadingOrders = true;
  bool _submitting = false;
  String? _error;
  List<PendingQuotationOrderModel> _mergeCandidates = [];
  final Map<String, _DraftDeviceForm> _forms = {};

  @override
  void initState() {
    super.initState();
    _forms[widget.order.id] = _DraftDeviceForm(
      repairOrderId: widget.order.id,
      orderCode: widget.order.orderNumber,
      deviceName: widget.order.deviceName,
    );
    _loadPendingOrders();
  }

  @override
  void dispose() {
    for (final f in _forms.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPendingOrders() async {
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.get(
        '/api/v1/repair-quotations/pending-orders',
        queryParameters: {'customerId': widget.order.customerId},
      );
      if (!mounted) return;
      final list = res is List
          ? res
              .whereType<Map<String, dynamic>>()
              .map(PendingQuotationOrderModel.fromJson)
              .where((o) => o.id != widget.order.id)
              .toList()
          : <PendingQuotationOrderModel>[];
      setState(() {
        _mergeCandidates = list;
        _loadingOrders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOrders = false);
    }
  }

  void _toggleMergeOrder(PendingQuotationOrderModel ord, bool selected) {
    setState(() {
      if (selected) {
        _forms.putIfAbsent(
          ord.id,
          () => _DraftDeviceForm(
            repairOrderId: ord.id,
            orderCode: ord.orderCode,
            deviceName: ord.deviceName,
          ),
        );
      } else {
        final removed = _forms.remove(ord.id);
        removed?.dispose();
      }
    });
  }

  Future<void> _submit({required bool sendImmediately}) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final itemsPayload = <Map<String, dynamic>>[];
      for (final form in _forms.values) {
        final lineItems = form.lines
            .where((l) => l.descCtrl.text.trim().isNotEmpty)
            .map((l) => {
                  'description': l.descCtrl.text.trim(),
                  'quantity': int.tryParse(l.qtyCtrl.text.trim()) ?? 1,
                  'unitPrice': double.tryParse(l.priceCtrl.text.trim()) ?? 0,
                })
            .toList();
        if (lineItems.isEmpty) {
          throw ApiException(
            400,
            'Vui lòng nhập ít nhất 1 hạng mục chi phí cho ${form.orderCode}.',
          );
        }

        final errors = form.errorsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => {'label': s, 'severity': 'HIGH'})
            .toList();

        final warrantyOptions = <Map<String, dynamic>>[
          if (form.include6M)
            {
              'code': '6M',
              'label': 'Bảo hành 6 tháng',
              'description': 'Gói tiêu chuẩn',
              'months': 6,
              'fee': 0,
            },
          if (form.include12M)
            {
              'code': '12M',
              'label': 'Bảo hành 1 năm',
              'description': 'Bảo vệ toàn diện linh kiện',
              'months': 12,
              'fee': 500000,
            },
        ];

        itemsPayload.add({
          'repairOrderId': form.repairOrderId,
          'diagnosedErrors': errors,
          'lineItems': lineItems,
          'warrantyOptions': warrantyOptions,
        });
      }

      final api = context.read<AuthProvider>().api;
      final res = await api.post(
        '/api/v1/repair-quotations',
        body: {
          'customerId': widget.order.customerId,
          'title': _forms.length > 1
              ? 'Báo giá sửa chữa ${_forms.length} thiết bị'
              : 'Báo giá sửa chữa ${widget.order.orderNumber}',
          'sendImmediately': sendImmediately,
          'items': itemsPayload,
        },
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        Navigator.pop(context, RepairQuotationModel.fromJson(res));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tạo báo giá thất bại. Vui lòng thử lại.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Icon(LucideIcons.filePlus2, size: 20, color: _navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lập báo giá (${_forms.length} thiết bị)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                    ),
                  ],

                  if (!_loadingOrders && _mergeCandidates.isNotEmpty) ...[
                    const Text(
                      'GHÉP ĐƠN KHÁC CỦA CÙNG KHÁCH HÀNG (NẾU CÓ):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._mergeCandidates.map((cand) {
                      final checked = _forms.containsKey(cand.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: checked,
                        onChanged: (v) => _toggleMergeOrder(cand, v == true),
                        title: Text(
                          '${cand.orderCode} • ${cand.deviceName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          cand.statusLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }),
                    const Divider(height: 20),
                  ],

                  ..._forms.values.map((form) => _buildDeviceFormCard(form)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _submit(sendImmediately: false),
                    child: const Text('Lưu nháp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _submitting
                        ? null
                        : () => _submit(sendImmediately: true),
                    icon: const Icon(LucideIcons.send, size: 15),
                    label: Text(
                      _submitting ? 'Đang gửi...' : 'Tạo & Gửi khách ngay',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceFormCard(_DraftDeviceForm form) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${form.orderCode} • ${form.deviceName}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: form.errorsCtrl,
            decoration: const InputDecoration(
              labelText: 'Lỗi chẩn đoán (cách nhau bởi dấu phẩy)',
              hintText: 'Hỏng IGBT, Cháy relay đóng ngắt',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Hạng mục chi phí:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...List.generate(form.lines.length, (idx) {
            final row = form.lines[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: row.descCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Tên hạng mục',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'SL',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: row.priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Đơn giá',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (form.lines.length > 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        final removed = form.lines.removeAt(idx);
                        removed.dispose();
                      }),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                    ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => form.lines.add(_DraftLineRow())),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('Thêm hạng mục'),
          ),
        ],
      ),
    );
  }
}

