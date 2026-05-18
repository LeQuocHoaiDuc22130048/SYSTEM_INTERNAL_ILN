import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../utils/network_provider.dart';
import '../utils/pending_sync_provider.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkProvider, PendingSyncProvider>(
      builder: (context, network, pendingSync, _) {
        return Stack(
          children: [
            child,
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: network.isOffline || pendingSync.hasPending || pendingSync.isSyncing
                      ? _SyncNotice(
                          isOffline: network.isOffline,
                          pendingCount: pendingSync.pendingCount,
                          isSyncing: pendingSync.isSyncing,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SyncNotice extends StatelessWidget {
  final bool isOffline;
  final int pendingCount;
  final bool isSyncing;

  const _SyncNotice({
    required this.isOffline,
    required this.pendingCount,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final message = isOffline
        ? pendingCount > 0
            ? 'Mất internet. $pendingCount thay đổi sẽ được đồng bộ khi có mạng.'
            : 'Thiết bị đang mất kết nối internet. Vui lòng kiểm tra mạng và thử lại.'
        : isSyncing
            ? 'Đang đồng bộ các thay đổi đã ghi nhận...'
            : '$pendingCount thay đổi đang chờ đồng bộ.';
    final color = isOffline ? AppColors.error : AppColors.warning;
    final icon = isOffline
        ? LucideIcons.wifiOff
        : isSyncing
            ? LucideIcons.refreshCw
            : LucideIcons.cloudUpload;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
