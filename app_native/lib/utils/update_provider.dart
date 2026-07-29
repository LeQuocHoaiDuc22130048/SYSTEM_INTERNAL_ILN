import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'dart:convert';

import 'api_client.dart';
import 'notification_provider.dart';
import '../theme/app_colors.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final bool mandatory;
  final String changelog;

  AppUpdateInfo({
    required this.updateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.mandatory,
    required this.changelog,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      updateAvailable: json['updateAvailable'] ?? false,
      latestVersion: json['latestVersion'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      mandatory: json['mandatory'] ?? false,
      changelog: json['changelog'] ?? '',
    );
  }
}

class UpdateProvider with ChangeNotifier {
  final ApiClient api;

  UpdateProvider({required this.api});

  String _currentVersion = '';
  String get currentVersion => _currentVersion;

  Future<void> _loadCurrentVersion() async {
    if (_currentVersion.isNotEmpty) return;
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
  }

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  AppUpdateInfo? _updateInfo;
  AppUpdateInfo? get updateInfo => _updateInfo;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  String _downloadStatus = '';
  String get downloadStatus => _downloadStatus;

  Future<void> checkForUpdate(BuildContext context, {required bool manual}) async {
    if (_isChecking || _isDownloading) return;
    
    _isChecking = true;
    notifyListeners();

    if (manual) {
      _showLoadingDialog(context);
    }

    try {
      await _loadCurrentVersion();
      final response = await api.get(
        '/api/v1/app-updates/check',
        queryParameters: {'version': _currentVersion},
      );

      if (manual && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }

      if (response != null && response is Map<String, dynamic>) {
        _updateInfo = AppUpdateInfo.fromJson(response);
        notifyListeners();

        if (context.mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          if (_updateInfo!.updateAvailable) {
            notificationProvider.setUpdateNotification(
              latestVersion: _updateInfo!.latestVersion,
              changelog: _updateInfo!.changelog,
            );

            _showUpdateDialog(context, _updateInfo!);

            if (!manual) {
              await notificationProvider.showLocalNotification(
                id: 9999,
                title: 'Có bản cập nhật mới (v${_updateInfo!.latestVersion})',
                body: _updateInfo!.changelog.isNotEmpty
                    ? _updateInfo!.changelog.replaceAll('\\n', '\n')
                    : 'Nhấn để xem chi tiết và cập nhật.',
                payload: jsonEncode({
                  'id': 'app_update_notification',
                  'type': 'APP_UPDATE',
                  'title': 'Có bản cập nhật mới (v${_updateInfo!.latestVersion})',
                  'body': _updateInfo!.changelog,
                }),
              );
            }
          } else {
            notificationProvider.clearUpdateNotification();
            if (manual) {
              _showSnackBar(context, 'Bạn đang sử dụng phiên bản mới nhất ($currentVersion)');
            }
          }
        }
      }
    } catch (e) {
      if (manual && context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }
      if (manual && context.mounted) {
        _showSnackBar(context, 'Lỗi kiểm tra cập nhật: ${e.toString()}', isError: true);
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(
                'Đang kiểm tra cập nhật...',
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAndInstall(BuildContext context, String url) async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadStatus = 'Đang kết nối tới máy chủ...';
    notifyListeners();

    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Mã phản hồi lỗi từ máy chủ: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final List<int> bytes = [];

      await response.stream.listen(
        (chunk) {
          bytes.addAll(chunk);
          downloadedBytes += chunk.length;
          if (contentLength > 0) {
            _downloadProgress = downloadedBytes / contentLength;
            final double mbDownloaded = downloadedBytes / (1024 * 1024);
            final double mbTotal = contentLength / (1024 * 1024);
            _downloadStatus = 'Đang tải: ${(_downloadProgress * 100).toStringAsFixed(0)}% (${mbDownloaded.toStringAsFixed(1)} MB / ${mbTotal.toStringAsFixed(1)} MB)';
          } else {
            final double mbDownloaded = downloadedBytes / (1024 * 1024);
            _downloadStatus = 'Đang tải: ${mbDownloaded.toStringAsFixed(1)} MB';
          }
          notifyListeners();
        },
        onError: (e) {
          throw e;
        },
        cancelOnError: true,
      ).asFuture();

      _downloadStatus = 'Đang chuẩn bị file cài đặt...';
      notifyListeners();

      final tempDir = await getTemporaryDirectory();
      final String fileName = url.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await file.writeAsBytes(bytes);

      _downloadStatus = 'Đang kích hoạt trình cài đặt...';
      notifyListeners();

      if (Platform.isWindows) {
        await Process.start(file.path, [], runInShell: true);
        exit(0);
      } else {
        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          throw Exception('Không thể mở trình cài đặt: ${result.message}');
        }
      }

      // Close dialog if not mandatory
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Lỗi tải/cài đặt cập nhật: ${e.toString()}', isError: true);
      }
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadStatus = '';
      notifyListeners();
      client.close();
    }
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (dialogContext) {
        return Consumer<UpdateProvider>(
          builder: (context, provider, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final isDownloading = provider.isDownloading;
            final downloadProgress = provider.downloadProgress;
            final downloadStatus = provider.downloadStatus;

            return WillPopScope(
              onWillPop: () async => !info.mandatory && !isDownloading,
              child: Dialog(
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.system_update,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Phát hiện phiên bản mới!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Phiên bản hiện tại: v$currentVersion | Phiên bản mới: v${info.latestVersion}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Chi tiết cập nhật:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            info.changelog.isNotEmpty
                                ? info.changelog.replaceAll('\\n', '\n')
                                : 'Không có chi tiết thay đổi nào được cung cấp.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isDownloading) ...[
                        Text(
                          downloadStatus,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: downloadProgress > 0 ? downloadProgress : null,
                            minHeight: 8,
                            backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                            color: AppColors.primary,
                          ),
                        ),
                      ] else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!info.mandatory)
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Để sau',
                                  style: TextStyle(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () {
                                final downloadUrlResolved = api.resolveUrl(info.downloadUrl);
                                provider._downloadAndInstall(dialogContext, downloadUrlResolved);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cập nhật ngay'),
                            ),
                          ],
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

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
