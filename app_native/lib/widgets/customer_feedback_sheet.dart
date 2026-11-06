import 'package:provider/provider.dart';
import '../utils/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_feedback.dart';

class CustomerFeedbackSheet extends StatefulWidget {
  final String? filterCustomerCode;
  final String? filterCustomerName;

  const CustomerFeedbackSheet({
    super.key,
    this.filterCustomerCode,
    this.filterCustomerName,
  });

  static Future<void> show(
    BuildContext context, {
    String? filterCustomerCode,
    String? filterCustomerName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerFeedbackSheet(
        filterCustomerCode: filterCustomerCode,
        filterCustomerName: filterCustomerName,
      ),
    );
  }

  @override
  State<CustomerFeedbackSheet> createState() => _CustomerFeedbackSheetState();
}

class _CustomerFeedbackSheetState extends State<CustomerFeedbackSheet> {
  String _selectedFilter = 'ALL'; // 'ALL', 'URGENT', 'PENDING', 'IN_PROGRESS', 'RESOLVED'
  String _searchKeyword = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<CustomerFeedback> _feedbacks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Future<void> _fetchFeedbacks() async {
    setState(() => _isLoading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final res = await api.get('/api/v1/customers/feedbacks?size=100');
      if (!mounted) return;
      if (res is Map<String, dynamic> && res['content'] is List) {
        setState(() {
          _feedbacks = (res['content'] as List)
              .map((item) => CustomerFeedback.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _feedbacks = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbacks = [];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openReplyDialog(CustomerFeedback feedback) {
    String currentStatus = feedback.status == 'PENDING' ? 'IN_PROGRESS' : feedback.status;
    final replyCtrl = TextEditingController(text: feedback.reply ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.messageSquare, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Xử lý & Trả lời khách hàng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${feedback.customerName} (${feedback.orderCode})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '“${feedback.content}”',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Trạng thái xử lý:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('⚙️ Đang xử lý', style: TextStyle(fontSize: 11)),
                          selected: currentStatus == 'IN_PROGRESS',
                          onSelected: (val) {
                            if (val) setDialogState(() => currentStatus = 'IN_PROGRESS');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('✅ Đã giải quyết', style: TextStyle(fontSize: 11)),
                          selected: currentStatus == 'RESOLVED',
                          onSelected: (val) {
                            if (val) setDialogState(() => currentStatus = 'RESOLVED');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Nội dung phản hồi kỹ thuật:*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: replyCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Nhập phương án xử lý, hỗ trợ thông số, hẹn giờ kỹ sư đến hiện trường...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final text = replyCtrl.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập nội dung phản hồi kỹ thuật')),
                    );
                    return;
                  }

                  final api = context.read<AuthProvider>().api;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);
                  try {
                    await api.put('/api/v1/customers/feedbacks/${feedback.id}/reply', body: {
                      'status': currentStatus,
                      'reply': text,
                    });
                    await _fetchFeedbacks();
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text('Đã lưu phản hồi vào CSDL thành công!'),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Lỗi khi gửi phản hồi: $e')),
                    );
                  }
                },
                icon: const Icon(LucideIcons.send, size: 14),
                label: const Text('Gửi phản hồi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var list = _feedbacks;

    // Filter by customer if provided
    if (widget.filterCustomerCode != null && widget.filterCustomerCode!.isNotEmpty) {
      list = list.where((f) => f.customerCode == widget.filterCustomerCode).toList();
    } else if (widget.filterCustomerName != null && widget.filterCustomerName!.isNotEmpty) {
      final nameLower = widget.filterCustomerName!.toLowerCase();
      list = list.where((f) => f.customerName.toLowerCase().contains(nameLower)).toList();
    }

    // Filter by status tab
    if (_selectedFilter == 'URGENT') {
      list = list.where((f) => f.isUrgent && f.status != 'RESOLVED').toList();
    } else if (_selectedFilter == 'PENDING') {
      list = list.where((f) => f.status == 'PENDING').toList();
    } else if (_selectedFilter == 'IN_PROGRESS') {
      list = list.where((f) => f.status == 'IN_PROGRESS').toList();
    } else if (_selectedFilter == 'RESOLVED') {
      list = list.where((f) => f.status == 'RESOLVED').toList();
    }

    // Keyword search
    if (_searchKeyword.isNotEmpty) {
      final q = _searchKeyword.toLowerCase();
      list = list.where((f) {
        return f.customerName.toLowerCase().contains(q) ||
            f.orderCode.toLowerCase().contains(q) ||
            (f.deviceModel ?? '').toLowerCase().contains(q) ||
            f.content.toLowerCase().contains(q);
      }).toList();
    }

    final urgentCount = _feedbacks.where((f) => f.isUrgent && f.status != 'RESOLVED').length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.messageSquare, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quản lý Phản hồi & CSKH',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          widget.filterCustomerName != null
                            ? 'Khách hàng: ${widget.filterCustomerName}'
                            : 'Ý kiến, đánh giá và khiếu nại bảo hành',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchKeyword = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên khách, mã đơn, nội dung...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(LucideIcons.search, size: 16, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchKeyword = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'Tất cả (${_feedbacks.length})'),
                  const SizedBox(width: 6),
                  _buildFilterChip('URGENT', '🚨 Khẩn cấp ($urgentCount)', isUrgentChip: true),
                  const SizedBox(width: 6),
                  _buildFilterChip('PENDING', 'Chờ tiếp nhận'),
                  const SizedBox(width: 6),
                  _buildFilterChip('IN_PROGRESS', 'Đang xử lý'),
                  const SizedBox(width: 6),
                  _buildFilterChip('RESOLVED', 'Đã giải quyết'),
                ],
              ),
            ),

            const Divider(height: 20),

            // Feedback Cards List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.inbox, size: 36, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Không có phản hồi nào phù hợp',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: list.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildFeedbackCard(list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isUrgentChip = false}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
      selectedColor: isUrgentChip ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (isUrgentChip ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8))
            : (isUrgentChip ? const Color(0xFFDC2626) : const Color(0xFF475569)),
      ),
      side: BorderSide(
        color: isSelected
            ? (isUrgentChip ? const Color(0xFFEF4444) : const Color(0xFF2563EB))
            : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildFeedbackCard(CustomerFeedback f) {
    final isInProgress = f.status == 'IN_PROGRESS';
    final isResolved = f.status == 'RESOLVED';

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);
    if (isResolved) {
      statusBg = const Color(0xFFDCFCE7);
      statusColor = const Color(0xFF15803D);
    } else if (isInProgress) {
      statusBg = const Color(0xFFDBEAFE);
      statusColor = const Color(0xFF1D4ED8);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: f.isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: f.isUrgent ? 1.5 : 1,
        ),
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
          // Top row
          Row(
            children: [
              Expanded(
                child: Text(
                  f.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (f.isUrgent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text(
                    '🚨 KHẨN CẤP',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  f.statusName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Order code & device
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  f.orderCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              if (f.deviceModel != null)
                Expanded(
                  child: Text(
                    f.deviceModel!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                f.createdAt,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Stars & Tags
          if (f.type != 'SUGGESTION') ...[
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    LucideIcons.star,
                    size: 14,
                    color: index < f.rating ? const Color(0xFFEAB308) : const Color(0xFFE2E8F0),
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  '${f.rating}/5',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF854D0E)),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (f.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: f.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500)),
              )).toList(),
            ),
            const SizedBox(height: 6),
          ],

          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              f.content,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
            ),
          ),

          // Existing reply
          if (f.reply != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.messageSquareCheck, size: 13, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        '${f.repliedBy ?? 'Kỹ thuật LikeNew'} đã trả lời:',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.reply!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (f.customerPhone != null && f.customerPhone!.isNotEmpty)
                InkWell(
                  onTap: () => _callPhone(f.customerPhone!),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.phone, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          f.customerPhone!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openReplyDialog(f),
                icon: const Icon(LucideIcons.send, size: 12),
                label: Text(
                  f.reply != null ? 'Sửa câu trả lời' : 'Xử lý & Trả lời',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
