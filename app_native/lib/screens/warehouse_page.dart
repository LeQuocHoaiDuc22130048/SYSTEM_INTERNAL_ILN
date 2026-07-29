import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/network_provider.dart';
import '../utils/pending_sync_provider.dart';
import '../widgets/status_badge.dart';
import '../models/board.dart';
import '../models/board_history_item.dart';
import '../models/part.dart';
import 'scanner_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/qr_share_helper.dart';

enum WarehouseMode { boards, parts }
enum PartFilterStatus { all, lowStock, outOfStock }

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<BoardStatus?> _filter = ValueNotifier(null);
  final ValueNotifier<PartFilterStatus> _partFilter = ValueNotifier(PartFilterStatus.all);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  WarehouseMode _currentMode = WarehouseMode.boards;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackendDataProvider>().loadBoards();
      context.read<BackendDataProvider>().loadParts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    _filter.dispose();
    _partFilter.dispose();
    super.dispose();
  }

  List<Board> get _filteredBoards {
    final query = _searchQuery.value.toLowerCase();
    final currentFilter = _filter.value;
    final boards = context.read<BackendDataProvider>().boards;
    return boards.where((board) {
      final matchesFilter =
          currentFilter == null || board.status == currentFilter;
      final matchesSearch =
          query.isEmpty ||
          board.name.toLowerCase().contains(query) ||
          board.qrCode.toLowerCase().contains(query) ||
          board.model.toLowerCase().contains(query) ||
          board.location.toLowerCase().contains(query) ||
          (board.serialNumber?.toLowerCase().contains(query) ?? false) ||
          (board.partIpn?.toLowerCase().contains(query) ?? false) ||
          (board.currentLocationCode?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<Part> get _filteredParts {
    final query = _searchQuery.value.toLowerCase();
    final currentFilter = _partFilter.value;
    final parts = context.read<BackendDataProvider>().parts;
    return parts.where((part) {
      final matchesFilter = currentFilter == PartFilterStatus.all ||
          (currentFilter == PartFilterStatus.lowStock && part.totalQuantity < part.minAmount) ||
          (currentFilter == PartFilterStatus.outOfStock && part.totalQuantity == 0);
      final matchesSearch = query.isEmpty ||
          part.name.toLowerCase().contains(query) ||
          part.ipn.toLowerCase().contains(query) ||
          (part.categoryName?.toLowerCase().contains(query) ?? false) ||
          (part.description?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  String _qrCodeLabel(Board board) {
    return board.qrCode.isEmpty ? 'QR chờ backend tạo' : board.qrCode;
  }

  String _inventoryLine(Board board) {
    return '';
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final boards = backend.boards;
    final parts = backend.parts;

    final totalParts = parts.length;
    final totalPartQty = parts.fold<double>(0.0, (sum, p) => sum + p.totalQuantity);
    final lowStockParts = parts.where((p) => p.totalQuantity < p.minAmount && p.totalQuantity > 0).length;
    final outOfStockParts = parts.where((p) => p.totalQuantity == 0).length;

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
                      // Mode Toggle segmented control
                      // _buildModeToggle(isDark),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentMode == WarehouseMode.boards ? 'Kho Bo mạch' : 'Kho Linh kiện',
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
                                  _currentMode == WarehouseMode.boards
                                      ? '${boards.length} bo mạch trong kho'
                                      : '$totalParts loại linh kiện trong kho',
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
                                  if (_currentMode == WarehouseMode.boards) {
                                    _showAddEditBoardDialog();
                                  } else {
                                    _showAddEditPartDialog();
                                  }
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
                              if (_currentMode == WarehouseMode.boards) ...[
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
                                      final qrCode = (result as String).trim();
                                      final backend = context.read<BackendDataProvider>();
                                      Board? matchedBoard;
                                      for (final b in backend.boards) {
                                        if (b.qrCode.toLowerCase() == qrCode.toLowerCase()) {
                                          matchedBoard = b;
                                          break;
                                        }
                                      }

                                      if (matchedBoard != null) {
                                        _showBoardDetail(matchedBoard, fromScan: true);
                                      } else {
                                        _searchQuery.value = qrCode;
                                        _searchController.text = qrCode;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Không tìm thấy bo mạch có mã QR: $qrCode'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    size: 16,
                                  ),
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
                            children: _currentMode == WarehouseMode.boards
                                ? [
                                    _buildLandscapeStatCard(
                                      '${boards.length}',
                                      'Tổng',
                                      LucideIcons.cpu,
                                      AppColors.primary,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      '${boards.where((b) => b.status == BoardStatus.available).length}',
                                      'Sẵn sàng',
                                      Icons.inventory_2_outlined,
                                      AppColors.success,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      '${boards.where((b) => b.status == BoardStatus.checkedOut).length}',
                                      'Đang dùng',
                                      LucideIcons.wrench,
                                      AppColors.warning,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      '${boards.where((b) => b.status == BoardStatus.maintenance).length}',
                                      'Bảo trì',
                                      Icons.warning_amber,
                                      AppColors.error,
                                      isDark,
                                    ),
                                  ]
                                : [
                                    _buildLandscapeStatCard(
                                      '$totalParts',
                                      'Tổng loại',
                                      Icons.widgets,
                                      AppColors.primary,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      totalPartQty.toStringAsFixed(0),
                                      'Tổng tồn kho',
                                      Icons.inventory_2_outlined,
                                      AppColors.success,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      '$lowStockParts',
                                      'Sắp hết',
                                      Icons.warning_amber,
                                      AppColors.warning,
                                      isDark,
                                    ),
                                    const SizedBox(width: 22),
                                    _buildLandscapeStatCard(
                                      '$outOfStockParts',
                                      'Hết hàng',
                                      Icons.error_outline,
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
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 98,
                          children: _currentMode == WarehouseMode.boards
                              ? [
                                  _buildCompactStatCard(
                                    '${boards.length}',
                                    'Tổng',
                                    LucideIcons.cpu,
                                    AppColors.primary,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    '${boards.where((b) => b.status == BoardStatus.available).length}',
                                    'Sẵn sàng',
                                    Icons.inventory_2_outlined,
                                    AppColors.success,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    '${boards.where((b) => b.status == BoardStatus.checkedOut).length}',
                                    'Đang dùng',
                                    LucideIcons.wrench,
                                    AppColors.warning,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    '${boards.where((b) => b.status == BoardStatus.maintenance).length}',
                                    'Bảo trì',
                                    Icons.warning_amber,
                                    AppColors.error,
                                    isDark,
                                  ),
                                ]
                              : [
                                  _buildCompactStatCard(
                                    '$totalParts',
                                    'Tổng loại',
                                    Icons.widgets,
                                    AppColors.primary,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    totalPartQty.toStringAsFixed(0),
                                    'Tổng tồn kho',
                                    Icons.inventory_2_outlined,
                                    AppColors.success,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    '$lowStockParts',
                                    'Sắp hết',
                                    Icons.warning_amber,
                                    AppColors.warning,
                                    isDark,
                                  ),
                                  _buildCompactStatCard(
                                    '$outOfStockParts',
                                    'Hết hàng',
                                    Icons.error_outline,
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
                                  hintText: _currentMode == WarehouseMode.boards
                                      ? 'Tìm tên, mã QR, model...'
                                      : 'Tìm tên, mã IPN, danh mục...',
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
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Filters
                      if (_currentMode == WarehouseMode.boards)
                        SizedBox(
                          height: 32,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Tất cả', null, boards.length),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Sẵn sàng',
                                  BoardStatus.available,
                                  boards
                                      .where(
                                        (b) => b.status == BoardStatus.available,
                                      )
                                      .length,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Đang dùng',
                                  BoardStatus.checkedOut,
                                  boards
                                      .where(
                                        (b) => b.status == BoardStatus.checkedOut,
                                      )
                                      .length,
                                ),
                                const SizedBox(width: 6),
                                _buildFilterChip(
                                  'Bảo trì',
                                  BoardStatus.maintenance,
                                  boards
                                      .where(
                                        (b) =>
                                            b.status == BoardStatus.maintenance,
                                      )
                                      .length,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 32,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildPartFilterChip('Tất cả', PartFilterStatus.all, totalParts),
                                const SizedBox(width: 6),
                                _buildPartFilterChip('Sắp hết', PartFilterStatus.lowStock, lowStockParts),
                                const SizedBox(width: 6),
                                _buildPartFilterChip('Hết hàng', PartFilterStatus.outOfStock, outOfStockParts),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // List
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_searchQuery, _filter, _partFilter]),
                    builder: (context, _) {
                      if (_currentMode == WarehouseMode.boards) {
                        final filtered = _filteredBoards;
                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () => context.read<BackendDataProvider>().loadBoards(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight - 220,
                                  child: Center(
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
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => context.read<BackendDataProvider>().loadBoards(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                          ),
                        );
                      } else {
                        final filtered = _filteredParts;
                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () => context.read<BackendDataProvider>().loadParts(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: constraints.maxHeight - 220,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('🔌', style: TextStyle(fontSize: 48)),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Không tìm thấy linh kiện',
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
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => context.read<BackendDataProvider>().loadParts(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPartListCard(filtered[index])
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
                          ),
                        );
                      }
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

  Widget _buildModeToggle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentMode = WarehouseMode.boards;
                  _searchQuery.value = '';
                  _searchController.clear();
                  _filter.value = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentMode == WarehouseMode.boards
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Bo mạch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentMode == WarehouseMode.boards
                          ? Colors.white
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentMode = WarehouseMode.parts;
                  _searchQuery.value = '';
                  _searchController.clear();
                  _partFilter.value = PartFilterStatus.all;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentMode == WarehouseMode.parts
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Linh kiện',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _currentMode == WarehouseMode.parts
                          ? Colors.white
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartFilterChip(String label, PartFilterStatus status, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<PartFilterStatus>(
      valueListenable: _partFilter,
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
              _partFilter.value = selected ? status : PartFilterStatus.all;
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

  Widget _buildLandscapeStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return _buildCompactStatCard(value, label, icon, color, isDark);
  }

  Widget _buildCompactStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final background = color.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
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
    final inventoryLine = _inventoryLine(board);
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
        padding: const EdgeInsets.all(12),
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
                  width: 36,
                  height: 36,
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
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 10,
                          height: 10,
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
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _qrCodeLabel(board),
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (inventoryLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        inventoryLine,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
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
            ),
            const Divider(height: 12),
            StatusBadge(status: board.status, size: 'sm'),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardListCard(Board board) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inventoryLine = _inventoryLine(board);
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _qrCodeLabel(board),
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Text(' · ', style: TextStyle(fontSize: 14)),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          board.location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (inventoryLine.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      inventoryLine,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

  Widget _buildPartListCard(Part part) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isOutOfStock = part.totalQuantity == 0;
    final bool isLowStock = part.totalQuantity < part.minAmount && part.totalQuantity > 0;
    final statusColor = isOutOfStock
        ? AppColors.error
        : isLowStock
            ? AppColors.warning
            : AppColors.success;
    final statusLabel = isOutOfStock
        ? 'Hết hàng'
        : isLowStock
            ? 'Sắp hết'
            : 'Đủ hàng';

    return InkWell(
      onTap: () {
        _showPartDetail(part);
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
                      Icons.widgets,
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
                    part.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        part.ipn,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Text(' · ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          part.categoryName ?? 'Không có danh mục',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Số lượng: ${part.totalQuantity.toStringAsFixed(0)} (Min: ${part.minAmount.toStringAsFixed(0)})',
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
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showPartDetail(Part part) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PartDetailSheet(
        part: part,
        onEdit: () {
          Navigator.pop(context);
          _showAddEditPartDialog(part: part);
        },
        onDelete: () {
          Navigator.pop(context);
          _showPartDeleteConfirmDialog(part);
        },
      ),
    );
  }

  void _showPartDeleteConfirmDialog(Part part) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa linh kiện'),
        content: Text('Bạn có chắc chắn muốn xóa linh kiện ${part.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<BackendDataProvider>().deletePart(part);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã xóa linh kiện ${part.name}')),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddEditPartDialog({Part? part}) {
    final isEditing = part != null;
    final ipnCtrl = TextEditingController(text: part?.ipn ?? '');
    final nameCtrl = TextEditingController(text: part?.name ?? '');
    final minAmountCtrl = TextEditingController(text: part?.minAmount.toStringAsFixed(0) ?? '0');
    final categoryCtrl = TextEditingController(text: part?.categoryName ?? '');
    final descCtrl = TextEditingController(text: part?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        isEditing ? 'Chỉnh sửa linh kiện' : 'Thêm linh kiện mới',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: ipnCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Mã IPN *',
                                  hintText: 'VD: IPN-001, CAP-10UF-50V...',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Tên linh kiện *',
                                  hintText: 'VD: Tụ điện 10uF 50V',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: minAmountCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Định mức tối thiểu (để báo sắp hết)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: categoryCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Danh mục / Phân loại',
                                  hintText: 'VD: Tụ điện, Điện trở...',
                                ),
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
                            onPressed: () async {
                              final ipn = ipnCtrl.text.trim();
                              final name = nameCtrl.text.trim();
                              final minAmountVal = double.tryParse(minAmountCtrl.text.trim()) ?? 0.0;
                              if (ipn.isEmpty || name.isEmpty) return;

                              final backend = context.read<BackendDataProvider>();
                              final body = <String, dynamic>{
                                'ipn': ipn,
                                'name': name,
                                'minAmount': minAmountVal,
                                'categoryName': categoryCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                              };

                              if (isEditing) {
                                await backend.api.put(
                                  '/api/v1/parts/${part.id}',
                                  body: body,
                                );
                              } else {
                                await backend.api.post(
                                  '/api/v1/parts',
                                  body: body,
                                );
                              }
                              await backend.loadParts();
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Đã cập nhật linh kiện'
                                        : 'Đã thêm linh kiện mới',
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

  void _showBoardDetail(Board board, {bool fromScan = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BoardDetailSheet(
        board: board,
        fromScan: fromScan,
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
            onPressed: () async {
              await context.read<BackendDataProvider>().deleteBoard(board);
              if (!context.mounted) return;
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
    final serialCtrl = TextEditingController(text: board?.serialNumber ?? '');
    final partIdCtrl = TextEditingController(text: board?.partId ?? '');
    final currentLocationIdCtrl =
        TextEditingController(text: board?.currentLocationId ?? '');
    final descCtrl = TextEditingController(text: board?.description ?? '');
    final quantityCtrl = TextEditingController(text: board?.quantity.toString() ?? '1');
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
                                controller: locationCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Vị trí',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: quantityCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Số lượng *',
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
                                  label = s.label;
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedStatus = val);
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
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty) return;

                              final serialNumber = _optionalText(
                                serialCtrl.text,
                              );
                              final partId = _optionalText(partIdCtrl.text);
                              final currentLocationId = _optionalText(
                                currentLocationIdCtrl.text,
                              );


                              final backend = context
                                  .read<BackendDataProvider>();
                              final body = <String, dynamic>{
                                'name': nameCtrl.text.trim(),
                                'category': modelCtrl.text.trim(),
                                'location': locationCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'serialNumber': serialNumber,
                                'quantity': int.tryParse(quantityCtrl.text) ?? 1,
                                if (isEditing)
                                  'status': _boardStatusName(selectedStatus),
                              };
                              if (partId != null) {
                                body['partId'] = partId;
                              }
                              if (currentLocationId != null) {
                                body['currentLocationId'] = currentLocationId;
                              }
                              if (isEditing) {
                                await backend.api.patch(
                                  '/api/v1/boards/${board.id}',
                                  body: body,
                                );
                              } else {
                                await backend.api.post(
                                  '/api/v1/boards',
                                  body: body,
                                );
                              }
                              await backend.loadBoards();
                              if (!context.mounted) return;
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

  String _boardStatusName(BoardStatus status) {
    return status.backendName;
  }
}

class _BoardDetailSheet extends StatefulWidget {
  final Board board;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// Nếu true: mở từ quét QR → cho phép thao tác Lấy/Trả.
  /// Nếu false: mở từ click thẻ danh sách → chỉ xem/sửa/xóa.
  final bool fromScan;

  const _BoardDetailSheet({
    required this.board,
    required this.onEdit,
    required this.onDelete,
    this.fromScan = false,
  });

  @override
  State<_BoardDetailSheet> createState() => _BoardDetailSheetState();
}

class _BoardDetailSheetState extends State<_BoardDetailSheet> {
  bool _isLoading = false;
  bool _isDone = false;
  List<BoardHistoryItem>? _history;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });
    try {
      final history = await context.read<BackendDataProvider>().getBoardHistory(widget.board.id);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  /// Returns a map with keys: returnType, returnQuantity, reason, notes
  /// Returns null if user cancelled.
  Future<Map<String, dynamic>?> _showReturnDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesController = TextEditingController();
    final reasonController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    String selectedType = 'FULL';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Trả bo mạch'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn hình thức trả:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // FULL option
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedType = 'FULL'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedType == 'FULL' ? AppColors.primary : Colors.grey.withOpacity(0.4),
                            width: selectedType == 'FULL' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: selectedType == 'FULL'
                              ? AppColors.primary.withOpacity(0.07)
                              : (isDark ? AppColors.surfaceDark : Colors.white),
                        ),
                        child: Row(
                          children: [
                            const Text('✅', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trả lại hết',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'FULL' ? AppColors.primary : null,
                                    ),
                                  ),
                                  Text(
                                    'Trả toàn bộ số lượng đã lấy. Nếu thiếu, ghi rõ lý do.',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // PARTIAL option
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedType = 'PARTIAL'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedType == 'PARTIAL' ? AppColors.primary : Colors.grey.withOpacity(0.4),
                            width: selectedType == 'PARTIAL' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: selectedType == 'PARTIAL'
                              ? AppColors.primary.withOpacity(0.07)
                              : (isDark ? AppColors.surfaceDark : Colors.white),
                        ),
                        child: Row(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trả lại một phần',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selectedType == 'PARTIAL' ? AppColors.primary : null,
                                    ),
                                  ),
                                  Text(
                                    'Chỉ trả lại một phần, bo mạch vẫn đang được sử dụng.',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Partial quantity input (only shown for PARTIAL)
                    if (selectedType == 'PARTIAL') ...[
                      Text(
                        'Số lượng trả lại *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Nhập số lượng trả...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Reason field
                    Text(
                      selectedType == 'FULL' ? 'Lý do bị thiếu (nếu không đủ số lượng)' : 'Lý do trả một phần',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: selectedType == 'FULL'
                            ? 'Ví dụ: Mất linh kiện trong quá trình sửa...'
                            : 'Ví dụ: Chỉ dùng xong một phần...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // General notes
                    Text(
                      'Ghi chú sau sửa chữa',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ghi chú thêm về trạng thái sau khi sử dụng...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = selectedType == 'PARTIAL'
                        ? int.tryParse(quantityController.text.trim())
                        : null;
                    if (selectedType == 'PARTIAL' && (qty == null || qty < 1)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập số lượng trả hợp lệ')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'returnType': selectedType,
                      'returnQuantity': qty,
                      'reason': reasonController.text.trim(),
                      'notes': notesController.text.trim(),
                    });
                  },
                  child: Text(selectedType == 'FULL' ? 'Xác nhận trả hết' : 'Xác nhận trả một phần'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHistoryDetailDialog(BoardHistoryItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final takenAtStr = item.takenAt != null
        ? "${item.takenAt!.day}/${item.takenAt!.month}/${item.takenAt!.year} ${item.takenAt!.hour.toString().padLeft(2, '0')}:${item.takenAt!.minute.toString().padLeft(2, '0')}"
        : "Không rõ";
    final returnedAtStr = item.returnedAt != null
        ? "${item.returnedAt!.day}/${item.returnedAt!.month}/${item.returnedAt!.year} ${item.returnedAt!.hour.toString().padLeft(2, '0')}:${item.returnedAt!.minute.toString().padLeft(2, '0')}"
        : "Chưa trả (Đang mượn)";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.history,
                color: isDark ? Colors.blueAccent : Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              const Text('Chi tiết mượn/trả'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalDetailRow('Người mượn', item.takenByName, isDark),
                _buildModalDetailRow('Số lượng lấy', item.quantity.toString(), isDark),
                if (item.repairBrand != null && item.repairBrand!.isNotEmpty)
                  _buildModalDetailRow('Hãng sửa chữa', item.repairBrand!, isDark),
                _buildModalDetailRow('Thời gian lấy', takenAtStr, isDark),
                _buildModalDetailRow('Lý do lấy', item.checkoutReason, isDark),
                const Divider(height: 24),
                _buildModalDetailRow('Trạng thái trả', item.returnedAt != null ? 'Đã trả' : 'Đang mượn', isDark,
                  valueColor: item.returnedAt != null ? Colors.green : Colors.orange,
                  valueBold: true,
                ),
                _buildModalDetailRow('Thời gian trả', returnedAtStr, isDark),
                _buildModalDetailRow('Thông tin sửa chữa/Lý do trả', item.returnReason, isDark),
                if (item.repairOrderId != null && item.repairOrderId!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildModalDetailRow('Đơn sửa chữa (ID)', item.repairOrderId!, isDark),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value, bool isDark, {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCheckoutFormDialog() async {
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Lấy bo mạch ra khỏi kho'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Số lượng lấy (Tồn kho: ${widget.board.quantity}) *',
                        hintText: 'Mặc định 1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (sử dụng cho hãng nào)',
                        hintText: 'Nhập hãng sử dụng hoặc ghi chú khác...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text) ?? 1;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Số lượng phải lớn hơn 0')),
                      );
                      return;
                    }
                    if (qty > widget.board.quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Số lượng lấy ($qty) vượt quá tồn kho (${widget.board.quantity})')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'quantity': qty,
                      'repairBrand': null,
                      'repairOrderId': null,
                      'note': noteCtrl.text.trim(),
                    });
                  },
                  child: const Text('Xác nhận lấy'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction({Map<String, dynamic>? returnData}) async {
    setState(() {
      _isLoading = true;
    });

    final isOnline = await context.read<NetworkProvider>().checkNow();
    final isReturn = widget.board.status == BoardStatus.checkedOut;

    try {
      if (isOnline) {
        if (isReturn) {
          final returnType = (returnData?['returnType'] as String?) ?? 'FULL';
          final returnQuantity = returnData?['returnQuantity'] as int?;
          final reason = returnData?['reason'] as String?;
          final notes = returnData?['notes'] as String?;
          await context.read<BackendDataProvider>().returnBoard(
                widget.board.id,
                checkoutId: widget.board.checkoutId,
                returnType: returnType,
                returnQuantity: returnQuantity,
                reason: reason,
                notes: notes,
              );
        } else {
          final checkoutData = await _showCheckoutFormDialog();
          if (checkoutData == null) {
            setState(() => _isLoading = false);
            return;
          }
          await context.read<BackendDataProvider>().checkoutBoard(
                widget.board.id,
                quantity: (checkoutData['quantity'] as num?)?.toInt(),
                repairBrand: checkoutData['repairBrand'] as String?,
                repairOrderId: checkoutData['repairOrderId'] as String?,
                note: checkoutData['note'] as String?,
              );
        }
      } else if (mounted) {
        context.read<PendingSyncProvider>().addAction(
          type: isReturn
              ? PendingSyncType.boardReturn
              : PendingSyncType.boardCheckout,
          title: isReturn ? 'Trả bo mạch' : 'Lấy bo mạch',
          description: '${widget.board.name} - ${widget.board.qrCode}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thao tác thất bại: $e'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

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
    final isEmployee = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).isEmployee;

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

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          widget.board.qrCode.isEmpty ? 'QR chờ backend tạo' : widget.board.qrCode,
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
                    icon: const Icon(
                      Icons.edit,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    onPressed: widget.onEdit,
                    tooltip: 'Chỉnh sửa',
                  ),
                  if (!isEmployee)
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: AppColors.error,
                      ),
                      onPressed: widget.onDelete,
                      tooltip: 'Xóa',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // QR Code Visualizer Card
              if (widget.board.qrCode.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.board.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: QrImageView(
                                  data: widget.board.qrCode,
                                  version: QrVersions.auto,
                                  size: 220.0,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.board.qrCode,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Đóng'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Tooltip(
                    message: 'Nhấn để phóng to',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          QrImageView(
                            data: widget.board.qrCode,
                            version: QrVersions.auto,
                            size: 90.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Mã QR linh kiện',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.fullscreen,
                                      size: 14,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.board.qrCode,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                    fontFamily: 'monospace',
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 45,
                            child: OutlinedButton(
                              onPressed: () {
                                final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${Uri.encodeComponent(widget.board.qrCode)}';
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  builder: (ctx) => Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'TEM PDF QR ĐỊNH DANH',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.blue.shade200, width: 2),
                                          ),
                                          child: Column(
                                            children: [
                                              QrImageView(
                                                data: widget.board.qrCode,
                                                version: QrVersions.auto,
                                                size: 160.0,
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Text(
                                                      'MÃ CODE QR:',
                                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                                    ),
                                                    Text(
                                                      widget.board.qrCode,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                        letterSpacing: 1.2,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                widget.board.name,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.picture_as_pdf),
                                            label: const Text('In tem PDF (Khuyên dùng cho Eleph-label)'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await Future.delayed(const Duration(milliseconds: 150));
                                              if (!mounted) return;
                                              await QrShareHelper.shareQrPdfToElephLabel(
                                                context: context,
                                                qrData: widget.board.qrCode,
                                                title: widget.board.name,
                                                subtitle: widget.board.model.isNotEmpty ? 'Model: ${widget.board.model}' : null,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.label_outline),
                                            label: const Text('Mở trong Eleph-label'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              Navigator.pop(ctx);
                                              await Future.delayed(const Duration(milliseconds: 150));
                                              if (!mounted) return;
                                              await QrShareHelper.shareQrCodeToElephLabel(
                                                context: context,
                                                qrData: widget.board.qrCode,
                                                title: widget.board.name,
                                                subtitle: widget.board.model.isNotEmpty ? 'Model: ${widget.board.model}' : null,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 44,
                                           child: TextButton.icon(
                                             icon: const Icon(Icons.copy),
                                             label: const Text('Sao chép mã QR vào bộ nhớ tạm'),
                                             onPressed: () async {
                                               Navigator.pop(ctx);
                                               await Future.delayed(const Duration(milliseconds: 150));
                                               if (!mounted) return;
                                               await QrShareHelper.copyAndLaunchElephLabel(
                                                 context: context,
                                                 qrData: widget.board.qrCode,
                                               );
                                             },
                                           ),
                                         ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    size: 16,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Xuất PDF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Info
              _buildInfoRow(
                'Trạng thái',
                null,
                child: StatusBadge(status: widget.board.status),
              ),
              _buildInfoRow('Vị trí', widget.board.location),
              _buildInfoRow('Số lượng', widget.board.quantity.toString()),
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

              // Lịch sử lấy/trả
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Lịch sử mượn/trả',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_history == null || _history!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Chưa có lịch sử mượn/trả.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                )
              else
                ..._history!.map((item) {
                  final takenAtStr = item.takenAt != null
                      ? "${item.takenAt!.day}/${item.takenAt!.month}/${item.takenAt!.year} ${item.takenAt!.hour.toString().padLeft(2, '0')}:${item.takenAt!.minute.toString().padLeft(2, '0')}"
                      : "Không rõ";
                  final returnedAtStr = item.returnedAt != null
                      ? "${item.returnedAt!.day}/${item.returnedAt!.month}/${item.returnedAt!.year} ${item.returnedAt!.hour.toString().padLeft(2, '0')}:${item.returnedAt!.minute.toString().padLeft(2, '0')}"
                      : "Đang mượn";

                  return GestureDetector(
                    onTap: () => _showHistoryDetailDialog(item),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
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
                              Text(
                                item.takenByName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.returnedAt != null
                                      ? (isDark ? Colors.green.withOpacity(0.15) : const Color(0xFFDCFCE7))
                                      : (isDark ? Colors.orange.withOpacity(0.15) : const Color(0xFFFFEDD5)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.returnedAt != null ? 'Đã trả' : 'Đang mượn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.returnedAt != null
                                        ? (isDark ? Colors.greenAccent : const Color(0xFF15803D))
                                        : (isDark ? Colors.orangeAccent : const Color(0xFFC2410C)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.play_arrow_outlined,
                                size: 14,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Lấy: $takenAtStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.stop_circle_outlined,
                                size: 14,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Trả: $returnedAtStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 8),
                            const SizedBox(height: 4),
                            Text(
                              'Ghi chú/Sửa chữa:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                    ],
                  ),
                ),
              ),
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
              else if (!widget.fromScan)
                // Mở từ click thẻ danh sách → chỉ hiện nút Đóng
                // Gợi ý người dùng cần quét mã để thao tác
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.amber.withOpacity(0.12)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.amber.withOpacity(0.3)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 18,
                            color: isDark ? Colors.amber : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Quét mã QR linh kiện để thực hiện thao tác Lấy / Trả bo mạch.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ],
                )
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
                          onPressed: () async {
                            final returnData = await _showReturnDialog();
                            if (returnData == null) return;
                            await _handleAction(returnData: returnData);
                          },
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
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  child ??
                  Text(
                    value ?? '',
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartDetailSheet extends StatefulWidget {
  final Part part;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PartDetailSheet({
    required this.part,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PartDetailSheet> createState() => _PartDetailSheetState();
}

class _PartDetailSheetState extends State<_PartDetailSheet> {
  bool _isLoading = false;

  void _showAdjustStockDialog() {
    final locationCodeCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Điều chỉnh tồn kho'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locationCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã vị trí lưu kho *',
                  hintText: 'VD: DEFAULT, Kệ A - Hàng 2...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Số lượng tồn kho mới *',
                  hintText: 'Nhập số lượng thực tế trong kho',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú lý do điều chỉnh',
                  hintText: 'Nhập thêm hàng, kiểm kho...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final locCode = locationCodeCtrl.text.trim();
              final amountStr = amountCtrl.text.trim();
              if (locCode.isEmpty || amountStr.isEmpty) return;

              final amount = double.tryParse(amountStr);
              if (amount == null || amount < 0) return;

              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);

              try {
                await context.read<BackendDataProvider>().adjustPartStock(
                  widget.part.id,
                  locationCode: locCode,
                  amount: amount,
                  note: noteCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Điều chỉnh tồn kho thành công')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                  Navigator.pop(context); // Close detail sheet to refresh
                }
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final part = widget.part;

    final bool isOutOfStock = part.totalQuantity == 0;
    final bool isLowStock = part.totalQuantity < part.minAmount && part.totalQuantity > 0;
    final statusColor = isOutOfStock
        ? AppColors.error
        : isLowStock
            ? AppColors.warning
            : AppColors.success;
    final statusLabel = isOutOfStock
        ? 'Hết hàng'
        : isLowStock
            ? 'Sắp hết'
            : 'Đủ hàng';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            part.categoryName ?? 'Chưa rõ danh mục',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: widget.onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const Divider(height: 24),

            // Specs
            Row(
              children: [
                Expanded(
                  child: _buildSpecItem('MÃ IPN', part.ipn, isDark, mono: true),
                ),
                Expanded(
                  child: _buildSpecItem('TỔNG TỒN', part.totalQuantity.toStringAsFixed(0), isDark, valueColor: AppColors.success),
                ),
                Expanded(
                  child: _buildSpecItem('ĐỊNH MỨC MIN', part.minAmount.toStringAsFixed(0), isDark),
                ),
              ],
            ),

            if (part.description != null && part.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Mô tả',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                part.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'VỊ TRÍ LƯU KHO & SỐ LƯỢNG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            if (part.lots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có linh kiện này ở bất kỳ vị trí kho nào. Nhấp "Điều chỉnh tồn kho" để nhập kho.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: part.lots.length,
                  itemBuilder: (context, index) {
                    final lot = part.lots[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lot.storeLocationName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Mã vị trí: ${lot.storeLocationCode}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          Text(
                            lot.amount.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _showAdjustStockDialog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Điều chỉnh số lượng tồn kho', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, bool isDark, {bool mono = false, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: mono ? 'monospace' : null,
            color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}