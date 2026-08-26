import 'package:flutter/material.dart';
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
import '../models/store_location.dart';
import '../widgets/location_picker_dialog.dart';
import 'scanner_page.dart';
import 'location_management_page.dart';

enum WarehouseMode { all, boards, parts }
enum PartFilterStatus { all, lowStock, outOfStock }
enum PartSearchMethod { general, locationQr }

class LocationGroupItem {
  final Part part;
  final PartLot lot;
  LocationGroupItem({required this.part, required this.lot});
}

class LocationGroup {
  final String locationCode;
  final String locationName;
  final List<LocationGroupItem> items;

  LocationGroup({
    required this.locationCode,
    required this.locationName,
    required this.items,
  });

  double get totalQuantity => items.fold(0.0, (sum, i) => sum + i.lot.amount);
}

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
  WarehouseMode _currentMode = WarehouseMode.all;
  PartSearchMethod _partSearchMethod = PartSearchMethod.general;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackendDataProvider>().loadBoards();
      context.read<BackendDataProvider>().loadParts();
      context.read<BackendDataProvider>().loadLocations();
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
    final query = _searchQuery.value.toLowerCase().trim();
    final currentFilter = _filter.value;
    final partFilter = _partFilter.value;
    final boards = context.read<BackendDataProvider>().boards;
    return boards.where((board) {
      final matchesFilter =
          currentFilter == null || board.status == currentFilter;
      final matchesStockFilter = partFilter == PartFilterStatus.all ||
          (partFilter == PartFilterStatus.lowStock && board.quantity < board.minQuantity && board.quantity > 0) ||
          (partFilter == PartFilterStatus.outOfStock && board.quantity == 0);
      final matchesSearch =
          query.isEmpty ||
          board.name.toLowerCase().contains(query) ||
          board.qrCode.toLowerCase().contains(query) ||
          board.model.toLowerCase().contains(query) ||
          board.location.toLowerCase().contains(query) ||
          (board.serialNumber?.toLowerCase().contains(query) ?? false) ||
          (board.partIpn?.toLowerCase().contains(query) ?? false) ||
          (board.currentLocationCode?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesStockFilter && matchesSearch;
    }).toList();
  }

  List<Part> get _filteredParts {
    final query = _searchQuery.value.toLowerCase().trim();
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
          (part.description?.toLowerCase().contains(query) ?? false) ||
          part.lots.any((lot) =>
              lot.storeLocationCode.toLowerCase().contains(query) ||
              lot.storeLocationName.toLowerCase().contains(query));
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<dynamic> get _filteredUnifiedItems {
    final boards = _filteredBoards;
    final parts = _filteredParts;
    final List<dynamic> merged = [...boards, ...parts];
    merged.sort((a, b) {
      final nameA = (a is Board ? a.name : (a as Part).name).toLowerCase();
      final nameB = (b is Board ? b.name : (b as Part).name).toLowerCase();
      return nameA.compareTo(nameB);
    });
    return merged;
  }

  List<LocationGroup> get _filteredLocationGroups {
    final filtered = _filteredParts;
    final query = _searchQuery.value.toLowerCase().trim();
    final Map<String, LocationGroup> groupMap = {};

    for (final part in filtered) {
      if (part.lots.isEmpty) {
        final key = 'UNASSIGNED';
        if (!groupMap.containsKey(key)) {
          groupMap[key] = LocationGroup(
            locationCode: 'N/A',
            locationName: 'Chưa xếp vị trí',
            items: [],
          );
        }
        groupMap[key]!.items.add(LocationGroupItem(
          part: part,
          lot: PartLot(
            id: '',
            storeLocationId: '',
            storeLocationCode: 'N/A',
            storeLocationName: 'Chưa xếp vị trí',
            amount: part.totalQuantity,
          ),
        ));
      } else {
        for (final lot in part.lots) {
          final locCode = lot.storeLocationCode.isNotEmpty ? lot.storeLocationCode : 'N/A';
          final locName = lot.storeLocationName.isNotEmpty ? lot.storeLocationName : locCode;

          if (query.isNotEmpty && _partSearchMethod == PartSearchMethod.locationQr) {
            final matchesLoc = locCode.toLowerCase().contains(query) || locName.toLowerCase().contains(query);
            final matchesPart = part.name.toLowerCase().contains(query) || part.ipn.toLowerCase().contains(query);
            if (!matchesLoc && !matchesPart) continue;
          }

          final key = lot.storeLocationId.isNotEmpty ? lot.storeLocationId : locCode;
          if (!groupMap.containsKey(key)) {
            groupMap[key] = LocationGroup(
              locationCode: locCode,
              locationName: locName,
              items: [],
            );
          }
          groupMap[key]!.items.add(LocationGroupItem(part: part, lot: lot));
        }
      }
    }

    return groupMap.values.toList();
  }

  String _inventoryLine(Board board) {
    if (board.minQuantity > 0) {
      return 'Số lượng: ${board.quantity} (Min: ${board.minQuantity})';
    }
    return 'Số lượng: ${board.quantity}';
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

    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape = screenSize.width > screenSize.height && screenSize.height < 600;
    final wide = screenSize.width >= 760;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
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
                                  'Kho Hàng',
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
                                  boards.isEmpty && parts.isEmpty
                                      ? '0 mặt hàng trong kho'
                                      : parts.isNotEmpty && boards.isNotEmpty
                                          ? '${parts.length} linh kiện, ${boards.length} bo mạch'
                                          : parts.isNotEmpty
                                              ? '${parts.length} loại linh kiện'
                                              : '${boards.length} bo mạch trong kho',
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
                                  _showAddSelectionSheet();
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text(
                                  'Thêm',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ScannerPage(),
                                    ),
                                  );
                                  if (result != null && mounted) {
                                    await _handleWarehouseQrScan(result as String);
                                  }
                                },
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Quét',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Quản lý Vị trí kho',
                                icon: const Icon(Icons.location_on_outlined, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                                  padding: const EdgeInsets.all(8),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LocationManagementPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
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
                                  hintText: _partSearchMethod == PartSearchMethod.locationQr
                                      ? 'Nhập hoặc quét mã QR vị trí (VD: LOC-A1)...'
                                      : 'Tìm tên, mã IPN, vị trí, danh mục...',
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

                      // Filters for Parts
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(height: 8),
                          // Search Method Switcher Bar
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text(
                                  'Phương thức tìm:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search, size: 12),
                                      SizedBox(width: 4),
                                      Text('🔍 Tên / IPN', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  selected: _partSearchMethod == PartSearchMethod.general,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _partSearchMethod = PartSearchMethod.general;
                                      });
                                    }
                                  },
                                  selectedColor: AppColors.primary.withOpacity(0.15),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: _partSearchMethod == PartSearchMethod.general
                                        ? AppColors.primary
                                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    fontWeight: _partSearchMethod == PartSearchMethod.general ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _partSearchMethod == PartSearchMethod.general
                                        ? AppColors.primary
                                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on, size: 12),
                                      SizedBox(width: 4),
                                      Text('📍 Vị trí / Quét QR', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  selected: _partSearchMethod == PartSearchMethod.locationQr,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _partSearchMethod = PartSearchMethod.locationQr;
                                      });
                                    }
                                  },
                                  selectedColor: AppColors.primary.withOpacity(0.15),
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: _partSearchMethod == PartSearchMethod.locationQr
                                        ? AppColors.primary
                                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    fontWeight: _partSearchMethod == PartSearchMethod.locationQr ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _partSearchMethod == PartSearchMethod.locationQr
                                        ? AppColors.primary
                                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ),
                          if (_partSearchMethod == PartSearchMethod.locationQr && _searchQuery.value.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.qr_code_scanner, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Đang lọc vị trí: "${_searchQuery.value}"',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _searchQuery.value = '';
                                    },
                                    child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
                      final double emptyViewHeight = (screenSize.height - 220).clamp(150.0, 600.0);

                      if (backend.isLoading && boards.isEmpty && parts.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (_currentMode == WarehouseMode.all) {
                        if (_partSearchMethod == PartSearchMethod.locationQr) {
                          final locationGroups = _filteredLocationGroups;
                          if (locationGroups.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: () => Future.wait([
                                context.read<BackendDataProvider>().loadBoards(),
                                context.read<BackendDataProvider>().loadParts(),
                                context.read<BackendDataProvider>().loadLocations(),
                              ]),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: emptyViewHeight,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('📍', style: TextStyle(fontSize: 48)),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Không tìm thấy mặt hàng ở vị trí này',
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
                                            'Thử đổi từ khóa hoặc quét lại mã QR vị trí khác',
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
                            onRefresh: () => Future.wait([
                              context.read<BackendDataProvider>().loadBoards(),
                              context.read<BackendDataProvider>().loadParts(),
                              context.read<BackendDataProvider>().loadLocations(),
                            ]),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: locationGroups.length,
                              itemBuilder: (context, index) {
                                return _buildLocationGroupCard(locationGroups[index]);
                              },
                            ),
                          );
                        }

                        final filtered = _filteredUnifiedItems;
                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () => Future.wait([
                              context.read<BackendDataProvider>().loadBoards(),
                              context.read<BackendDataProvider>().loadParts(),
                              context.read<BackendDataProvider>().loadLocations(),
                            ]),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: emptyViewHeight,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('📦', style: TextStyle(fontSize: 48)),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Không tìm thấy mặt hàng nào',
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
                                          'Thử thay đổi từ khóa tìm kiếm hoặc bộ lọc',
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
                          onRefresh: () => Future.wait([
                            context.read<BackendDataProvider>().loadBoards(),
                            context.read<BackendDataProvider>().loadParts(),
                            context.read<BackendDataProvider>().loadLocations(),
                          ]),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              if (item is Board) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildBoardListCard(item),
                                );
                              } else if (item is Part) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildPartListCard(item),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        );
                      } else if (_currentMode == WarehouseMode.boards) {
                        final filtered = _filteredBoards;
                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () => context.read<BackendDataProvider>().loadBoards(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: emptyViewHeight,
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
                                child: _buildBoardListCard(filtered[index]),
                              );
                            },
                          ),
                        );
                      } else {
                        if (_partSearchMethod == PartSearchMethod.locationQr) {
                          final locationGroups = _filteredLocationGroups;
                          if (locationGroups.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: () => context.read<BackendDataProvider>().loadParts(),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: emptyViewHeight,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('📍', style: TextStyle(fontSize: 48)),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Không tìm thấy linh kiện ở vị trí này',
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
                                            'Thử đổi từ khóa hoặc quét lại mã QR vị trí khác',
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
                              itemCount: locationGroups.length,
                              itemBuilder: (context, index) {
                                return _buildLocationGroupCard(locationGroups[index]);
                              },
                            ),
                          );
                        }

                        final filtered = _filteredParts;
                        if (filtered.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: () => context.read<BackendDataProvider>().loadParts(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: emptyViewHeight,
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
                                child: _buildPartListCard(filtered[index]),
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
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

  Widget _buildModeToggle(bool isDark, int boardsCount, int partsCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          _buildModeToggleItem(
            mode: WarehouseMode.all,
            title: 'Tất cả (${boardsCount + partsCount})',
            icon: Icons.all_inbox_rounded,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _buildModeToggleItem(
            mode: WarehouseMode.boards,
            title: 'Bo mạch ($boardsCount)',
            icon: LucideIcons.cpu,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _buildModeToggleItem(
            mode: WarehouseMode.parts,
            title: 'Linh kiện ($partsCount)',
            icon: Icons.precision_manufacturing,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleItem({
    required WarehouseMode mode,
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentMode = mode;
            _searchQuery.value = '';
            _searchController.clear();
            _filter.value = null;
            _partFilter.value = PartFilterStatus.all;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllModeFilterChip(String label, WarehouseMode mode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentMode == mode;

    return SizedBox(
      height: 32,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _currentMode = mode;
            _searchQuery.value = '';
            _searchController.clear();
          });
        },
        backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _showAddSelectionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 16),
            Text(
              'Thêm mới vào Kho',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.cpu, color: AppColors.info, size: 22),
              ),
              title: Text(
                'Bo mạch mới',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              subtitle: Text(
                'Tạo hồ sơ theo dõi bo mạch / thiết bị sửa chữa',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditBoardDialog();
              },
            ),
            const Divider(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.precision_manufacturing, color: AppColors.success, size: 22),
              ),
              title: Text(
                'Linh kiện mới',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              subtitle: Text(
                'Thêm linh kiện điện tử, số lượng tồn kho và vị trí lưu trữ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditPartDialog();
              },
            ),
            const Divider(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: AppColors.primary, size: 22),
              ),
              title: Text(
                'Vị trí lưu kho mới',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              subtitle: Text(
                'Tạo mã kệ / ngăn lưu trữ mới cho bo mạch và linh kiện',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                showCreateStoreLocationDialog(context);
              },
            ),
            const Divider(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.mapPin, color: AppColors.info, size: 22),
              ),
              title: Text(
                'Quản lý Vị trí kho & Kệ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              subtitle: Text(
                'Xem danh sách kệ hàng, sửa thông tin, xóa vị trí và quét QR',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationManagementPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
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
    return SizedBox(
      width: 140,
      child: _buildCompactStatCard(value, label, icon, color, isDark),
    );
  }

  Widget _buildCompactStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final background = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, size: 11, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
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
                    if (board.model.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Model: ${board.model}',
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
                        board.model.isNotEmpty ? board.model : 'Bo mạch',
                        style: TextStyle(
                          fontSize: 14,
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

  Widget _buildLocationGroupCard(LocationGroup group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${group.locationName} (${group.locationCode})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.items.length} loại · SL: ${group.totalQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            itemBuilder: (context, index) {
              final item = group.items[index];
              return ListTile(
                dense: true,
                onTap: () => _showPartDetail(item.part),
                leading: const Icon(Icons.widgets_outlined, size: 18, color: Color(0xFF64748B)),
                title: Text(
                  item.part.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'IPN: ${item.part.ipn} · Tồn: ${item.part.totalQuantity.toStringAsFixed(0)} (Min: ${item.part.minAmount.toStringAsFixed(0)})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Kệ: ${item.lot.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                        ),
                      ),
                    ),
                    if (item.lot.amount > 0) ...[
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          _showPartCheckoutDialog(
                            context,
                            part: item.part,
                            initialLot: item.lot,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Lấy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
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
        onCheckout: () {
          Navigator.pop(context);
          _showPartCheckoutDialog(context, part: part);
        },
      ),
    );
  }

  void _showPartCheckoutDialog(
    BuildContext context, {
    required Part part,
    PartLot? initialLot,
  }) {
    final availableLots = part.lots.where((l) => l.amount > 0).toList();
    if (availableLots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linh kiện ${part.name} hiện không có tồn kho ở vị trí nào để lấy.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    PartLot selectedLot = initialLot != null && availableLots.any((l) => l.id == initialLot.id)
        ? availableLots.firstWhere((l) => l.id == initialLot.id)
        : availableLots.first;

    final qtyCtrl = TextEditingController(text: '1');
    String selectedPurpose = 'Sửa chữa thiết bị';
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.outbox, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Lấy linh kiện out kho',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IPN: ${part.ipn}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location selection
                  const Text(
                    'Vị trí lấy hàng *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedLot.id,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: availableLots.map((lot) {
                      return DropdownMenuItem<String>(
                        value: lot.id,
                        child: Text(
                          '📍 ${lot.storeLocationName} (${lot.storeLocationCode}) · Tồn: ${lot.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() {
                          selectedLot = availableLots.firstWhere((l) => l.id == val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Quantity input
                  Text(
                    'Số lượng lấy * (Tối đa: ${selectedLot.amount.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                      hintText: 'Nhập số lượng',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Purpose
                  const Text(
                    'Mục đích sử dụng',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedPurpose,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Sửa chữa thiết bị', child: Text('Sửa chữa thiết bị')),
                      DropdownMenuItem(value: 'Thay thế linh kiện hỏng', child: Text('Thay thế linh kiện hỏng')),
                      DropdownMenuItem(value: 'Xuất kiểm thử / R&D', child: Text('Xuất kiểm thử / R&D')),
                      DropdownMenuItem(value: 'Xuất dự phòng', child: Text('Xuất dự phòng')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác (ghi rõ bên dưới)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedPurpose = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  const Text(
                    'Ghi chú / Đơn sửa chữa',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                      hintText: 'VD: Thay IC nguồn cho đơn #RO-1024...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final qty = double.tryParse(qtyCtrl.text.trim());
                        if (qty == null || qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập số lượng hợp lệ')),
                          );
                          return;
                        }
                        if (qty > selectedLot.amount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Số lượng vượt quá tồn tại kệ (${selectedLot.amount})')),
                          );
                          return;
                        }

                        setDlgState(() => isSubmitting = true);
                        try {
                          await context.read<BackendDataProvider>().checkoutPart(
                            part.id,
                            storeLocationId: selectedLot.storeLocationId,
                            partLotId: selectedLot.id,
                            quantity: qty,
                            purpose: selectedPurpose,
                            notes: notesCtrl.text.trim(),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Đã lấy ${qty.toStringAsFixed(0)} ${part.name} ra khỏi kệ ${selectedLot.storeLocationCode}'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Xác nhận lấy linh kiện'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLocationScanResultSheet(Map<String, dynamic> locData) {
    final locationName = locData['name']?.toString() ?? 'Vị trí kho';
    final locationCode = locData['code']?.toString() ?? '';
    final description = locData['description']?.toString();
    final partsList = (locData['parts'] as List?) ?? [];
    final boardsList = (locData['boards'] as List?) ?? [];
    final totalTypes = locData['totalPartTypes'] ?? (partsList.length + boardsList.length);
    final totalQty = (locData['totalQuantity'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final screenSize = MediaQuery.sizeOf(context);

        return Container(
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.85),
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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

              // Location Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 28, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$locationName ($locationCode)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (description != null && description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalTypes loại · SL: ${totalQty.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (partsList.isEmpty && boardsList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Vị trí kho này hiện chưa có bo mạch hoặc linh kiện nào.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section: Bo mạch tại vị trí
                        if (boardsList.isNotEmpty) ...[
                          Text(
                            'DANH SÁCH BO MẠCH TẠI KỆ NÀY (${boardsList.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...boardsList.map((item) {
                            final b = item as Map<String, dynamic>;
                            final boardId = b['boardId']?.toString() ?? '';
                            final name = b['name']?.toString() ?? '';
                            final model = b['model']?.toString() ?? '';
                            final qrCode = b['qrCode']?.toString() ?? '';
                            final qty = (b['quantity'] as num?)?.toInt() ?? 0;
                            final minQty = (b['minQuantity'] as num?)?.toInt() ?? 0;

                            final allBoards = context.read<BackendDataProvider>().boards;
                            final matchedBoard = allBoards.firstWhere(
                              (bo) => bo.id == boardId || bo.qrCode == qrCode,
                              orElse: () => Board(
                                id: boardId,
                                name: name,
                                qrCode: qrCode,
                                status: BoardStatus.available,
                                quantity: qty,
                                minQuantity: minQty,
                                model: model,
                                location: locationCode,
                              ),
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.memory, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${model.isNotEmpty ? '$model · ' : ''}QR: $qrCode',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Số lượng: $qty (Min: $minQty)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showBoardDetail(matchedBoard, fromScan: true);
                                    },
                                    icon: const Icon(Icons.outbox, size: 15),
                                    label: const Text('Lấy / Xuất', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],

                        // Section: Linh kiện tại vị trí
                        if (partsList.isNotEmpty) ...[
                          Text(
                            'DANH SÁCH LINH KIỆN TẠI KỆ NÀY (${partsList.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...partsList.map((item) {
                            final p = item as Map<String, dynamic>;
                            final partId = p['partId']?.toString() ?? '';
                            final partName = p['name']?.toString() ?? '';
                            final ipn = p['ipn']?.toString() ?? '';
                            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                            final category = p['categoryName']?.toString() ?? 'Chưa rõ';
                            final condition = p['condition']?.toString();

                            final allParts = context.read<BackendDataProvider>().parts;
                            final matchedPart = allParts.firstWhere(
                              (pa) => pa.id == partId,
                              orElse: () => Part(
                                id: partId,
                                ipn: ipn,
                                name: partName,
                                minAmount: 0,
                                totalQuantity: amount,
                                lots: [
                                  PartLot(
                                    id: p['partLotId']?.toString() ?? '',
                                    storeLocationId: locData['locationId']?.toString() ?? '',
                                    storeLocationCode: locationCode,
                                    storeLocationName: locationName,
                                    amount: amount,
                                  ),
                                ],
                              ),
                            );

                            final matchedLot = matchedPart.lots.firstWhere(
                              (l) => l.id == (p['partLotId']?.toString() ?? ''),
                              orElse: () => PartLot(
                                id: p['partLotId']?.toString() ?? '',
                                storeLocationId: locData['locationId']?.toString() ?? '',
                                storeLocationCode: locationCode,
                                storeLocationName: locationName,
                                amount: amount,
                              ),
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.settings_input_component, color: Color(0xFFD97706), size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'IPN: $ipn · $category${condition != null ? ' · $condition' : ''}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tồn tại kệ: ${amount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: amount <= 0
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            _showPartCheckoutDialog(
                                              context,
                                              part: matchedPart,
                                              initialLot: matchedLot,
                                            );
                                          },
                                    icon: const Icon(Icons.outbox, size: 15),
                                    label: const Text('Lấy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD97706),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleWarehouseQrScan(String rawResult) async {
    String qrCode = rawResult.trim();

    final match = RegExp(r'(?:mã qr|mã vị trí kho|mã bo mạch|mã linh kiện):\s*([^\n\r]+)', caseSensitive: false)
        .firstMatch(qrCode);
    if (match != null && match.group(1) != null) {
      qrCode = match.group(1)!.trim();
    }

    final backend = context.read<BackendDataProvider>();

    // 1. Quét theo Vị trí Kho trước
    try {
      final locData = await backend.scanLocationQr(qrCode);
      if (locData.isNotEmpty && (locData['code'] != null || locData['locationId'] != null || locData['id'] != null)) {
        if (!mounted) return;
        _showLocationScanResultSheet(locData);
        return;
      }
    } catch (_) {
      // Tiếp tục kiểm tra các loại khác nếu không phải mã vị trí
    }

    // 2. Kiểm tra nếu khớp mã QR bo mạch
    final matchedBoard = backend.boards.cast<Board?>().firstWhere(
          (b) => b?.qrCode.toLowerCase() == qrCode.toLowerCase() || b?.id == qrCode,
          orElse: () => null,
        );
    if (matchedBoard != null) {
      if (!mounted) return;
      _showBoardDetail(matchedBoard, fromScan: true);
      return;
    }

    // 3. Kiểm tra nếu khớp mã IPN linh kiện
    final matchedPart = backend.parts.cast<Part?>().firstWhere(
          (p) => p?.ipn.toLowerCase() == qrCode.toLowerCase() || p?.id == qrCode,
          orElse: () => null,
        );
    if (matchedPart != null) {
      if (!mounted) return;
      _showPartDetail(matchedPart);
      return;
    }

    // Fallback: search query
    _searchQuery.value = qrCode;
    _searchController.text = qrCode;
    setState(() {
      _partSearchMethod = PartSearchMethod.locationQr;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Đang lọc theo mã: $qrCode'),
        backgroundColor: AppColors.primary,
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
    StoreLocation? initialLocation;
    final initialQtyCtrl = TextEditingController();

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
                              if (!isEditing) ...[
                                const SizedBox(height: 12),
                                LocationPickerField(
                                  selectedLocation: initialLocation,
                                  fallbackCode: null,
                                  label: 'Vị trí lưu kho ban đầu (Tùy chọn)',
                                  onSelected: (loc) {
                                    setDialogState(() {
                                      initialLocation = loc;
                                    });
                                  },
                                ),
                                if (initialLocation != null) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: initialQtyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Số lượng nhập kho ban đầu',
                                      hintText: 'VD: 50, 100...',
                                    ),
                                  ),
                                ],
                              ],
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
                                final res = await backend.api.post(
                                  '/api/v1/parts',
                                  body: body,
                                );
                                final createdPartId = res is Map<String, dynamic> ? res['id']?.toString() : null;
                                final initQty = double.tryParse(initialQtyCtrl.text.trim()) ?? 0.0;
                                if (createdPartId != null && initialLocation != null && initQty > 0) {
                                  await backend.adjustPartStock(
                                    createdPartId,
                                    locationCode: initialLocation!.code,
                                    amount: initQty,
                                    note: 'Khởi tạo tồn kho ban đầu',
                                    reload: false,
                                  );
                                }
                              }
                              await Future.wait([
                                backend.loadParts(),
                                backend.loadLocations(),
                              ]);
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
              try {
                await context.read<BackendDataProvider>().deleteBoard(board);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã xóa bo mạch ${board.name}')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                final msg = e.toString().replaceAll('ApiException: ', '').replaceAll('Exception: ', '');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
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
    final modelCtrl = TextEditingController(text: board?.model ?? '');
    final locationCtrl = TextEditingController(text: board?.location ?? '');
    final serialCtrl = TextEditingController(text: board?.serialNumber ?? '');
    final partIdCtrl = TextEditingController(text: board?.partId ?? '');
    final currentLocationIdCtrl =
        TextEditingController(text: board?.currentLocationId ?? '');
    final descCtrl = TextEditingController(text: board?.description ?? '');
    final quantityCtrl = TextEditingController(text: board?.quantity.toString() ?? '1');
    final minQuantityCtrl = TextEditingController(text: board?.minQuantity.toString() ?? '0');
    final removedPartsCtrl = TextEditingController(text: board?.removedParts ?? '');
    BoardStatus selectedStatus = board?.status ?? BoardStatus.available;

    final allLocations = context.read<BackendDataProvider>().locations;
    StoreLocation? selectedLocation;
    if (board != null) {
      if (board.currentLocationId != null && board.currentLocationId!.isNotEmpty) {
        selectedLocation = allLocations.cast<StoreLocation?>().firstWhere(
          (l) => l?.id == board.currentLocationId,
          orElse: () => null,
        );
      }
      if (selectedLocation == null && board.location.isNotEmpty) {
        selectedLocation = allLocations.cast<StoreLocation?>().firstWhere(
          (l) => l?.code.toLowerCase() == board.location.toLowerCase() ||
                 l?.name.toLowerCase() == board.location.toLowerCase(),
          orElse: () => null,
        );
      }
    }

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
                                  labelText: 'Tên bo mạch *',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Model',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: serialCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Số serial',
                                ),
                              ),
                              const SizedBox(height: 12),
                              LocationPickerField(
                                selectedLocation: selectedLocation,
                                fallbackCode: locationCtrl.text,
                                label: 'Vị trí lưu kho bo mạch',
                                onSelected: (loc) {
                                  setDialogState(() {
                                    selectedLocation = loc;
                                    if (loc != null) {
                                      locationCtrl.text = loc.code;
                                      currentLocationIdCtrl.text = loc.id;
                                    } else {
                                      locationCtrl.text = '';
                                      currentLocationIdCtrl.text = '';
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: quantityCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Số lượng *',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: minQuantityCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Tồn tối thiểu (Min)',
                                        hintText: '0',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: removedPartsCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Linh kiện đã rã / tháo (nếu có)',
                                  hintText: 'VD: IC nguồn U1, Tụ C12...',
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<BoardStatus>(
                                initialValue: selectedStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Trạng thái',
                                ),
                                items: BoardStatus.values.map((s) {
                                  String label;
                                  switch (s) {
                                    case BoardStatus.available:
                                      label = 'Sẵn sàng';
                                      break;
                                    case BoardStatus.checkedOut:
                                      label = 'Đang dùng';
                                      break;
                                    case BoardStatus.inRepair:
                                      label = 'Đang sửa';
                                      break;
                                    case BoardStatus.damaged:
                                      label = 'Hỏng';
                                      break;
                                    case BoardStatus.lost:
                                      label = 'Thất lạc';
                                      break;
                                    case BoardStatus.archived:
                                      label = 'Lưu trữ';
                                      break;
                                    case BoardStatus.maintenance:
                                      label = 'Bảo trì';
                                      break;
                                  }
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
                              final model = _optionalText(modelCtrl.text);
                              final partId = _optionalText(partIdCtrl.text);
                              final currentLocationId = _optionalText(
                                currentLocationIdCtrl.text,
                              );

                              final backend = context
                                  .read<BackendDataProvider>();
                              final body = <String, dynamic>{
                                'name': nameCtrl.text.trim(),
                                if (model != null) 'model': model,
                                if (model != null) 'category': model,
                                'location': locationCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'serialNumber': serialNumber,
                                'quantity': int.tryParse(quantityCtrl.text) ?? 1,
                                'minQuantity': int.tryParse(minQuantityCtrl.text) ?? 0,
                                if (removedPartsCtrl.text.trim().isNotEmpty)
                                  'removedParts': removedPartsCtrl.text.trim(),
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
                              await Future.wait([
                                backend.loadBoards(),
                                backend.loadLocations(),
                              ]);
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
                        if (widget.board.model.isNotEmpty)
                          Text(
                            'Model: ${widget.board.model}',
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

              if (widget.board.location.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF16A34A), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vị trí lưu kho',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.board.location,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              _buildInfoRow('Số lượng tồn', widget.board.quantity.toString()),
              if (widget.board.minQuantity > 0)
                _buildInfoRow('Định mức tối thiểu (Min)', widget.board.minQuantity.toString()),
              if (widget.board.removedParts != null && widget.board.removedParts!.isNotEmpty)
                _buildInfoRow('Linh kiện đã rã', widget.board.removedParts!),
              if (widget.board.partIpn != null && widget.board.partIpn!.isNotEmpty)
                _buildInfoRow('Mã linh kiện tương ứng', widget.board.partIpn!),
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
  final VoidCallback onCheckout;

  const _PartDetailSheet({
    required this.part,
    required this.onEdit,
    required this.onDelete,
    required this.onCheckout,
  });

  @override
  State<_PartDetailSheet> createState() => _PartDetailSheetState();
}

class _PartDetailSheetState extends State<_PartDetailSheet> {
  bool _isLoading = false;

  void _showAdjustStockDialog() {
    final allLocations = context.read<BackendDataProvider>().locations;
    StoreLocation? selectedLocation;
    if (widget.part.lots.isNotEmpty) {
      final firstLot = widget.part.lots.first;
      selectedLocation = allLocations.cast<StoreLocation?>().firstWhere(
        (l) => l?.id == firstLot.storeLocationId || l?.code.toLowerCase() == firstLot.storeLocationCode.toLowerCase(),
        orElse: () => null,
      );
    }

    final locationCodeCtrl = TextEditingController(
      text: selectedLocation?.code ?? (widget.part.lots.isNotEmpty ? widget.part.lots.first.storeLocationCode : ''),
    );
    final amountCtrl = TextEditingController(
      text: widget.part.totalQuantity > 0 ? widget.part.totalQuantity.toStringAsFixed(0) : '',
    );
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Điều chỉnh tồn kho'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocationPickerField(
                  selectedLocation: selectedLocation,
                  fallbackCode: locationCodeCtrl.text,
                  label: 'Vị trí lưu kho linh kiện *',
                  isRequired: true,
                  onSelected: (loc) {
                    setDlgState(() {
                      selectedLocation = loc;
                      if (loc != null) {
                        locationCodeCtrl.text = loc.code;
                      } else {
                        locationCodeCtrl.text = '';
                      }
                    });
                  },
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
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final locCode = selectedLocation?.code ?? locationCodeCtrl.text.trim();
                final amountStr = amountCtrl.text.trim();
                if (locCode.isEmpty || amountStr.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn vị trí và nhập số lượng tồn kho')),
                  );
                  return;
                }

                final amount = double.tryParse(amountStr);
                if (amount == null || amount < 0) return;

                Navigator.pop(dlgContext); // Close dialog
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onCheckout,
                      icon: const Icon(Icons.outbox, size: 18),
                      label: const Text('Lấy linh kiện', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAdjustStockDialog,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Điều chỉnh kho'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
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
