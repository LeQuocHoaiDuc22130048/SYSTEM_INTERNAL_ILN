import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/store_location.dart';
import '../screens/scanner_page.dart';
import '../theme/app_colors.dart';
import '../utils/backend_data_provider.dart';

Future<StoreLocation?> showCreateStoreLocationDialog(
  BuildContext context, {
  String? initialCode,
}) async {
  final codeCtrl = TextEditingController(text: initialCode ?? '');
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isSubmitting = false;

  return showDialog<StoreLocation>(
    context: context,
    barrierDismissible: false,
    builder: (dlgContext) => StatefulBuilder(
      builder: (context, setDlgState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Thêm Vị Trí Kho Mới', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vị trí lưu kho dùng để định danh kệ, ngăn, hộp lưu trữ bo mạch và linh kiện.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã vị trí kho *',
                    hintText: 'VD: K-A1, KE-02, BIN-B3...',
                    prefixIcon: Icon(Icons.qr_code, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị vị trí *',
                    hintText: 'VD: Kệ A1 - Tầng 2, Hộp tụ điện...',
                    prefixIcon: Icon(Icons.label_outline, size: 18),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả thêm (Tùy chọn)',
                    hintText: 'Ghi chú vị trí, khu vực...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dlgContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      final name = nameCtrl.text.trim();
                      if (code.isEmpty || name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập đầy đủ Mã và Tên vị trí kho')),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);
                      try {
                        final backend = context.read<BackendDataProvider>();
                        final created = await backend.createStoreLocation(
                          code: code,
                          name: name,
                          description: descCtrl.text.trim(),
                          qrCode: code,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(dlgContext, created);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã tạo vị trí "${created.name} (${created.code})" thành công'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setDlgState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Tạo vị trí'),
            ),
          ],
        );
      },
    ),
  );
}

Future<StoreLocation?> showStoreLocationPicker(
  BuildContext context, {
  String? currentCode,
  String? currentId,
}) async {
  final backend = context.read<BackendDataProvider>();
  if (backend.locations.isEmpty) {
    await backend.loadLocations();
    if (!context.mounted) return null;
  }

  return showModalBottomSheet<StoreLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final locations = backend.locations;
        final queryCtrl = TextEditingController();
        String filterText = '';

        return StatefulBuilder(
          builder: (ctx, setFilterState) {
            final filtered = locations.where((loc) {
              if (filterText.isEmpty) return true;
              final q = filterText.toLowerCase();
              return loc.code.toLowerCase().contains(q) ||
                  loc.name.toLowerCase().contains(q) ||
                  (loc.description?.toLowerCase().contains(q) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chọn Vị Trí Lưu Kho',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final newLoc = await showCreateStoreLocationDialog(sheetContext);
                          if (newLoc != null) {
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, newLoc);
                            }
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Thêm vị trí'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: queryCtrl,
                          onChanged: (val) {
                            setFilterState(() {
                              filterText = val.trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mã hoặc tên vị trí...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            suffixIcon: filterText.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      queryCtrl.clear();
                                      setFilterState(() {
                                        filterText = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Quét mã QR vị trí',
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        onPressed: () async {
                          final scanned = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(builder: (_) => const ScannerPage()),
                          );
                          if (scanned != null && scanned.trim().isNotEmpty) {
                            final code = scanned.trim();
                            final matched = locations.cast<StoreLocation?>().firstWhere(
                              (l) =>
                                  l?.code.toUpperCase() == code.toUpperCase() ||
                                  l?.qrCode?.toUpperCase() == code.toUpperCase(),
                              orElse: () => null,
                            );
                            if (matched != null) {
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, matched);
                              }
                            } else {
                              if (sheetContext.mounted) {
                                final created = await showCreateStoreLocationDialog(sheetContext, initialCode: code);
                                if (created != null && sheetContext.mounted) {
                                  Navigator.pop(sheetContext, created);
                                }
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  filterText.isEmpty
                                      ? 'Chưa có vị trí kho nào được tạo'
                                      : 'Không tìm thấy vị trí phù hợp',
                                  style: TextStyle(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final newLoc = await showCreateStoreLocationDialog(
                                      sheetContext,
                                      initialCode: filterText.isNotEmpty ? filterText.toUpperCase() : null,
                                    );
                                    if (newLoc != null && sheetContext.mounted) {
                                      Navigator.pop(sheetContext, newLoc);
                                    }
                                  },
                                  icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                                  label: const Text('Tạo vị trí này ngay'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              final loc = filtered[index];
                              final isSelected = (currentId != null && loc.id == currentId) ||
                                  (currentCode != null && loc.code.toLowerCase() == currentCode.toLowerCase());

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        loc.name,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        loc.code,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: loc.description != null && loc.description!.isNotEmpty
                                    ? Text(
                                        loc.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                                    : null,
                                onTap: () => Navigator.pop(sheetContext, loc),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class LocationPickerField extends StatelessWidget {
  final StoreLocation? selectedLocation;
  final String? fallbackCode;
  final ValueChanged<StoreLocation?> onSelected;
  final String label;
  final String hint;
  final bool isRequired;

  const LocationPickerField({
    super.key,
    required this.selectedLocation,
    required this.onSelected,
    this.fallbackCode,
    this.label = 'Vị trí lưu kho',
    this.hint = 'Chạm để chọn vị trí kho (kệ/ngăn)...',
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = selectedLocation != null || (fallbackCode != null && fallbackCode!.trim().isNotEmpty);
    final displayText = selectedLocation != null
        ? '${selectedLocation!.name} (${selectedLocation!.code})'
        : (fallbackCode != null && fallbackCode!.trim().isNotEmpty
            ? fallbackCode!
            : hint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isRequired ? '$label *' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            InkWell(
              onTap: () async {
                final created = await showCreateStoreLocationDialog(context);
                if (created != null) {
                  onSelected(created);
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Thêm vị trí mới',
                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final loc = await showStoreLocationPicker(
              context,
              currentCode: selectedLocation?.code ?? fallbackCode,
              currentId: selectedLocation?.id,
            );
            if (loc != null) {
              onSelected(loc);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasSelection
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: hasSelection ? AppColors.primary : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                      color: hasSelection
                          ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                          : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSelection && !isRequired) ...[
                  InkWell(
                    onTap: () => onSelected(null),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
