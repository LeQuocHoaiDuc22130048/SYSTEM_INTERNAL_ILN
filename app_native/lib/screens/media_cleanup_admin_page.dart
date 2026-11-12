import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../widgets/navigation/app_back_button.dart';

class MediaCleanupAdminPage extends StatefulWidget {
  const MediaCleanupAdminPage({super.key});

  @override
  State<MediaCleanupAdminPage> createState() => _MediaCleanupAdminPageState();
}

class _MediaCleanupAdminPageState extends State<MediaCleanupAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  bool _triggeringCleanup = false;
  bool _recovering = false;
  String? _retryingMediaId;

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _schedule;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _assets = [];
  String _assetStatusFilter = 'FAILED_PERMANENT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final api = context.read<AuthProvider>().api;
    try {
      final results = await Future.wait([
        api.get('/api/v1/admin/media-cleanup/stats'),
        api.get('/api/v1/admin/media-cleanup/schedule'),
        api.get('/api/v1/admin/media-cleanup/jobs', queryParameters: {
          'page': '0',
          'size': '20',
        }),
        api.get('/api/v1/admin/media-cleanup/assets', queryParameters: {
          'status': _assetStatusFilter,
          'page': '0',
          'size': '20',
        }),
      ]);

      if (!mounted) return;
      final statsRes = results[0];
      final scheduleRes = results[1];
      final jobsRes = results[2];
      final assetsRes = results[3];

      setState(() {
        if (statsRes is Map<String, dynamic>) {
          _stats = statsRes;
        }
        if (scheduleRes is Map<String, dynamic>) {
          _schedule = scheduleRes;
        }
        if (jobsRes is Map<String, dynamic> && jobsRes['content'] is List) {
          _jobs = List<Map<String, dynamic>>.from(
            (jobsRes['content'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
        }
        if (assetsRes is Map<String, dynamic> && assetsRes['content'] is List) {
          _assets = List<Map<String, dynamic>>.from(
            (assetsRes['content'] as List).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải dữ liệu Media Cleanup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showScheduleSheet() async {
    bool enabled = _schedule?['enabled'] == true;
    String mode = _schedule?['scheduleMode']?.toString() ?? 'SPECIFIC_DATETIME';
    DateTime? targetDateTime = _schedule?['scheduledRunAt'] != null
        ? DateTime.tryParse(_schedule!['scheduledRunAt'].toString())?.toLocal()
        : DateTime.now().add(const Duration(days: 1));
    int dayOfMonth = (_schedule?['dayOfMonth'] as num?)?.toInt() ?? 1;
    int dayOfWeek = (_schedule?['dayOfWeek'] as num?)?.toInt() ?? 1;
    String timeOfDay = _schedule?['timeOfDay']?.toString() ?? '02:00';
    final ttlUploadCtrl = TextEditingController(
      text: ((_schedule?['unreferencedUploadTtlHours'] as num?)?.toInt() ?? 24)
          .toString(),
    );
    final ttlMsgCtrl = TextEditingController(
      text: ((_schedule?['deletedMessageMediaTtlDays'] as num?)?.toInt() ?? 7)
          .toString(),
    );
    final ttlRepairCtrl = TextEditingController(
      text: ((_schedule?['closedRepairMediaTtlDays'] as num?)?.toInt() ?? 180)
          .toString(),
    );
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hẹn thời gian chạy Cleanup (Không xóa liên tục)',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Kích hoạt hẹn giờ chạy tự động',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Chỉ chạy đúng khi chạm mốc thời gian đã hẹn',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: enabled,
                        onChanged: (val) => setModalState(() => enabled = val),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: const InputDecoration(
                          labelText: 'Chế độ hẹn giờ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'SPECIFIC_DATETIME',
                            child: Text(
                              'Chạy 1 lần vào Ngày & Giờ xác định',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'MONTHLY',
                            child: Text(
                              'Định kỳ mỗi tháng 1 lần',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'WEEKLY',
                            child: Text(
                              'Định kỳ mỗi tuần 1 lần',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'DAILY',
                            child: Text(
                              'Định kỳ mỗi ngày',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => mode = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (mode == 'SPECIFIC_DATETIME')
                        OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: targetDateTime ?? now,
                              firstDate: now.subtract(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 365 * 3)),
                            );
                            if (pickedDate == null || !context.mounted) return;
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                targetDateTime ?? now,
                              ),
                            );
                            if (pickedTime == null) return;
                            setModalState(() {
                              targetDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          icon: const Icon(LucideIcons.clock, size: 16),
                          label: Text(
                            targetDateTime == null
                                ? 'Chọn Ngày & Giờ xác định'
                                : 'Mốc hẹn: ${_formatDate(targetDateTime!.toIso8601String())}',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ttlUploadCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Upload nháp (giờ)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ttlMsgCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tin nhắn xóa (ngày)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ttlRepairCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Đơn đóng (ngày)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  try {
                                    final api =
                                        this.context.read<AuthProvider>().api;
                                    await api.put(
                                      '/api/v1/admin/media-cleanup/schedule',
                                      body: {
                                        'enabled': enabled,
                                        'scheduleMode': mode,
                                        'scheduledRunAt':
                                            targetDateTime?.toUtc().toIso8601String(),
                                        'dayOfMonth': dayOfMonth,
                                        'dayOfWeek': dayOfWeek,
                                        'timeOfDay': timeOfDay,
                                        'unreferencedUploadTtlHours':
                                            int.tryParse(ttlUploadCtrl.text) ??
                                                24,
                                        'deletedMessageMediaTtlDays':
                                            int.tryParse(ttlMsgCtrl.text) ?? 7,
                                        'closedRepairMediaTtlDays':
                                            int.tryParse(ttlRepairCtrl.text) ??
                                                180,
                                      },
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    await _loadAll();
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Đã lưu lịch hẹn chạy Media Cleanup.',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi lưu lịch hẹn: $e'),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setModalState(() => saving = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Lưu cấu hình lịch hẹn'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _triggerManualCleanup() async {
    setState(() => _triggeringCleanup = true);
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.post(
        '/api/v1/admin/media-cleanup/trigger',
        timeout: const Duration(seconds: 45),
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final jobCode = res['jobCode'] ?? '';
        final deleted = res['deletedCount'] ?? 0;
        final failed = res['failedCount'] ?? 0;
        final freed = _formatBytes((res['freedBytes'] as num?)?.toInt() ?? 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã chạy $jobCode: Xóa $deleted tệp ($freed), Lỗi $failed',
            ),
          ),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chạy Media Cleanup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _triggeringCleanup = false);
      }
    }
  }

  Future<void> _recoverStuckState() async {
    setState(() => _recovering = true);
    try {
      final api = context.read<AuthProvider>().api;
      final res = await api.post('/api/v1/admin/media-cleanup/recover');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final jobs = res['recoveredJobs'] ?? 0;
        final assets = res['recoveredMediaAssets'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phục hồi hoàn tất: $jobs job treo, $assets bản ghi CLEANUP_IN_PROGRESS',
            ),
          ),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi phục hồi trạng thái treo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _recovering = false);
      }
    }
  }

  Future<void> _retryMediaAsset(String mediaId) async {
    setState(() => _retryingMediaId = mediaId);
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/api/v1/admin/media-cleanup/assets/$mediaId/retry');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đặt lại trạng thái retry cho bản ghi Media.'),
        ),
      );
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đặt lại retry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retryingMediaId = null);
      }
    }
  }

  Future<void> _showJobAuditLogsSheet(Map<String, dynamic> job) async {
    final jobId = job['id']?.toString() ?? '';
    final jobCode = job['jobCode']?.toString() ?? '';
    if (jobId.isEmpty) return;

    final api = context.read<AuthProvider>().api;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 20,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Audit Log — $jobCode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<dynamic>(
                      future: api.get(
                        '/api/v1/admin/media-cleanup/jobs/$jobId/logs',
                        queryParameters: {'page': '0', 'size': '50'},
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final data = snapshot.data;
                        final logs = (data is Map<String, dynamic> &&
                                data['content'] is List)
                            ? List<Map<String, dynamic>>.from(
                                (data['content'] as List).map(
                                  (e) => Map<String, dynamic>.from(e as Map),
                                ),
                              )
                            : <Map<String, dynamic>>[];

                        if (logs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Không có bản ghi Audit Log trong phiên này.',
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: logs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final item = logs[index];
                            final outcome =
                                item['outcome']?.toString() ?? 'SUCCESS';
                            final action = item['action']?.toString() ?? '';
                            final bucket = item['bucketName']?.toString() ?? '';
                            final key = item['objectKey']?.toString() ?? '';
                            final attempt = item['attemptNumber'] ?? 1;
                            final durationMs = item['durationMs'] ?? 0;
                            final errCode = item['errorCode']?.toString();
                            final errMsg = item['errorMessage']?.toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildBadge(outcome),
                                      Text(
                                        'Lần thử #$attempt • ${durationMs}ms',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$bucket/$key',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Action: $action',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  if (errCode != null ||
                                      (errMsg != null &&
                                          errMsg.isNotEmpty)) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${errCode ?? ''} ${errMsg ?? ''}'.trim(),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFFE11D48),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
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
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int idx = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && idx < units.length - 1) {
      value /= 1024;
      idx++;
    }
    return '${value.toStringAsFixed(idx == 0 ? 0 : 2)} ${units[idx]}';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw.toString())?.toLocal();
    if (parsed == null) return raw.toString();
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${parsed.year} $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batchSize = (_stats?['batchSize'] as num?)?.toInt() ?? 100;
    final activeCount = (_stats?['activeMediaCount'] as num?)?.toInt() ?? 0;
    final eligibleCount =
        (_stats?['eligibleExpiredCandidates'] as num?)?.toInt() ?? 0;
    final softDeletedCount =
        (_stats?['softDeletedMediaCount'] as num?)?.toInt() ?? 0;
    final failedCount =
        (_stats?['permanentlyFailedMediaCount'] as num?)?.toInt() ?? 0;
    final freedBytes = (_stats?['totalFreedBytes'] as num?)?.toInt() ?? 0;
    final scheduleEnabled = _schedule?['enabled'] == true;
    final nextRunText = scheduleEnabled && _schedule?['scheduledRunAt'] != null
        ? 'Hẹn chạy: ${_formatDate(_schedule!['scheduledRunAt'])}'
        : 'Không xóa liên tục • Chỉ chạy khi đến mốc hẹn';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppBackButton(
                    isDark: isDark,
                    icon: LucideIcons.chevronLeft,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Media Cleanup Engine',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$nextRunText • Batch $batchSize',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showScheduleSheet,
                    icon: const Icon(LucideIcons.calendar, size: 18),
                    tooltip: 'Hẹn thời gian chạy Cleanup',
                  ),
                  IconButton(
                    onPressed: _loading ? null : _loadAll,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    tooltip: 'Làm mới',
                  ),
                ],
              ),
            ),

            // KPI Summary & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          isDark: isDark,
                          title: 'Đang lưu trữ',
                          value: '$activeCount',
                          subtitle: 'Chờ xóa: $eligibleCount',
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          isDark: isDark,
                          title: 'Đã xóa mềm',
                          value: '$softDeletedCount',
                          subtitle: _formatBytes(freedBytes),
                          color: const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          isDark: isDark,
                          title: 'Lỗi vĩnh viễn',
                          value: '$failedCount',
                          subtitle: 'Max retry = 5',
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _triggeringCleanup ? null : _triggerManualCleanup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _triggeringCleanup
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.play, size: 15),
                          label: const Text(
                            'Chạy ngay',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showScheduleSheet,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(LucideIcons.calendar, size: 15),
                          label: const Text(
                            'Hẹn giờ xóa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recovering ? null : _recoverStuckState,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _recovering
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.rotateCcw, size: 15),
                          label: const Text(
                            'Phục hồi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                tabs: const [
                  Tab(text: 'Lịch sử Job & Audit Log'),
                  Tab(text: 'Bản ghi Media & Retry'),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJobsList(isDark),
                        _buildAssetsList(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList(bool isDark) {
    if (_jobs.isEmpty) {
      return const Center(
        child: Text('Chưa có phiên chạy Cleanup Job nào.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final job = _jobs[index];
        final jobCode = job['jobCode']?.toString() ?? '';
        final status = job['status']?.toString() ?? 'COMPLETED';
        final trigger = job['triggerType']?.toString() ?? '';
        final batches = job['totalBatches'] ?? 0;
        final deleted = job['deletedCount'] ?? 0;
        final failed = job['failedCount'] ?? 0;
        final freed = _formatBytes((job['freedBytes'] as num?)?.toInt() ?? 0);

        return InkWell(
          onTap: () => _showJobAuditLogsSheet(job),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        jobCode,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    _buildBadge(status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Trigger: $trigger • $batches batch • Xóa: $deleted • Lỗi: $failed • Giải phóng: $freed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(job['startedAt']),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      'Chạm để xem Audit Log →',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssetsList(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in const [
                  'FAILED_PERMANENT',
                  'ACTIVE',
                  'CLEANUP_IN_PROGRESS',
                  'SOFT_DELETED',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status, style: const TextStyle(fontSize: 11.5)),
                      selected: _assetStatusFilter == status,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _assetStatusFilter = status);
                          _loadAll();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _assets.isEmpty
              ? Center(
                  child: Text(
                    'Không có bản ghi Media ở trạng thái $_assetStatusFilter',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final asset = _assets[index];
                    final id = asset['id']?.toString() ?? '';
                    final bucket = asset['bucketName']?.toString() ?? '';
                    final key = asset['objectKey']?.toString() ?? '';
                    final status = asset['status']?.toString() ?? '';
                    final retryCount = asset['retryCount'] ?? 0;
                    final maxRetries = asset['maxRetries'] ?? 5;
                    final size =
                        _formatBytes((asset['fileSize'] as num?)?.toInt() ?? 0);
                    final errCode = asset['lastErrorCode']?.toString();
                    final errMsg = asset['lastErrorMessage']?.toString();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '$bucket/$key',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              _buildBadge(status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dung lượng: $size • Retry: $retryCount/$maxRetries • Hết hạn: ${_formatDate(asset['expiresAt'])}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (errCode != null && errCode.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$errCode: ${errMsg ?? ''}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                          ],
                          if (status != 'SOFT_DELETED') ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _retryingMediaId == id
                                    ? null
                                    : () => _retryMediaAsset(id),
                                icon: const Icon(
                                  LucideIcons.rotateCcw,
                                  size: 14,
                                ),
                                label: const Text('Đặt lại Retry'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadge(String status) {
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF059669);
    if (status == 'FAILED' || status == 'FAILED_PERMANENT') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFE11D48);
    } else if (status == 'PARTIAL_FAILURE' ||
        status == 'SKIPPED' ||
        status == 'INTERRUPTED_RECOVERED') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    } else if (status == 'SOFT_DELETED') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
