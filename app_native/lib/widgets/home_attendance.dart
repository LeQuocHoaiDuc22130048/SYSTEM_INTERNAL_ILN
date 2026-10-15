import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_permission.dart';
import '../models/attendance.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';

class HomeAttendance extends StatefulWidget {
  const HomeAttendance({super.key});
  @override
  State<HomeAttendance> createState() => _HomeAttendanceState();
}

class _HomeAttendanceState extends State<HomeAttendance> {
  bool _loading = false;
  String? _error;
  AttendanceStatus? _selectedStatusFilter;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.can(AppPermission.viewAttendance)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final backend = context.read<BackendDataProvider>();
      if (auth.can(AppPermission.viewAttendanceReports)) {
        await backend.loadAttendance();
      } else {
        await backend.loadMyTodayAttendance();
      }
    } catch (_) {
      if (mounted) _error = 'Không thể tải chấm công hôm nay.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _today(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'NV';
    if (words.length == 1) {
      return words.first.characters.first.toUpperCase();
    }
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }

  String? _resolveAvatarUrl(
    AttendanceRecord record,
    BackendDataProvider backend,
    AuthProvider auth,
  ) {
    User? matched;
    for (final emp in backend.employees) {
      if ((record.employeeId.isNotEmpty &&
              (emp.employeeId == record.employeeId ||
                  emp.id == record.employeeId)) ||
          emp.name.trim().toLowerCase() ==
              record.employeeName.trim().toLowerCase()) {
        matched = emp;
        break;
      }
    }
    matched ??=
        (auth.currentUser != null &&
            (auth.currentUser!.name.trim().toLowerCase() ==
                    record.employeeName.trim().toLowerCase() ||
                record.id == 'own-today'))
        ? auth.currentUser
        : null;

    final raw = matched?.avatar;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${backend.api.activeBaseUrl.replaceAll(RegExp(r'/+$'), '')}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  ({Color fg, Color bg, Color border}) _statusPalette(
    AttendanceStatus status,
    bool isDark,
  ) {
    switch (status) {
      case AttendanceStatus.onTime:
        return (
          fg: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
          bg: isDark
              ? const Color(0xFF16A34A).withValues(alpha: 0.18)
              : const Color(0xFFDCFCE7),
          border: isDark
              ? const Color(0xFF4ADE80).withValues(alpha: 0.35)
              : const Color(0xFFBBF7D0),
        );
      case AttendanceStatus.late:
        return (
          fg: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
          bg: isDark
              ? const Color(0xFFEA580C).withValues(alpha: 0.18)
              : const Color(0xFFFFEDD5),
          border: isDark
              ? const Color(0xFFFB923C).withValues(alpha: 0.35)
              : const Color(0xFFFED7AA),
        );
      case AttendanceStatus.fieldWork:
        return (
          fg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          bg: isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.18)
              : const Color(0xFFFEF3C7),
          border: isDark
              ? const Color(0xFFFBBF24).withValues(alpha: 0.35)
              : const Color(0xFFFDE68A),
        );
      case AttendanceStatus.absent:
        return (
          fg: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          bg: isDark
              ? const Color(0xFF64748B).withValues(alpha: 0.18)
              : const Color(0xFFF1F5F9),
          border: isDark
              ? const Color(0xFF94A3B8).withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        );
    }
  }

  Widget _buildFilterChip({
    required Key chipKey,
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final accent = activeColor ?? const Color(0xFF2563EB);
    final bg = selected
        ? (isDark ? accent.withValues(alpha: 0.22) : accent)
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final fg = selected
        ? (isDark ? Colors.white : Colors.white)
        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF475569));
    final border = selected
        ? accent
        : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0));

    return GestureDetector(
      key: chipKey,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.can(AppPermission.viewAttendance)) return const SizedBox.shrink();
    final backend = context.watch<BackendDataProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final team = auth.can(AppPermission.viewAttendanceReports);
    final own = backend.myTodayAttendance;
    final records = team
        ? backend.attendanceRecords.where((r) => _today(r.date)).toList()
        : <AttendanceRecord>[
            if (own != null && (own.date == null || _today(own.date!)))
              AttendanceRecord(
                id: 'own-today',
                employeeId: auth.currentUser?.employeeId ?? '',
                employeeName: auth.currentUser?.name ?? 'Bạn',
                date: DateTime.now(),
                checkIn: own.checkInTimeStr,
                checkOut: own.checkOutTimeStr,
                status: own.fieldWork
                    ? AttendanceStatus.fieldWork
                    : own.checkIn == null
                    ? AttendanceStatus.absent
                    : own.isLate
                    ? AttendanceStatus.late
                    : AttendanceStatus.onTime,
              ),
          ];
    records.sort((a, b) => a.employeeName.compareTo(b.employeeName));

    final onTimeCount = records
        .where((r) => r.status == AttendanceStatus.onTime)
        .length;
    final lateCount = records
        .where((r) => r.status == AttendanceStatus.late)
        .length;
    final absentCount = records
        .where((r) => r.status == AttendanceStatus.absent)
        .length;

    final query = _searchQuery.trim().toLowerCase();
    final filteredRecords = records.where((r) {
      if (_selectedStatusFilter != null && r.status != _selectedStatusFilter) {
        return false;
      }
      if (query.isNotEmpty &&
          !r.employeeName.toLowerCase().contains(query) &&
          !r.employeeId.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Chấm công hôm nay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (team) ...[
              IconButton(
                key: const ValueKey('attendance-search-toggle'),
                tooltip: 'Tìm kiếm nhân viên',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(6),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch && _searchQuery.isNotEmpty) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                icon: Icon(
                  _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                  size: 20,
                  color: _showSearch ? const Color(0xFF2563EB) : null,
                ),
              ),
              const SizedBox(width: 12),
            ],
            IconButton(
              tooltip: 'Tải lại chấm công',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: const EdgeInsets.all(6),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        if (!team)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Chấm công của bạn',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        if (team) ...[
          if (_showSearch) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 36,
              child: TextField(
                key: const ValueKey('attendance-search-input'),
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm tên nhân viên...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF64748B),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 4),
          SingleChildScrollView(
            key: const ValueKey('attendance-filter-scroll'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _buildFilterChip(
                  chipKey: const ValueKey('attendance-filter-all'),
                  label: 'Tất cả (${records.length})',
                  selected: _selectedStatusFilter == null,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedStatusFilter = null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  chipKey: const ValueKey('attendance-filter-onTime'),
                  label: 'Đúng giờ ($onTimeCount)',
                  selected: _selectedStatusFilter == AttendanceStatus.onTime,
                  isDark: isDark,
                  activeColor: const Color(0xFF16A34A),
                  onTap: () => setState(
                    () => _selectedStatusFilter =
                        _selectedStatusFilter == AttendanceStatus.onTime
                        ? null
                        : AttendanceStatus.onTime,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  chipKey: const ValueKey('attendance-filter-late'),
                  label: 'Đi muộn ($lateCount)',
                  selected: _selectedStatusFilter == AttendanceStatus.late,
                  isDark: isDark,
                  activeColor: const Color(0xFFEA580C),
                  onTap: () => setState(
                    () => _selectedStatusFilter =
                        _selectedStatusFilter == AttendanceStatus.late
                        ? null
                        : AttendanceStatus.late,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  chipKey: const ValueKey('attendance-filter-absent'),
                  label: 'Vắng mặt ($absentCount)',
                  selected: _selectedStatusFilter == AttendanceStatus.absent,
                  isDark: isDark,
                  activeColor: const Color(0xFF64748B),
                  onTap: () => setState(
                    () => _selectedStatusFilter =
                        _selectedStatusFilter == AttendanceStatus.absent
                        ? null
                        : AttendanceStatus.absent,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Text(_error!)
        else if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Chưa có dữ liệu chấm công hôm nay.'),
          )
        else if (filteredRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Không có nhân viên phù hợp bộ lọc.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF64748B),
              ),
            ),
          )
        else
          ...filteredRecords.map((r) {
            final palette = _statusPalette(r.status, isDark);
            final avatarUrl = _resolveAvatarUrl(r, backend, auth);
            final initials = _initials(r.employeeName);
            final hasCheckIn =
                r.checkIn != null &&
                r.checkIn!.trim().isNotEmpty &&
                r.checkIn != '--:--';
            final hasCheckOut =
                r.checkOut != null &&
                r.checkOut!.trim().isNotEmpty &&
                r.checkOut != '--:--';

            final fallbackAvatar = Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showAttendanceDetailSheet(
                    context,
                    record: r,
                    palette: palette,
                    avatarUrl: avatarUrl,
                    initials: initials,
                    isDark: isDark,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.bg,
                                border: Border.all(
                                  color: palette.border,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: avatarUrl == null
                                    ? fallbackAvatar
                                    : Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            fallbackAvatar,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: palette.fg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.surfaceDark
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.employeeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.bg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: palette.border),
                                    ),
                                    child: Text(
                                      r.statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: palette.fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (hasCheckOut) ...[
                                    Text(
                                      'Vào: ${r.checkIn ?? '--:--'}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                    Text(
                                      'Ra: ${r.checkOut}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ] else if (hasCheckIn)
                                    Text(
                                      'Vào: ${r.checkIn} - Hiện tại',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF475569),
                                      ),
                                    )
                                  else
                                    Text(
                                      'Chưa check-in',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showAttendanceDetailSheet(
    BuildContext context, {
    required AttendanceRecord record,
    required ({Color fg, Color bg, Color border}) palette,
    required String? avatarUrl,
    required String initials,
    required bool isDark,
  }) {
    final hasCheckIn =
        record.checkIn != null &&
        record.checkIn!.trim().isNotEmpty &&
        record.checkIn != '--:--';
    final hasCheckOut =
        record.checkOut != null &&
        record.checkOut!.trim().isNotEmpty &&
        record.checkOut != '--:--';
    final day = record.date.day.toString().padLeft(2, '0');
    final month = record.date.month.toString().padLeft(2, '0');
    final dateLabel = '$day/$month/${record.date.year}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.bg,
                        border: Border.all(color: palette.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: palette.fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.employeeName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ngày chấm công: $dateLabel',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        record.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.backgroundDark
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
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
                              'Giờ vào',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasCheckIn ? record.checkIn! : '--:--',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giờ ra / Trạng thái ca',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasCheckOut
                                  ? record.checkOut!
                                  : (hasCheckIn ? 'Hiện tại' : 'Chưa check-in'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
