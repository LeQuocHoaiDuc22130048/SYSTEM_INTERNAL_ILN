import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance.dart';
import '../utils/auth_provider.dart';
import '../models/app_permission.dart';
import '../utils/notification_provider.dart';
import '../utils/backend_data_provider.dart';

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
    final note = TextEditingController(text: day.note);
    final action = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yêu cầu đi công trình'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sửa nội dung sẽ gửi lại để quản trị viên xét duyệt.'),
            TextField(controller: note, maxLength: 2000, maxLines: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: const Text('Hủy yêu cầu'),
          ),
          FilledButton(
            onPressed: () {
              if (note.text.trim().isNotEmpty) Navigator.pop(c, 'save');
            },
            child: const Text('Gửi duyệt'),
          ),
        ],
      ),
    );
    final text = note.text;
    // The dialog may still be animating out; its controller is disposed after the transition.
    Future.delayed(const Duration(milliseconds: 300), note.dispose);
    if (action == null || !mounted) return;
    await _run(() async {
      final backend = context.read<BackendDataProvider>();
      if (action == 'cancel') {
        await backend.removeFieldWork(day.workDate);
      } else {
        await backend.saveFieldWork(day.workDate, text);
      }
    });
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
                Expanded(
                  child: Text(
                    admin ? 'Duyệt đi công trình' : 'Yêu cầu đi công trình',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!admin)
              TextButton(
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
                child: Text('Tháng ${_month.month}/${_month.year}'),
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
