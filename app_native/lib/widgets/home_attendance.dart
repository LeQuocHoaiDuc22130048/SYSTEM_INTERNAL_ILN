import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_permission.dart';
import '../models/attendance.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
      if (auth.can(AppPermission.manageAttendance)) {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.can(AppPermission.viewAttendance)) return const SizedBox.shrink();
    final backend = context.watch<BackendDataProvider>();
    final team = auth.can(AppPermission.manageAttendance);
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
                status: own.checkIn == null
                    ? AttendanceStatus.absent
                    : own.isLate
                    ? AttendanceStatus.late
                    : AttendanceStatus.onTime,
              ),
          ];
    records.sort((a, b) => a.employeeName.compareTo(b.employeeName));
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chấm công hôm nay',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Tải lại chấm công',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (!team) const Text('Chấm công của bạn'),
        const SizedBox(height: 10),
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
            padding: EdgeInsets.all(16),
            child: Text('Chưa có dữ liệu chấm công hôm nay.'),
          )
        else
          ...records.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        Icons.access_time,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.employeeName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text('Vào: ${r.checkIn ?? '--:--'}'),
                              Text('Ra: ${r.checkOut ?? '--:--'}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.statusLabel,
                            style: TextStyle(
                              color: r.status == AttendanceStatus.onTime
                                  ? Colors.green
                                  : colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
