import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../utils/backend_data_provider.dart';
import 'modal_top_bar.dart';

Future<void> showFieldWorkBottomSheet(
  BuildContext context, {
  String? dateStr,
  String? initialNote,
  bool isExisting = false,
  required bool isDark,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return FieldWorkBottomSheet(
        dateStr: dateStr,
        initialNote: initialNote,
        isExisting: isExisting,
        isDark: isDark,
      );
    },
  );
}

class FieldWorkBottomSheet extends StatefulWidget {
  final String? dateStr;
  final String? initialNote;
  final bool isExisting;
  final bool isDark;

  const FieldWorkBottomSheet({
    super.key,
    this.dateStr,
    this.initialNote,
    this.isExisting = false,
    required this.isDark,
  });

  @override
  State<FieldWorkBottomSheet> createState() => _FieldWorkBottomSheetState();
}

class _FieldWorkBottomSheetState extends State<FieldWorkBottomSheet> {
  late DateTime _selectedDate;
  late TextEditingController _noteController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.dateStr != null) {
      _selectedDate = DateTime.tryParse(widget.dateStr!) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập ghi chú địa điểm / nội dung công việc';
      });
      return;
    }
    if (note.length > 2000) {
      setState(() {
        _errorMessage = 'Ghi chú không được vượt quá 2000 ký tự';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await context.read<BackendDataProvider>().saveFieldWork(
        _selectedDate,
        note,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi yêu cầu đi công trình, chờ quản trị viên duyệt',
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận huỷ ghi nhận'),
        content: const Text(
          'Bạn có chắc chắn muốn huỷ ghi nhận ngày đi công trình này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Huỷ ghi nhận'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await context.read<BackendDataProvider>().removeFieldWork(_selectedDate);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã huỷ ghi nhận ngày đi công trình')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ModalTopBar(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.briefcase,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isExisting
                              ? 'Chỉnh sửa đi công trình'
                              : 'Báo cáo công trình',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chỉ tính 1.0 công sau khi quản trị viên chấp nhận',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Ngày làm việc',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Địa điểm & nội dung công việc (bắt buộc)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLength: 2000,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Ví dụ: Khảo sát hiện trường tại công trình Nhà máy Bia Sabeco, nghiệm thu tủ điện...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFD97706),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        color: Color(0xFFEF4444),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.isExisting) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _handleDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Huỷ báo'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _handleSave,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.isExisting
                                  ? 'Cập nhật'
                                  : 'Ghi nhận đi công trình',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
