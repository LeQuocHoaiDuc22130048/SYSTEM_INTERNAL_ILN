import '../widgets/permission_gate.dart';
import '../models/app_permission.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../theme/app_colors.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/modal_top_bar.dart';

Future<Customer?> showCustomerFormSheet(
  BuildContext context, {
  Customer? customer,
  String? initialName,
  String? initialPhone,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CustomerFormSheet(
      customer: customer,
      initialName: initialName,
      initialPhone: initialPhone,
    ),
  );
}

class CustomerFormSheet extends StatefulWidget {
  final Customer? customer;
  final String? initialName;
  final String? initialPhone;

  const CustomerFormSheet({
    super.key,
    this.customer,
    this.initialName,
    this.initialPhone,
  });

  @override
  State<CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _taxCodeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  late CustomerType _selectedType;
  bool _isLoading = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(
      text: c?.name ?? widget.initialName ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: c?.phone ?? widget.initialPhone ?? '',
    );
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _taxCodeCtrl = TextEditingController(text: c?.taxCode ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _selectedType = c?.type ?? CustomerType.individual;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxCodeCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final backend = context.read<BackendDataProvider>();

    final cleanPhone = _phoneCtrl.text.trim().isEmpty
        ? null
        : _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '');
    final cleanEmail = _emailCtrl.text.trim().isEmpty
        ? null
        : _emailCtrl.text.trim();
    final cleanTaxCode = _taxCodeCtrl.text.trim().isEmpty
        ? null
        : _taxCodeCtrl.text.trim();
    final cleanAddress = _addressCtrl.text.trim().isEmpty
        ? null
        : _addressCtrl.text.trim();
    final cleanNotes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();

    final cleanName = normalizeCustomerName(_nameCtrl.text, _selectedType);

