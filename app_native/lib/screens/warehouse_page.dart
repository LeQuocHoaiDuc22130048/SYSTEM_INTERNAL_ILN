import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/network_provider.dart';
import '../utils/pending_sync_provider.dart';
import '../widgets/status_badge.dart';
import '../data/mock_data.dart';
import '../models/board.dart';
import 'scanner_page.dart';

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<BoardStatus?> _filter = ValueNotifier(null);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    _filter.dispose();
    super.dispose();
  }

  List<Board> get _filteredBoards {
    final query = _searchQuery.value.toLowerCase();
    final currentFilter = _filter.value;
    return mockBoards.where((board) {
      final matchesFilter = currentFilter == null || board.status == currentFilter;
      final matchesSearch =
          query.isEmpty ||
          board.name.toLowerCase().contains(query) ||
          board.qrCode.toLowerCase().contains(query) ||
          board.model.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  String _qrCodeLabel(Board board) {
    return board.qrCode.isEmpty ? 'QR chờ backend tạo' : board.qrCode;
  }

  Future<void> _handleEmployeeQrScan(String qrCode) async {
    final isOnline = await context.read<NetworkProvider>().checkNow();
    if (!mounted) return;

    if (!isOnline) {
      context.read<PendingSyncProvider>().addAction(
            type: PendingSyncType.qrScan,
            title: 'Quét QR bo mạch',
            description: 'Mã QR: $qrCode',
          );
      _showSnackBar(
        'Đã lưu tạm mã QR. Admin sẽ thấy thay đổi khi thiết bị có mạng lại.',
        AppColors.warning,
      );
      return;
    }

    _showSnackBar('Đã quét và cập nhật admin: $qrCode', AppColors.success);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmployee = Provider.of<AuthProvider>(context).isEmployee;

    if (isEmployee) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: 24),
                Text(
                  'Quét mã QR Bo mạch',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sử dụng camera để quét mã QR trên bo mạch',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScannerPage(),
                      ),
                    );
                    if (result != null && mounted) {
                      await _handleEmployeeQrScan(result as String);
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Mở Máy Quét'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxHeight < 650;
            final wide = constraints.maxWidth >= 760;

            return Column(
              children: [
                // Header & Stats
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 20 : 22,
                    wide ? 22 : 16,
                    wide ? 20 : 22,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kho Bo mạch',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${mockBoards.length} bo mạch trong kho',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showAddEditBoardDialog();
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text(
                                  'Thêm',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ScannerPage(),
                                    ),
                                  );
                                  if (result != null && mounted) {
                                    _searchQuery.value = result as String;
                                    _searchController.text = _searchQuery.value;
                                  }
                                },
                                icon: const Icon(Icons.qr_code_scanner, size: 16),
                                label: const Text(
                                  'Quét QR',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Responsive Stats
                      if (isLandscape)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildLandscapeStatCard(
                                '${mockBoards.length}',
                                'Tổng',
                                LucideIcons.cpu,
                                AppColors.primary,
                                isDark,
                              ),
                              const SizedBox(width: 22),
                              _buildLandscapeStatCard(
                                '${mockBoards.where((b) => b.status == BoardStatus.available).length}',
                                'Sẵn sàng',
                                Icons.inventory_2_outlined,
                                AppColors.success,
                                isDark,
                              ),
                              const SizedBox(width: 22),
                              _buildLandscapeStatCard(
                                '${mockBoards.where((b) => b.status == BoardStatus.checkedOut).length}',
                                'Đang dùng',
                                LucideIcons.wrench,
                                AppColors.warning,
                                isDark,
                              ),
                              const SizedBox(width: 22),
                              _buildLandscapeStatCard(
                                '${mockBoards.where((b) => b.status == BoardStatus.maintenance).length}',
                                'Bảo trì',
                                Icons.warning_amber,
                                AppColors.error,
                                isDark,
                              ),
                            ],
                          ),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.0,
                          children: [
                            _buildCompactStatCard(
                              '${mockBoards.length}',
                              'Tổng',
                              LucideIcons.cpu,
                              AppColors.primary,
                              isDark,
                            ),
                            _buildCompactStatCard(
                              '${mockBoards.where((b) => b.status == BoardStatus.available).length}',
                              'Sẵn sàng',
                              Icons.inventory_2_outlined,
                              AppColors.success,
                              isDark,
                            ),
                            _buildCompactStatCard(
                              '${mockBoards.where((b) => b.status == BoardStatus.checkedOut).length}',
                              'Đang dùng',
                              LucideIcons.wrench,
                              AppColors.warning,
                              isDark,
                            ),
                            _buildCompactStatCard(
                              '${mockBoards.where((b) => b.status == BoardStatus.maintenance).length}',
                              'Bảo trì',
                              Icons.warning_amber,
                              AppColors.error,
                              isDark,
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // Search and View Toggle
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  _searchQuery.value = value;
                                },
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Tìm tên, mã QR, model...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? AppColors.borderDark
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isGridView = !_isGridView;
                                    });
                                  },
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.grid_view,
                                    size: 18,
                                    color: _isGridView
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: _isGridView
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isGridView = false;
                                    });
                                  },
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.view_list,
                                    size: 18,
                                    color: !_isGridView
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight),
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: !_isGridView
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filters
                      SizedBox(
                        height: 32,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                'Tất cả',
                                null,
                                mockBoards.length,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'Sẵn sàng',
                                BoardStatus.available,
                                mockBoards
                                    .where(
                                      (b) => b.status == BoardStatus.available,
                                    )
                                    .length,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'Đang dùng',
                                BoardStatus.checkedOut,
                                mockBoards
                                    .where(
                                      (b) => b.status == BoardStatus.checkedOut,
                                    )
                                    .length,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                'Bảo trì',
                                BoardStatus.maintenance,
                                mockBoards
                                    .where(
                                      (b) =>
                                          b.status == BoardStatus.maintenance,
                                    )
                                    .length,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Board List
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_searchQuery, _filter]),
                    builder: (context, _) {
                      final filtered = _filteredBoards;
                      if (filtered.isEmpty) {
                        return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🔌', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 16),
                                Text(
                                  'Không tìm thấy bo mạch',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Thử thay đổi bộ lọc',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                      }
                      
                      return _isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: wide ? 4 : 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: wide ? 0.75 : 0.7,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildBoardGridCard(filtered[index])
                                  .animate(target: 1)
                                  .fadeIn(
                                    duration: 400.ms,
                                    delay: (50 * index).ms,
                                  )
                                  .slideY(
                                    begin: 0.2,
                                    end: 0,
                                    duration: 400.ms,
                                    delay: (50 * index).ms,
                                  );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildBoardListCard(filtered[index])
                                    .animate(target: 1)
                                    .fadeIn(
                                      duration: 400.ms,
                                      delay: (50 * index).ms,
                                    )
                                    .slideX(
                                      begin: -0.2,
                                      end: 0,
                                      duration: 400.ms,
                                      delay: (50 * index).ms,
                                    ),
                              );
                            },
                          );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, BoardStatus? status, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<BoardStatus?>(
      valueListenable: _filter,
      builder: (context, currentFilter, _) {
        final isSelected = currentFilter == status;
        return SizedBox(
          height: 32,
          child: FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? Colors.blue[200]
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              _filter.value = selected ? status : null;
            },
            backgroundColor: isDark
                ? AppColors.surfaceDark
                : const Color(0xFFF1F5F9),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }

  Widget _buildCompactStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(target: 1)
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.2, end: 0, duration: 300.ms, delay: 100.ms);
  }

  Widget _buildBoardGridCard(Board board) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = board.status == BoardStatus.available
        ? AppColors.success
        : board.status == BoardStatus.checkedOut
        ? AppColors.info
        : AppColors.warning;

    return InkWell(
      onTap: () {
        _showBoardDetail(board);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          LucideIcons.cpu,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _qrCodeLabel(board),
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      board.model,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 9,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            board.location,
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 8),
            StatusBadge(status: board.status, size: 'sm'),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardListCard(Board board) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = board.status == BoardStatus.available
        ? AppColors.success
        : board.status == BoardStatus.checkedOut
        ? AppColors.info
        : AppColors.warning;

    return InkWell(
      onTap: () {
        _showBoardDetail(board);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      LucideIcons.cpu,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _qrCodeLabel(board),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Text(' · ', style: TextStyle(fontSize: 12)),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          board.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(status: board.status, size: 'sm'),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showBoardDetail(Board board) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BoardDetailSheet(
        board: board,
        onEdit: () {
          Navigator.pop(context);
          _showAddEditBoardDialog(board: board);
        },
        onDelete: () {
          Navigator.pop(context);
          _showDeleteConfirmDialog(board);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bo mạch'),
        content: Text('Bạn có chắc chắn muốn xóa bo mạch ${board.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                mockBoards.removeWhere((b) => b.id == board.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa bo mạch ${board.name}')),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddEditBoardDialog({Board? board}) {
    final isEditing = board != null;
    final nameCtrl = TextEditingController(text: board?.name ?? '');
    final qrCodeCtrl = TextEditingController(text: board?.qrCode ?? '');
    final modelCtrl = TextEditingController(text: board?.model ?? '');
    final locationCtrl = TextEditingController(text: board?.location ?? '');
    final descCtrl = TextEditingController(text: board?.description ?? '');
    BoardStatus selectedStatus = board?.status ?? BoardStatus.available;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final screenSize = MediaQuery.sizeOf(context);
          final isCompact = screenSize.width < 600;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 20,
              vertical: 20,
            ),
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: isCompact ? 1 : 0.75,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * (isCompact ? 0.9 : 0.75),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEditing ? 'Chỉnh sửa bo mạch' : 'Thêm bo mạch',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Tên bo mạch',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (isEditing) ...[
                                TextField(
                                  controller: qrCodeCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Mã QR',
                                    filled: true,
                                    fillColor: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade200,
                                  ),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Model',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: locationCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Vị trí',
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<BoardStatus>(
                                initialValue: selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Trạng thái',
                                ),
                                items: BoardStatus.values.map((s) {
                                  String label = 'Sẵn sàng';
                                  if (s == BoardStatus.checkedOut) {
                                    label = 'Đang dùng';
                                  }
                                  if (s == BoardStatus.maintenance) {
                                    label = 'Bảo trì';
                                  }
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(
                                      () => selectedStatus = val,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: descCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Mô tả',
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (nameCtrl.text.isEmpty) return;

                              setState(() {
                                if (isEditing) {
                                  final index = mockBoards.indexWhere(
                                    (b) => b.id == board.id,
                                  );
                                  if (index != -1) {
                                    mockBoards[index] = Board(
                                      id: board.id,
                                      name: nameCtrl.text,
                                      qrCode: board.qrCode,
                                      model: modelCtrl.text,
                                      location: locationCtrl.text,
                                      status: selectedStatus,
                                      description: descCtrl.text,
                                      checkedOutBy: board.checkedOutBy,
                                      checkedOutAt: board.checkedOutAt,
                                      currentRepairOrder:
                                          board.currentRepairOrder,
                                    );
                                  }
                                } else {
                                  mockBoards.add(
                                    Board(
                                      id: 'board_${DateTime.now().millisecondsSinceEpoch}',
                                      name: nameCtrl.text,
                                      qrCode: '',
                                      model: modelCtrl.text,
                                      location: locationCtrl.text,
                                      status: selectedStatus,
                                      description: descCtrl.text,
                                    ),
                                  );
                                }
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Đã cập nhật bo mạch'
                                        : 'Đã thêm bo mạch',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Lưu'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardDetailSheet extends StatefulWidget {
  final Board board;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BoardDetailSheet({
    required this.board,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_BoardDetailSheet> createState() => _BoardDetailSheetState();
}

class _BoardDetailSheetState extends State<_BoardDetailSheet> {
  bool _isLoading = false;
  bool _isDone = false;

  Future<void> _handleAction() async {
    setState(() {
      _isLoading = true;
    });

    final isOnline = await context.read<NetworkProvider>().checkNow();
    if (!isOnline && mounted) {
      final isReturn = widget.board.status == BoardStatus.checkedOut;
      context.read<PendingSyncProvider>().addAction(
            type: isReturn
                ? PendingSyncType.boardReturn
                : PendingSyncType.boardCheckout,
            title: isReturn ? 'Trả bo mạch' : 'Lấy bo mạch',
            description: '${widget.board.name} - ${widget.board.qrCode}',
          );
    }

    await Future.delayed(Duration(milliseconds: isOnline ? 1200 : 250));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isDone = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon and Title
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      LucideIcons.cpu,
                      size: 28,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.board.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          '${widget.board.qrCode.isEmpty ? 'QR chờ backend tạo' : widget.board.qrCode} '
                          '· ${widget.board.model}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                    onPressed: widget.onEdit,
                    tooltip: 'Chỉnh sửa',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                    onPressed: widget.onDelete,
                    tooltip: 'Xóa',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Info
              _buildInfoRow(
                'Trạng thái',
                null,
                child: StatusBadge(status: widget.board.status),
              ),
              _buildInfoRow('Vị trí', widget.board.location),
              if (widget.board.checkedOutBy != null)
                _buildInfoRow('Đang dùng bởi', widget.board.checkedOutBy!),
              if (widget.board.currentRepairOrder != null)
                _buildInfoRow('Đơn sửa chữa', widget.board.currentRepairOrder!),
              if (widget.board.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.board.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              if (_isDone)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'Thao tác thành công!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                    if (widget.board.status == BoardStatus.available) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleAction,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Lấy bo mạch'),
                        ),
                      ),
                    ],
                    if (widget.board.status == BoardStatus.checkedOut) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Trả bo mạch'),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, {Widget? child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          child ??
              Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
        ],
      ),
    );
  }
}
