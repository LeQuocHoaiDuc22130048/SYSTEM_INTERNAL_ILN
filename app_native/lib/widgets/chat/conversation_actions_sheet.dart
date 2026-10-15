import 'package:flutter/material.dart';
import '../../models/conversation.dart';

/// Callbacks are omitted when the account cannot perform an action.
class ConversationActionsSheet extends StatelessWidget {
  const ConversationActionsSheet({
    super.key,
    required this.conversation,
    this.onPin,
    this.onMute,
    this.onRead,
    required this.onGallery,
    required this.onSearch,
    required this.onInfo,
  });

  final ChatConversation conversation;
  final VoidCallback? onPin, onMute, onRead;
  final VoidCallback onGallery, onSearch, onInfo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget action(IconData icon, String label, VoidCallback callback) =>
        ListTile(
          leading: Icon(icon, color: colors.primary),
          title: Text(label),
          onTap: callback,
        );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  conversation.name.trim().isEmpty
                      ? '?'
                      : conversation.name.trim().characters.first.toUpperCase(),
                ),
              ),
              title: Text(
                conversation.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                conversation.type == 'GROUP'
                    ? '${conversation.members.length} thành viên'
                    : 'Cuộc trò chuyện riêng',
              ),
            ),
            if (onPin != null)
              action(
                Icons.push_pin_outlined,
                conversation.isPinned ? 'Bỏ ghim hội thoại' : 'Ghim hội thoại',
                onPin!,
              ),
            if (onMute != null)
              action(
                Icons.notifications_none_outlined,
                conversation.notificationsMuted
                    ? 'Bật thông báo'
                    : 'Tắt thông báo',
                onMute!,
              ),
            if (onRead != null && conversation.unreadCount > 0)
              action(
                Icons.mark_email_read_outlined,
                'Đánh dấu đã đọc',
                onRead!,
              ),
            const Divider(),
            action(
              Icons.photo_library_outlined,
              'Xem ảnh, file & liên kết',
              onGallery,
            ),
            action(Icons.search, 'Tìm kiếm tin nhắn', onSearch),
            action(
              Icons.info_outline,
              conversation.type == 'GROUP'
                  ? 'Thành viên nhóm'
                  : 'Thông tin cuộc trò chuyện',
              onInfo,
            ),
          ],
        ),
      ),
    );
  }
}