    try {
      Customer result;
      if (_isEditing) {
        result = await backend.updateCustomer(
          widget.customer!.id,
          name: cleanName,
          type: _selectedType,
          phone: cleanPhone,
          email: cleanEmail,
          taxCode: cleanTaxCode,
          address: cleanAddress,
          notes: cleanNotes,
        );
      } else {
        result = await backend.createCustomer(
          name: cleanName,
          type: _selectedType,
          phone: cleanPhone,
          email: cleanEmail,
          taxCode: cleanTaxCode,
          address: cleanAddress,
          notes: cleanNotes,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Cập nhật khách hàng thành công!'
                : 'Thêm khách hàng thành công!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSuffixIcon = suffixIcon ??
        (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number
            ? IconButton(
                icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                tooltip: 'Ẩn bàn phím',
                onPressed: () => FocusScope.of(context).unfocus(),
              )
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction ??
              (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : AppColors.textTertiaryLight,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
            suffixIcon: effectiveSuffixIcon,
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          validator: validator,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        margin: EdgeInsets.only(bottom: viewInsets.bottom),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModalTopBar(
                title: _isEditing
                    ? 'Chỉnh sửa khách hàng'
                    : 'Thêm mới khách hàng',
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Type selector
                      Text(
                        'Loại khách hàng *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.user,
                                    size: 16,
                                    color:
                                        _selectedType == CustomerType.individual
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : AppColors.textPrimaryLight),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cá nhân',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _selectedType ==
                                              CustomerType.individual
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : AppColors.textPrimaryLight),
                                    ),
                                  ),
                                ],
                              ),
                              selected:
                                  _selectedType == CustomerType.individual,
                              selectedColor: AppColors.primary,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              onSelected: (val) {
                                if (val) {
                                  setState(
                                    () =>
                                        _selectedType = CustomerType.individual,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.building2,
                                    size: 16,
                                    color: _selectedType == CustomerType.company
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : AppColors.textPrimaryLight),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Doanh nghiệp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          _selectedType == CustomerType.company
                                          ? Colors.white
                                          : (isDark
                                                ? Colors.white70
                                                : AppColors.textPrimaryLight),
                                    ),
                                  ),
                                ],
                              ),
                              selected: _selectedType == CustomerType.company,
                              selectedColor: AppColors.primary,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              onSelected: (val) {
                                if (val) {
                                  setState(
                                    () => _selectedType = CustomerType.company,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name
                      _buildField(
                        controller: _nameCtrl,
                        label: _selectedType == CustomerType.company
                            ? 'Tên công ty / Đơn vị'
                            : 'Họ và tên khách hàng',
                        hint: _selectedType == CustomerType.company
                            ? 'VD: Công ty TNHH Giải Pháp X'
                            : 'VD: Nguyễn Văn A',
                        icon: _selectedType == CustomerType.company
                            ? LucideIcons.building2
                            : LucideIcons.user,
                        required: true,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Vui lòng nhập tên khách hàng';
                          }
                          if (v.trim().length > 100) {
                            return 'Tên không được vượt quá 100 ký tự';
                          }
                          return null;
                        },
                      ),

                      // Phone
                      _buildField(
                        controller: _phoneCtrl,
                        label: 'Số điện thoại',
                        hint: 'VD: 0912 345 678',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 20,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final clean = v.trim();
                          if (clean.length > 20) {
                            return 'Số điện thoại tối đa 20 ký tự';
                          }
                          return null;
                        },
                      ),

                      // Email
                      _buildField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'VD: contact@example.com',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        maxLength: 254,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final clean = v.trim();
                          if (clean.length > 254) {
                            return 'Email tối đa 254 ký tự';
                          }
                          final emailRegex = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );
                          if (!emailRegex.hasMatch(clean)) {
                            return 'Email không đúng định dạng';
                          }
                          return null;
                        },
                      ),

                      // Tax code (if company or individual)
                      _buildField(
                        controller: _taxCodeCtrl,
                        label: 'Mã số thuế',
                        hint: 'VD: 0312345678',
                        icon: LucideIcons.fileText,
                        maxLength: 30,
                        validator: (v) {
                          if (v != null && v.trim().length > 30) {
                            return 'Mã số thuế tối đa 30 ký tự';
                          }
                          return null;
                        },
                      ),

                      // Address
                      _buildField(
                        controller: _addressCtrl,
                        label: 'Địa chỉ',
                        hint: 'VD: 123 Đường Lê Lợi, Phường 1, TP. HCM',
                        icon: LucideIcons.mapPin,
                        maxLines: 2,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) {
                          if (v != null && v.trim().length > 500) {
                            return 'Địa chỉ tối đa 500 ký tự';
                          }
                          return null;
                        },
                      ),

                      // Notes
                      _buildField(
                        controller: _notesCtrl,
                        label: 'Ghi chú',
                        hint: 'Ghi chú nội bộ về khách hàng...',
                        icon: LucideIcons.stickyNote,
                        maxLines: 3,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) {
                          if (v != null && v.trim().length > 2000) {
                            return 'Ghi chú tối đa 2000 ký tự';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: PermissionGate(
                          permission: _isEditing
                              ? AppPermission.updateCustomers
                              : AppPermission.createCustomers,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
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
                                    _isEditing
                                        ? 'Lưu thay đổi'
                                        : 'Tạo khách hàng',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
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
    ),
  );
}

  static String normalizeCustomerName(String name, CustomerType type) {
    if (name.trim().isEmpty) return '';
    const acronyms = {
      'TNHH',
      'CP',
      'JSC',
      'MTV',
      'TM',
      'DV',
      'TMDV',
      'XNK',
      'KCN',
      'PCCC',
      'EVN',
      'ABB',
      'VFD',
      'PLC',
      'SCADA',
      'CNC',
      'IT',
      'AI',
      'LLC',
      'LTD',
      'CO',
      'CORP',
      'INC',
    };
    const lowercaseCompanyWords = {'ty', 'và', 'của', 'tại', 'cho'};

    String normalizeWord(String word, bool isCompany, int index) {
      if (word.isEmpty) return '';
      if (word.contains('-')) {
        return word
            .split('-')
            .map((p) => normalizeWord(p, isCompany, index))
            .join('-');
      }
      final upper = word.toUpperCase();
      if (acronyms.contains(upper)) {
        return upper;
      }
      final lower = word.toLowerCase();
      if (isCompany && index > 0 && lowercaseCompanyWords.contains(lower)) {
        return lower;
      }
      final first = word.substring(0, 1).toUpperCase();
      final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
      return first + rest;
    }

    final isCompany = type == CustomerType.company;
    final words = name.trim().replaceAll(RegExp(r'\s+'), ' ').split(' ');
    return words
        .asMap()
        .entries
        .map((e) => normalizeWord(e.value, isCompany, e.key))
        .join(' ');
  }
}
