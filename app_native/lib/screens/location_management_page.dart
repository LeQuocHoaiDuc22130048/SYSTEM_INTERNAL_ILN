import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../models/store_location.dart';
import '../utils/backend_data_provider.dart';

class LocationManagementPage extends StatefulWidget {
  const LocationManagementPage({super.key});

  @override
  State<LocationManagementPage> createState() => _LocationManagementPageState();
}

class _LocationManagementPageState extends State<LocationManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackendDataProvider>().loadLocations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddEditDialog([StoreLocation? location]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeCtrl = TextEditingController(text: location?.code ?? '');
    final nameCtrl = TextEditingController(text: location?.name ?? '');
    final descCtrl = TextEditingController(text: location?.description ?? '');
    final qrCtrl = TextEditingController(text: location?.qrCode ?? location?.code ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  location == null ? LucideIcons.plus : LucideIcons.pencil,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                location == null ? 'Thêm Vị Trí Mới' : 'Sửa Vị Trí Kho',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã vị trí (Code) *',
                      hintText: 'VD: LOC-A1, KE-01, NGAN-02...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mã vị trí' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên vị trí / Kệ kho *',
                      hintText: 'VD: Kệ A - Tầng 1 (Công suất)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên vị trí' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết',
                      hintText: 'Loại linh kiện chứa, ghi chú vị trí...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mã QR Code (Tùy chọn)',
                      hintText: 'Để trống sẽ tự lấy theo mã vị trí',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final code = codeCtrl.text.trim().toUpperCase();
                final name = nameCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final qr = qrCtrl.text.trim();

                Navigator.pop(dlgContext);
                setState(() => _isLoading = true);

                try {
                  final provider = context.read<BackendDataProvider>();
                  if (location == null) {
                    await provider.createStoreLocation(
                      code: code,
                      name: name,
                      description: desc.isNotEmpty ? desc : null,
                      qrCode: qr.isNotEmpty ? qr : code,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Đã tạo vị trí $name')),
                      );
                    }
                  } else {
                    await provider.updateStoreLocation(
                      id: location.id,
                      code: code,
                      name: name,
                      description: desc.isNotEmpty ? desc : null,
                      qrCode: qr.isNotEmpty ? qr : code,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Đã cập nhật vị trí $name')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Lỗi: $e'), backgroundColor: AppColors.error),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text(location == null ? 'Tạo mới' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(StoreLocation location) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text('Xác nhận xóa vị trí', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa vị trí ${location.name} (${location.code}) khỏi kho hàng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dlgContext);
              setState(() => _isLoading = true);

              try {
                await context.read<BackendDataProvider>().deleteStoreLocation(location.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Đã xóa vị trí ${location.name}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Không thể xóa: $e'), backgroundColor: AppColors.error),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final locations = backend.locations;

    final query = _searchQuery.toLowerCase().trim();
    final filteredLocations = locations.where((loc) {
      if (query.isEmpty) return true;
      return loc.name.toLowerCase().contains(query) ||
          loc.code.toLowerCase().contains(query) ||
          (loc.description?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Vị Trí Kho / Kệ', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Thêm vị trí mới',
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tên, mã kệ hoặc vị trí...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Count Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredLocations.length} vị trí lưu kho',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm mới', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),

          // Location List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => context.read<BackendDataProvider>().loadLocations(),
                    child: filteredLocations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 350,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.mapPin, size: 56, color: Colors.grey),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Không tìm thấy vị trí phù hợp'
                                            : 'Chưa có vị trí lưu kho nào',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Thử thay đổi từ khóa tìm kiếm'
                                            : 'Bấm "+ Thêm mới" để tạo kệ hoặc ngăn kéo đầu tiên',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filteredLocations.length,
                            itemBuilder: (context, index) {
                              final loc = filteredLocations[index];
                              final partCount = loc.itemCount;
                              final totalQty = loc.totalQuantity;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.info.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: AppColors.info.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              loc.code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppColors.info,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  loc.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (loc.description != null && loc.description!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    loc.description!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? AppColors.textSecondaryDark
                                                          : AppColors.textSecondaryLight,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 20),
                                            padding: EdgeInsets.zero,
                                            onSelected: (val) {
                                              if (val == 'edit') {
                                                _showAddEditDialog(loc);
                                              } else if (val == 'delete') {
                                                _showDeleteDialog(loc);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Sửa vị trí'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                                    SizedBox(width: 8),
                                                    Text('Xóa vị trí', style: TextStyle(color: AppColors.error)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                LucideIcons.boxes,
                                                size: 14,
                                                color: partCount > 0 ? AppColors.success : Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                partCount > 0
                                                    ? '$partCount loại linh kiện (${totalQty.toStringAsFixed(0)} tồn)'
                                                    : 'Chưa có linh kiện',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: partCount > 0
                                                      ? AppColors.success
                                                      : (isDark
                                                          ? AppColors.textSecondaryDark
                                                          : AppColors.textSecondaryLight),
                                                ),
                                              ),
                                            ],
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _showAddEditDialog(loc),
                                            icon: const Icon(Icons.edit, size: 14),
                                            label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm vị trí mới'),
      ),
    );
  }
}
