import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/attendance.dart';
import '../utils/auth_provider.dart';
import '../models/app_permission.dart';
import '../utils/notification_provider.dart';
import '../utils/backend_data_provider.dart';
import 'field_work_bottom_sheet.dart';

class FieldWorkRequests extends StatefulWidget {
  const FieldWorkRequests({super.key});
  @override
  State<FieldWorkRequests> createState() => _FieldWorkRequestsState();
}

class _FieldWorkRequestsState extends State<FieldWorkRequests> {
  late Future<List<FieldWorkDay>> _requests;
  bool _busy = false;
  int _revision = -1;
  String _notificationId = '';
  DateTime _month = DateTime.now();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<BackendDataProvider>().fieldWorkRevision;
    final notifications = context.watch<NotificationProvider>().notifications;
    final latest =
        notifications.where((n) => n.refType == 'FIELD_WORK').firstOrNull?.id ??
        '';
    if (_revision != revision || _notificationId != latest) {
      _notificationId = latest;
      _revision = revision;
      _requests = _load();
    }
  }

  Future<List<FieldWorkDay>> _load() {
    final backend = context.read<BackendDataProvider>();
    final auth = context.read<AuthProvider>();
    if (!auth.isAdminOrAbove && !auth.can(AppPermission.saveFieldWork)) {
      return Future.value([]);
    }
    return auth.isAdminOrAbove
        ? backend.getPendingFieldWork()
        : backend.getFieldWorkDays(
            from: DateTime(_month.year, _month.month),
            to: DateTime(_month.year, _month.month + 1, 0),
          );
  }

  void _refresh() => setState(() => _requests = _load());

  Future<void> _review(FieldWorkDay day, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'Chấp nhận đi công trình?' : 'Từ chối yêu cầu?'),
        content: Text('${day.employeeName ?? day.employeeId}\n${day.note}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => context.read<BackendDataProvider>().reviewFieldWork(
        day.id,
        approve,
        day.version,
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật yêu cầu')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(FieldWorkDay day) async {
    final dateStr =
        '${day.workDate.year.toString().padLeft(4, '0')}-${day.workDate.month.toString().padLeft(2, '0')}-${day.workDate.day.toString().padLeft(2, '0')}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showFieldWorkBottomSheet(
      context,
      dateStr: dateStr,
      initialNote: day.note,
      isExisting: true,
      isDark: isDark,
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = auth.isAdminOrAbove;
    if (!admin && !auth.can(AppPermission.saveFieldWork)) {
      return const SizedBox.shrink();
    }
    const labels = {
      'PENDING': 'Chờ duyệt',
      'APPROVED': 'Đã chấp nhận',
      'REJECTED': 'Đã từ chối',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.briefcase,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    admin ? 'Duyệt đi công trình' : 'Báo cáo công trình',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!admin)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _month,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null && mounted) {
                                _month = date;
                                _refresh();
                              }
                            },
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text('Tháng ${_month.month}/${_month.year}'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        backgroundColor: const Color(0xFFFEF3C7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await showFieldWorkBottomSheet(
                          context,
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                        );
                        if (mounted) _refresh();
                      },
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text(
                        'Báo công trình',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            FutureBuilder<List<FieldWorkDay>>(
              future: _requests,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Không tải được yêu cầu: ${snapshot.error}');
                }
                final days = snapshot.data ?? [];
                if (days.isEmpty) return const Text('Không có yêu cầu.');
                return Column(
                  children: days
                      .map(
                        (day) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${day.workDate.day}/${day.workDate.month}/${day.workDate.year}${admin ? ' — ${day.employeeName ?? day.employeeId}' : ''}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day.note),
                              Text(labels[day.status] ?? day.status),
                              Wrap(
                                spacing: 8,
                                children: admin
                                    ? [
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(day, true),
                                          child: const Text('Chấp nhận'),
                                        ),
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(day, false),
                                          child: const Text('Từ chối'),
                                        ),
                                      ]
                                    : [
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _edit(day),
                                          child: const Text(
                                            'Sửa / Hủy yêu cầu',
                                          ),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
