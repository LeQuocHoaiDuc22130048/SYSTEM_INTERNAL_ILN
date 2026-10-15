import '../widgets/chat/conversation_actions_sheet.dart';
import '../widgets/permission_gate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../models/app_permission.dart';
import '../models/chat_repair_order_card.dart';
import '../utils/chat_provider.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/media_auth_headers.dart';
import '../services/giphy_service.dart';
import '../widgets/modal_top_bar.dart';
import '../widgets/directional_slide_switcher.dart';
import '../widgets/navigation/app_back_button.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/image_preview_dialog.dart';
import '../widgets/chat/chat_media_image.dart';
import '../widgets/chat/chat_message_gestures.dart';
import '../widgets/chat/message_presentation.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/add_members_dialog.dart';
import '../widgets/chat/repair_order_picker_dialog.dart';
import '../widgets/chat/repair_order_message_card.dart';
import '../widgets/chat/voice_record_button.dart';
import '../widgets/chat/voice_message_player.dart';
import '../services/voice_recorder.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _conversationFilter = 'all';
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final activeId = chatProvider.activeConversationId;

    if (activeId != null) {
      final currentConv = chatProvider.conversations.firstWhere(
        (c) => c.id == activeId,
        orElse: () => ChatConversation(
          id: activeId,
          type: 'DIRECT',
          name: 'Cuộc trò chuyện',
          avatarUrl: null,
          members: [],
          lastMessage: null,
          unreadCount: 0,
          createdAt: DateTime.now(),
        ),
      );

      return DirectionalSlideSwitcher(
        isForward: true,
        child: _ChatDetailPage(
          key: ValueKey(activeId),
          conversation: currentConv,
          isDark: isDark,
          onBack: () {
            chatProvider.clearActiveChat();
          },
        ),
      );
    }

    return DirectionalSlideSwitcher(
      isForward: false,
      child: _ConversationListPage(
        key: const ValueKey('conversation-list'),
        filter: _conversationFilter,
        onFilterChanged: (value) => setState(() => _conversationFilter = value),
        isDark: isDark,
        onSelect: (conversation) {
          chatProvider.loadMessages(conversation.id);
        },
      ),
    );
  }
}

class _ConversationListPage extends StatefulWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final bool isDark;
  final ValueChanged<ChatConversation> onSelect;

  const _ConversationListPage({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.isDark,
    required this.onSelect,
  });

  @override
  State<_ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<_ConversationListPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
      context.read<BackendDataProvider>().loadEmployees(notify: false);
    });
  }

  void _showNewChatDialog(BuildContext context) {
    final employees = context.read<BackendDataProvider>().employees;
    final currentUser = context.read<AuthProvider>().currentUser;
    final list = employees.where((e) => e.id != currentUser?.id).toList();

    showDialog(
      context: context,
      builder: (context) => _NewChatDialog(
        employees: list,
        onChatCreated: (conv) {
          widget.onSelect(conv);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final chatProvider = context.watch<ChatProvider>();
    final wide = MediaQuery.sizeOf(context).width > 760;

    final filteredConversations = chatProvider.conversations.where((conv) {
      if (widget.filter == 'unread' && conv.unreadCount == 0) return false;
      if (widget.filter == 'group' && conv.type != 'GROUP') return false;
      final query = _searchQuery.toLowerCase();
      final matchesName = conv.name.toLowerCase().contains(query);
      final matchesMsg =
          conv.lastMessage?.content.toLowerCase().contains(query) ?? false;
      return matchesName || matchesMsg;
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 20 : 22,
                wide ? 22 : 16,
                wide ? 20 : 22,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tin nhắn',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  PermissionGate(
                    permission: AppPermission.createConversations,
                    child: IconButton(
                      onPressed: () => _showNewChatDialog(context),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.messageSquarePlus,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm cuộc trò chuyện...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.surfaceDark
                        : AppColors.backgroundLight,
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(
                children: [
                  for (final option in [
                    ('all', 'Tất cả'),
                    (
                      'unread',
                      'Chưa đọc (${chatProvider.conversations.where((c) => c.unreadCount > 0).length})',
                    ),
                    ('group', 'Nhóm'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(option.$2),
                        labelStyle: const TextStyle(fontSize: 12),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        selected: widget.filter == option.$1,
                        onSelected: (_) => widget.onFilterChanged(option.$1),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: chatProvider.loadConversations,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: filteredConversations.isEmpty
                      ? 1
                      : filteredConversations.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: (wide ? 20 : 22) + 50,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  itemBuilder: (context, index) {
                    if (filteredConversations.isEmpty) {
                      return SizedBox(
                        height: 300,
                        child: chatProvider.isLoadingConversations
                            ? const Center(child: CircularProgressIndicator())
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.searchX,
                                      size: 48,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      chatProvider.conversationsError != null
                                          ? 'Lỗi tải dữ liệu. Vui lòng thử lại.'
                                          : 'Không tìm thấy cuộc trò chuyện',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    }
                    final conversation = filteredConversations[index];
                    return Dismissible(
                      key: ValueKey('conversation-row-${conversation.id}'),
                      direction:
                          context.watch<AuthProvider>().can(
                            AppPermission.pinConversations,
                          )
                          ? (context.watch<AuthProvider>().can(
                                  AppPermission.muteConversations,
                                )
                                ? DismissDirection.horizontal
                                : DismissDirection.startToEnd)
                          : (context.watch<AuthProvider>().can(
                                  AppPermission.muteConversations,
                                )
                                ? DismissDirection.endToStart
                                : DismissDirection.none),
                      background: _conversationSwipeBackground(
                        conversation.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        Alignment.centerLeft,
                        AppColors.primary,
                      ),
                      secondaryBackground: _conversationSwipeBackground(
                        conversation.notificationsMuted
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        Alignment.centerRight,
                        Colors.orange,
                      ),
                      confirmDismiss: (direction) async {
                        await _runChatAction(
                          context,
                          (provider) => direction == DismissDirection.startToEnd
                              ? provider.pinConversation(
                                  conversation.id,
                                  !conversation.isPinned,
                                )
                              : provider.setNotificationsMuted(
                                  conversation.id,
                                  !conversation.notificationsMuted,
                                ),
                        );
                        return false;
                      },
                      child: _ConversationTile(
                        conversation: conversation,
                        isDark: isDark,
                        horizontalPadding: wide ? 20 : 22,
                        onTap: () => widget.onSelect(conversation),
                        onLongPress: () =>
                            _showConversationActions(context, conversation),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _conversationSwipeBackground(
  IconData icon,
  Alignment alignment,
  Color color,
) => Container(
  color: color.withValues(alpha: 0.12),
  alignment: alignment,
  padding: const EdgeInsets.symmetric(horizontal: 22),
  child: Icon(icon, color: color),
);

Future<void> _runChatAction(
  BuildContext context,
  Future<void> Function(ChatProvider) action,
) async {
  try {
    await action(context.read<ChatProvider>());
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
        ),
      );
    }
  }
}

void _showConversationActions(
  BuildContext context,
  ChatConversation conversation,
) {
  HapticFeedback.mediumImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final provider = context.read<ChatProvider>();

  void openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChangeNotifierProvider.value(value: provider, child: page),
      ),
    );
  }

  void openSearch() => openPage(
    _ConversationSearchPage(conversationId: conversation.id, isDark: isDark),
  );
  void openGallery() => openPage(
    _ConversationGalleryPage(conversationId: conversation.id, isDark: isDark),
  );
  Future<void> toggleMute() => _runChatAction(context, (provider) {
    final current =
        provider.conversations
            .where((item) => item.id == conversation.id)
            .firstOrNull ??
        conversation;
    return provider.setNotificationsMuted(
      conversation.id,
      !current.notificationsMuted,
    );
  });

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final auth = sheetContext.watch<AuthProvider>();
      VoidCallback closeThen(VoidCallback action) => () {
        Navigator.pop(sheetContext);
        action();
      };
      return ConversationActionsSheet(
        conversation: conversation,
        onPin: auth.can(AppPermission.pinConversations)
            ? closeThen(
                () => _runChatAction(
                  context,
                  (provider) => provider.pinConversation(
                    conversation.id,
                    !conversation.isPinned,
                  ),
                ),
              )
            : null,
        onMute: auth.can(AppPermission.muteConversations)
            ? closeThen(toggleMute)
            : null,
        onRead: auth.can(AppPermission.markConversationsRead)
            ? closeThen(
                () => _runChatAction(
                  context,
                  (provider) => provider.markAsRead(conversation.id),
                ),
              )
            : null,
        onGallery: closeThen(openGallery),
        onSearch: closeThen(openSearch),
        onInfo: closeThen(
          () => openPage(
            _ChatDetailInfoPage(
              conversation: conversation,
              isDark: isDark,
              onMuteToggle: toggleMute,
              onSearch: openSearch,
              onGallery: openGallery,
            ),
          ),
        ),
      );
    },
  );
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double horizontalPadding;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.horizontalPadding,
  });

  String get _avatarText {
    if (conversation.name.isEmpty) return '??';
    final parts = conversation.name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0])
          .toUpperCase();
    }
    return conversation.name[0].toUpperCase();
  }

  Color get _avatarColor {
    final hash = conversation.name.hashCode;
    final index = hash.abs() % Colors.primaries.length;
    return Colors.primaries[index];
  }

  String get _messageText {
    final lastMsg = conversation.lastMessage;
    if (lastMsg == null) return 'Chưa có tin nhắn';
    final content = lastMsg.content.isNotEmpty
        ? lastMsg.content
        : switch (lastMsg.messageType) {
            'IMAGE' => 'Đã gửi một ảnh',
            'VIDEO' => 'Đã gửi một video',
            'FILE' => 'Đã gửi một tệp đính kèm',
            _ => '',
          };
    return '${lastMsg.senderName}: $content';
  }

  String get _timeText {
    final lastMsg = conversation.lastMessage;
    if (lastMsg == null) return '';
    final sentAt = lastMsg.sentAt.toLocal();
    final now = DateTime.now();
    if (sentAt.year == now.year &&
        sentAt.month == now.month &&
        sentAt.day == now.day) {
      return DateFormat('HH:mm').format(sentAt);
    }
    return DateFormat('dd/MM').format(sentAt);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          12,
        ),
        child: Row(
          children: [
            Container(
              key: ValueKey('conversation-avatar-${conversation.id}'),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: conversation.type == 'GROUP'
                    ? const Icon(
                        LucideIcons.usersRound,
                        color: Colors.white,
                        size: 17,
                      )
                    : Text(
                        _avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
                  Row(
                    children: [
                      if (conversation.isPinned) ...[
                        const Icon(
                          Icons.push_pin_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conversation.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w900
                                : FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _messageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: conversation.unreadCount > 0
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                if (conversation.unreadCount > 0)
                  Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 17),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MentionSuggestion {
  final String userId;
  final String displayName;
  final String? subtitle;

  const _MentionSuggestion({
    required this.userId,
    required this.displayName,
    this.subtitle,
  });
}

class _ChatDetailPage extends StatefulWidget {
  final ChatConversation conversation;
  final bool isDark;
  final VoidCallback onBack;

  const _ChatDetailPage({
    super.key,
    required this.conversation,
    required this.isDark,
    required this.onBack,
  });

  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  late final ChatProvider _chatProvider;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final Set<String> _expandedMetadata = {};
  bool _showScrollToBottom = false;
  double _edgeBackDistance = 0;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  bool _voiceBusy = false;
  bool _isTyping = false;
  ChatMessage? _replyingToMessage;

  // Mention autocomplete state
  String? _mentionQuery; // non-null when user is typing @...

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    _controller.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _chatProvider.updateTyping(false);
    _controller.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _inputFocus.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 180;
    if (show != _showScrollToBottom) setState(() => _showScrollToBottom = show);
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent - _scrollController.offset <
            180 &&
        _chatProvider.olderMessagesError == null) {
      _chatProvider.loadOlderMessages();
    }
  }

  void _replyTo(ChatMessage message) {
    setState(() => _replyingToMessage = message);
    _inputFocus.requestFocus();
  }

  Future<void> _showAttachments() async {
    final canShareOrder = context.read<AuthProvider>().can(
      AppPermission.viewRepairOrders,
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              ('file', Icons.attach_file, 'Đính kèm tệp'),
              ('camera', Icons.camera_alt_outlined, 'Chụp ảnh'),
              ('gallery', Icons.photo_library_outlined, 'Ảnh và video'),
              if (canShareOrder)
                ('order', Icons.build_circle_outlined, 'Gửi thẻ đơn sửa chữa'),
            ])
              ListTile(
                leading: Icon(item.$2),
                title: Text(item.$3),
                onTap: () => Navigator.pop(sheetContext, item.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'file':
        await _pickFile();
      case 'camera':
        await _pickCamera();
      case 'gallery':
        await _pickMedia();
      case 'order':
        final provider = context.read<ChatProvider>();
        final parentId = _replyingToMessage?.id;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RepairOrderPickerDialog(
            api: provider.api,
            onSend: (order) async {
              await provider.sendMessage(
                widget.conversation.id,
                ChatRepairOrderCard.fromOrder(order).toContent(),
                parentMessageId: parentId,
              );
              if (mounted) setState(() => _replyingToMessage = null);
            },
          ),
        );
    }
  }

  Future<void> _sendVoice(RecordedVoice voice) async {
    await _chatProvider.sendMediaMessage(
      widget.conversation.id,
      bytes: voice.bytes,
      filename: voice.filename,
      messageType: 'FILE',
      contentType: 'audio/mp4',
      content: 'Tin nhắn thoại (${voice.duration.inSeconds}s)',
      parentMessageId: _replyingToMessage?.id,
    );
    if (mounted) setState(() => _replyingToMessage = null);
  }

  void _onTextChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;
    _chatProvider.updateTyping(isTyping);
    if (isTyping != _isTyping) {
      setState(() {
        _isTyping = isTyping;
      });
    }

    // Only show mention suggestions in group chats
    if (widget.conversation.type != 'GROUP') return;

    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return;

    // Find the last '@' before the cursor
    final textBeforeCursor = text.substring(0, cursorPos.clamp(0, text.length));
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex != -1) {
      // Ensure there is no space between '@' and cursor
      final query = textBeforeCursor.substring(atIndex + 1);
      if (!query.contains(' ')) {
        if (_mentionQuery != query) {
          setState(() => _mentionQuery = query);
        }
        return;
      }
    }
    if (_mentionQuery != null) {
      setState(() => _mentionQuery = null);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final parentId = _replyingToMessage?.id;
    if (parentId != null) {
      setState(() {
        _replyingToMessage = null;
      });
    }
    context.read<ChatProvider>().sendMessage(
      widget.conversation.id,
      text,
      mentionUserIds: _mentionUserIdsFor(text),
      parentMessageId: parentId,
    );
  }

  void _sendLike() {
    context.read<ChatProvider>().sendMessage(widget.conversation.id, '👍');
  }

  Future<void> _pickCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file != null) {
      await _uploadMedia(await file.readAsBytes(), file.name, 'IMAGE');
    }
  }

  List<String> _mentionUserIdsFor(String text) {
    final normalizedText = text.toLowerCase();
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    // @All mentions every member except the sender
    if (normalizedText.contains('@all') || normalizedText.contains('@tất cả')) {
      return widget.conversation.members
          .where((m) => m.userId != currentUserId)
          .map((m) => m.userId)
          .toList();
    }
    final ids = <String>{};
    for (final member in widget.conversation.members) {
      if (member.userId == currentUserId) continue;
      final names = <String>[
        member.fullName,
        if (member.employeeCode != null) member.employeeCode!,
      ];
      for (final name in names) {
        final token = name.trim().toLowerCase();
        if (token.isNotEmpty && normalizedText.contains('@$token')) {
          ids.add(member.userId);
        }
      }
    }
    return ids.toList();
  }

  /// Called when user taps a mention suggestion.
  void _handleMentionSelected(String displayName) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final before = text.substring(0, atIndex);
    final after = text.substring(cursorPos);
    final inserted = '@$displayName ';
    final newText = '$before$inserted$after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + inserted.length,
      ),
    );
    setState(() => _mentionQuery = null);
  }

  /// Builds the mention suggestion list shown above the input bar.
  Widget _buildMentionSuggestions() {
    if (_mentionQuery == null || widget.conversation.type != 'GROUP') {
      return const SizedBox.shrink();
    }
    final query = _mentionQuery!.toLowerCase();
    final isDark = widget.isDark;

    // Build suggestion entries: first "All", then members (excluding self)
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final List<_MentionSuggestion> suggestions = [];
    if ('all'.startsWith(query) || 'tất cả'.contains(query)) {
      suggestions.add(
        const _MentionSuggestion(
          userId: '__all__',
          displayName: 'All',
          subtitle: 'Nhắc tất cả thành viên',
        ),
      );
    }
    for (final member in widget.conversation.members) {
      if (member.userId == currentUserId) continue; // skip self
      if (member.fullName.toLowerCase().contains(query) ||
          (member.employeeCode?.toLowerCase().contains(query) ?? false)) {
        suggestions.add(
          _MentionSuggestion(
            userId: member.userId,
            displayName: member.fullName,
            subtitle: member.employeeCode,
          ),
        );
      }
    }
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        separatorBuilder: (context, idx) =>
            Divider(height: 1, color: borderColor, indent: 52),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          final isAll = s.userId == '__all__';
          return InkWell(
            onTap: () => _handleMentionSelected(s.displayName),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isAll
                        ? AppColors.primary
                        : Colors.primaries[s.displayName.hashCode.abs() %
                              Colors.primaries.length],
                    child: isAll
                        ? const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 16,
                          )
                        : Text(
                            s.displayName.isNotEmpty
                                ? s.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@${s.displayName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (s.subtitle != null && s.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            s.subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMedia() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultipleMedia();
      if (pickedFiles.isNotEmpty) {
        await _uploadMultipleMedia(pickedFiles);
      }
    } catch (e) {
      debugPrint('[CHAT] Error picking media: $e');
    }
  }

  Future<void> _uploadMultipleMedia(List<XFile> files) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      String caption = _controller.text.trim();
      bool isFirst = true;

      final parentId = _replyingToMessage?.id;
      if (parentId != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }

      for (final file in files) {
        final bytes = await file.readAsBytes();
        final type = _getMediaType(file);

        await chatProvider.sendMediaMessage(
          widget.conversation.id,
          bytes: Uint8List.fromList(bytes),
          filename: file.name,
          messageType: type,
          content: isFirst ? caption : '',
          parentMessageId: isFirst ? parentId : null,
        );

        if (isFirst && caption.isNotEmpty) {
          _controller.clear();
          caption = '';
        }
        isFirst = false;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể gửi tệp: $error')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getMediaType(XFile file) {
    final mime = file.mimeType;
    if (mime != null) {
      if (mime.startsWith('video/')) return 'VIDEO';
      if (mime.startsWith('image/')) return 'IMAGE';
    }
    final path = file.path.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv') ||
        path.endsWith('.3gp') ||
        path.endsWith('.webm') ||
        path.endsWith('.flv') ||
        path.endsWith('.wmv')) {
      return 'VIDEO';
    }
    return 'IMAGE';
  }

  Widget _buildReplyPreviewBar() {
    final msg = _replyingToMessage!;
    final isDark = widget.isDark;

    String displayContent = msg.isRecalled
        ? 'Tin nhắn đã bị thu hồi'
        : msg.content;
    if (!msg.isRecalled && displayContent.isEmpty) {
      if (msg.messageType == 'IMAGE') {
        displayContent = 'Đã gửi một hình ảnh';
      } else if (msg.messageType == 'VIDEO') {
        displayContent = 'Đã gửi một video';
      } else if (msg.messageType == 'FILE') {
        displayContent = 'Đã gửi một tệp đính kèm';
      } else {
        displayContent = 'Tin nhắn đính kèm';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : Colors.grey.shade300,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đang trả lời ${msg.sender.fullName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayContent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontStyle: msg.isRecalled
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file != null && file.bytes != null) {
      await _uploadMedia(file.bytes!, file.name, 'FILE');
    }
  }

  Future<void> _uploadMedia(
    List<int> bytes,
    String fileName,
    String type,
  ) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final caption = type == 'FILE' ? '' : _controller.text.trim();
      final parentId = _replyingToMessage?.id;
      if (parentId != null) {
        setState(() {
          _replyingToMessage = null;
        });
      }
      await context.read<ChatProvider>().sendMediaMessage(
        widget.conversation.id,
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
        messageType: type,
        content: caption,
        parentMessageId: parentId,
      );
      if (caption.isNotEmpty) {
        _controller.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể gửi tệp: $error')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showConversationSearch() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _ConversationSearchPage(
          conversationId: widget.conversation.id,
          isDark: widget.isDark,
        ),
      ),
    );
  }

  void _showConversationGallery() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _ConversationGalleryPage(
          conversationId: widget.conversation.id,
          isDark: widget.isDark,
        ),
      ),
    );
  }

  void _showConversationTools() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => _ChatDetailInfoPage(
          conversation: widget.conversation,
          isDark: widget.isDark,
          onMuteToggle: _toggleConversationMute,
          onSearch: _showConversationSearch,
          onGallery: _showConversationGallery,
        ),
      ),
    );
  }

  Future<void> _toggleConversationMute() async {
    await _runChatAction(context, (provider) {
      final current =
          provider.conversations
              .where((c) => c.id == widget.conversation.id)
              .firstOrNull ??
          widget.conversation;
      return provider.setNotificationsMuted(
        current.id,
        !current.notificationsMuted,
      );
    });
  }

  String get _avatarText {
    if (widget.conversation.name.isEmpty) return '??';
    final parts = widget.conversation.name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0])
          .toUpperCase();
    }
    return widget.conversation.name[0].toUpperCase();
  }

  Color get _avatarColor {
    final hash = widget.conversation.name.hashCode;
    final index = hash.abs() % Colors.primaries.length;
    return Colors.primaries[index];
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? AppColors.surfaceDark : Colors.white;
    final background = widget.isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final chatProvider = context.watch<ChatProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final latestOutgoingId = chatProvider.activeMessages
        .where((m) => m.sender.userId == currentUser?.id && !m.isRecalled)
        .firstOrNull
        ?.id;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              decoration: BoxDecoration(
                color: surface,
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppBackButton(
                      isDark: widget.isDark,
                      onPressed: widget.onBack,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showConversationTools,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _avatarColor,
                        shape: BoxShape.circle,
                      ),
                      child: widget.conversation.type == 'GROUP'
                          ? const Icon(
                              LucideIcons.usersRound,
                              color: Colors.white,
                              size: 16,
                            )
                          : Center(
                              child: Text(
                                _avatarText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('chat-header-info'),
                      onTap: _showConversationTools,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            widget.conversation.type == 'GROUP'
                                ? '${widget.conversation.members.length} thành viên'
                                : 'Đang hoạt động',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Thông tin cuộc trò chuyện',
                    onPressed: _showConversationTools,
                    icon: const Icon(Icons.info_outline, size: 22),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            if (widget.conversation.pinnedMessage != null)
              _PinnedMessageBanner(
                conversation: widget.conversation,
                isDark: widget.isDark,
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: chatProvider.isLoadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : chatProvider.activeMessages.isEmpty
                        ? Center(
                            child: Text(
                              'Chưa có tin nhắn. Bắt đầu cuộc trò chuyện!',
                              style: TextStyle(
                                color: widget.isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          )
                        : ListView.builder(
                            key: const ValueKey('chat-message-list'),
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            reverse: true, // Auto-scrolls to bottom
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            itemCount:
                                chatProvider.activeMessages.length +
                                (chatProvider.hasMoreMessages ||
                                        chatProvider.olderMessagesError != null
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (index == chatProvider.activeMessages.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: chatProvider.isLoadingOlderMessages
                                      ? const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : TextButton(
                                          onPressed:
                                              chatProvider.loadOlderMessages,
                                          child: Text(
                                            chatProvider.olderMessagesError ==
                                                    null
                                                ? 'Tải tin nhắn cũ'
                                                : 'Không thể tải tin nhắn cũ. Thử lại',
                                          ),
                                        ),
                                );
                              }
                              final message =
                                  chatProvider.activeMessages[index];
                              final isMe =
                                  message.sender.userId == currentUser?.id;

                              if (message.messageType == 'SYSTEM') {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    message.content,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: widget.isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }
                              final groupedWithNewer =
                                  index > 0 &&
                                  messagesBelongToSameGroup(
                                    message,
                                    chatProvider.activeMessages[index - 1],
                                  );
                              final groupedWithOlder =
                                  index + 1 <
                                      chatProvider.activeMessages.length &&
                                  messagesBelongToSameGroup(
                                    message,
                                    chatProvider.activeMessages[index + 1],
                                  );
                              return Padding(
                                key: ValueKey('chat-message-${message.id}'),
                                padding: EdgeInsets.only(
                                  bottom: groupedWithNewer ? 4 : 12,
                                ),
                                child: _ChatMessageBubble(
                                  message: message,
                                  isDark: widget.isDark,
                                  isOutgoing: isMe,
                                  showMetadata:
                                      !groupedWithNewer ||
                                      _expandedMetadata.contains(message.id),
                                  showSender: !groupedWithOlder,
                                  showAvatar: !groupedWithNewer,
                                  showDeliveryStatus:
                                      message.id == latestOutgoingId,
                                  onReply: () => _replyTo(message),
                                  onTap: () => setState(() {
                                    if (!_expandedMetadata.add(message.id)) {
                                      _expandedMetadata.remove(message.id);
                                    }
                                  }),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_showScrollToBottom)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        tooltip: 'Tin nhắn mới nhất',
                        onPressed: () => _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        ),
                        child: const Icon(Icons.arrow_downward),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 18,
                    child: Listener(
                      onPointerCancel: (_) => _edgeBackDistance = 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: (_) => _edgeBackDistance = 0,
                        onHorizontalDragUpdate: (details) =>
                            _edgeBackDistance += details.delta.dx,
                        onHorizontalDragEnd: (_) {
                          if (_edgeBackDistance >= 50) {
                            _inputFocus.unfocus();
                            widget.onBack();
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (chatProvider.typingUserIds.any((id) => id != currentUser?.id))
              TypingIndicator(
                names: chatProvider.typingUserIds
                    .where((id) => id != currentUser?.id)
                    .map(
                      (id) =>
                          widget.conversation.members
                              .where((m) => m.userId == id)
                              .firstOrNull
                              ?.fullName ??
                          (widget.conversation.type == 'DIRECT'
                              ? widget.conversation.name
                              : 'Người dùng'),
                    )
                    .toList(),
              ),
            _buildMentionSuggestions(),
            PermissionGate.any(
              permissions: const [
                AppPermission.sendMessages,
                AppPermission.uploadMessages,
              ],
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  8 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(
                    top: BorderSide(
                      color: widget.isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToMessage != null) ...[
                      _buildReplyPreviewBar(),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Visibility(
                          visible: !_isTyping,
                          maintainSize: false,
                          maintainAnimation: false,
                          maintainState: false,
                          child: PermissionGate(
                            permission: AppPermission.uploadMessages,
                            child: IconButton(
                              onPressed: _isUploading || _voiceBusy
                                  ? null
                                  : _showAttachments,
                              tooltip: 'Thêm nội dung',
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 24,
                              ),
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Visibility(
                          visible: _isTyping,
                          maintainSize: false,
                          maintainAnimation: false,
                          maintainState: false,
                          child: IconButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _isTyping = false;
                              });
                            },
                            icon: const Icon(Icons.chevron_right, size: 24),
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    enabled: !_voiceBusy,
                                    focusNode: _inputFocus,
                                    onSubmitted: (_) => _handleSend(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: widget.isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Nhập tin nhắn...',
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        PermissionGate(
                          permission: AppPermission.uploadMessages,
                          child: VoiceRecordButton(
                            onSend: _sendVoice,
                            enabled: !_isUploading,
                            onBusyChanged: (busy) {
                              if (mounted) setState(() => _voiceBusy = busy);
                            },
                          ),
                        ),
                        Visibility(
                          visible: _isTyping,
                          maintainSize: false,
                          maintainAnimation: false,
                          maintainState: false,
                          child: PermissionGate(
                            permission: AppPermission.sendMessages,
                            child: InkWell(
                              onTap: _isUploading || _voiceBusy
                                  ? null
                                  : _handleSend,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.send,
                                        size: 22,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: !_isTyping,
                          maintainSize: false,
                          maintainAnimation: false,
                          maintainState: false,
                          child: PermissionGate(
                            permission: AppPermission.sendMessages,
                            child: IconButton(
                              onPressed: _voiceBusy ? null : _sendLike,
                              icon: const Icon(Icons.thumb_up, size: 22),
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiphyPickerSheet extends StatefulWidget {
  final String type;
  final VoidCallback onManualUrl;

  const _GiphyPickerSheet({required this.type, required this.onManualUrl});

  @override
  State<_GiphyPickerSheet> createState() => _GiphyPickerSheetState();
}

class _GiphyPickerSheetState extends State<_GiphyPickerSheet> {
  final _service = GiphyService();
  final _queryController = TextEditingController(text: 'hello');
  List<GiphyItem> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.search(query: query, type: widget.type);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      String errorMsg = 'Không thể tìm trên Giphy. Kiểm tra mạng hoặc key.';
      if (error is GiphyMissingApiKeyException) {
        errorMsg = 'Chưa cấu hình GIPHY_API_KEY khi chạy/build app.';
      } else if (error is GiphyException) {
        errorMsg = 'Lỗi Giphy: ${error.message}';
        if (error.message.contains('401')) {
          errorMsg =
              'Lỗi Giphy (401 Unauthorized): API Key không hợp lệ hoặc đã hết hạn.';
        }
      }
      setState(() => _error = errorMsg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: widget.type == 'GIF'
                            ? 'Tim GIF tren Giphy'
                            : 'Tim sticker tren Giphy',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _search, child: const Text('Tim')),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onManualUrl,
                      child: const Text('Gui URL'),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: widget.onManualUrl,
                    child: const Text('Gui URL rieng'),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('Chua co ket qua'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, item),
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                    color: Color(0xFFE5E7EB),
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchPage extends StatefulWidget {
  final String conversationId;
  final bool isDark;

  const _ConversationSearchPage({
    required this.conversationId,
    required this.isDark,
  });

  @override
  State<_ConversationSearchPage> createState() =>
      _ConversationSearchPageState();
}

class _ConversationSearchPageState extends State<_ConversationSearchPage> {
  final _controller = TextEditingController();
  List<ChatMessage> _results = const [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });
    try {
      final results = await context.read<ChatProvider>().searchMessages(
        widget.conversationId,
        query,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Không thể tìm tin nhắn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = widget.isDark ? AppColors.surfaceDark : Colors.white;
    final textPrimaryColor = widget.isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final inputBg = widget.isDark
        ? AppColors.borderDark
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: AppBackButton(
              isDark: widget.isDark,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Tìm kiếm tin nhắn',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                      style: TextStyle(color: textPrimaryColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Nhập từ khóa cần tìm...',
                        hintStyle: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: textSecondaryColor,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _search,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Tìm'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 60,
                          color: textSecondaryColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nhập từ khóa tin nhắn để tìm kiếm',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: textSecondaryColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy tin nhắn nào',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => Divider(
                      color: widget.isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final message = _results[index];
                      final senderAvatarText = message.sender.fullName.isEmpty
                          ? '?'
                          : message.sender.fullName
                                .trim()
                                .split(' ')
                                .last[0]
                                .toUpperCase();
                      final senderHash = message.sender.fullName.hashCode;
                      final senderColor =
                          Colors.primaries[senderHash.abs() %
                              Colors.primaries.length];

                      return ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: senderColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              senderAvatarText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              message.sender.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'dd/MM HH:mm',
                              ).format(message.sentAt.toLocal()),
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            message.content.isEmpty
                                ? '[${message.messageType}]'
                                : message.content,
                            style: TextStyle(
                              fontSize: 13,
                              color: textPrimaryColor.withValues(alpha: 0.9),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationGalleryPage extends StatefulWidget {
  final String conversationId;
  final bool isDark;

  const _ConversationGalleryPage({
    required this.conversationId,
    required this.isDark,
  });

  @override
  State<_ConversationGalleryPage> createState() =>
      _ConversationGalleryPageState();
}

class _ConversationGalleryPageState extends State<_ConversationGalleryPage> {
  List<ChatMessage> _mediaItems = const [];
  List<ChatMessage> _linkItems = const [];
  List<ChatMessage> _fileItems = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chatProvider = context.read<ChatProvider>();
      final media = await chatProvider.loadGallery(
        widget.conversationId,
        'MEDIA',
      );
      final links = await chatProvider.loadGallery(
        widget.conversationId,
        'LINKS',
      );
      final files = await chatProvider.loadGallery(
        widget.conversationId,
        'FILES',
      );

      if (mounted) {
        setState(() {
          _mediaItems = media;
          _linkItems = links;
          _fileItems = files;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Không thể tải kho tài nguyên. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = widget.isDark ? AppColors.surfaceDark : Colors.white;
    final textPrimaryColor = widget.isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leadingWidth: 58,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: AppBackButton(
                isDark: widget.isDark,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: Text(
            'Ảnh, file & liên kết',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: textSecondaryColor,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Media'),
              Tab(text: 'Liên kết'),
              Tab(text: 'File'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAll,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : TabBarView(
                children: [
                  _buildMediaTab(),
                  _buildLinksTab(),
                  _buildFilesTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaTab() {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState(
        Icons.image_not_supported_outlined,
        'Chưa có file phương tiện nào',
      );
    }
    final provider = context.read<ChatProvider>();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final item = _mediaItems[index];
        final mediaUrl = item.mediaUrl == null
            ? null
            : provider.mediaUrl(item.mediaUrl!);
        if (mediaUrl == null) return const SizedBox.shrink();

        return InkWell(
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: item.messageType == 'VIDEO'
                ? Colors.transparent
                : Colors.black54,
            builder: (_) => item.messageType == 'VIDEO'
                ? VideoPlayerDialog(
                    videoUrl: mediaUrl,
                    title: 'Video',
                    senderName: item.sender.fullName,
                  )
                : ImagePreviewDialog(imageUrl: mediaUrl),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.messageType == 'VIDEO'
                ? const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Center(child: Icon(Icons.play_circle_outline)),
                  )
                : Image.network(
                    mediaUrl,
                    headers: mediaAuthHeaders(context, mediaUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    if (_linkItems.isEmpty) {
      return _buildEmptyState(Icons.link_off, 'Chưa có liên kết chia sẻ nào');
    }
    final textPrimaryColor = widget.isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final provider = context.read<ChatProvider>();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _linkItems.length,
      separatorBuilder: (context, index) => Divider(
        color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        final target = _firstLink(item.content) ?? item.mediaUrl;
        final resolved = target == null ? null : provider.mediaUrl(target);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.link, color: Colors.blue),
          ),
          title: Text(
            item.content.isEmpty ? (target ?? 'Liên kết') : item.content,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.sender.fullName} - ${DateFormat('dd/MM HH:mm').format(item.sentAt.toLocal())}',
            style: TextStyle(color: textSecondaryColor, fontSize: 11),
          ),
          onTap: resolved == null
              ? null
              : () => launchUrl(
                  Uri.parse(resolved),
                  mode: LaunchMode.externalApplication,
                ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    if (_fileItems.isEmpty) {
      return _buildEmptyState(
        Icons.folder_off_outlined,
        'Chưa có file tài liệu nào',
      );
    }
    final textPrimaryColor = widget.isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final provider = context.read<ChatProvider>();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _fileItems.length,
      separatorBuilder: (context, index) => Divider(
        color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final item = _fileItems[index];
        final filename = item.mediaUrl?.split('/').last ?? 'Tài liệu đính kèm';
        final resolved = item.mediaUrl == null
            ? null
            : provider.mediaUrl(item.mediaUrl!);
        final ext = filename.split('.').last.toLowerCase();

        Color iconColor = Colors.orange;
        IconData iconData = Icons.insert_drive_file;
        if (ext == 'pdf') {
          iconColor = Colors.red;
          iconData = Icons.picture_as_pdf;
        } else if (['doc', 'docx'].contains(ext)) {
          iconColor = Colors.blue;
          iconData = Icons.description;
        } else if (['xls', 'xlsx'].contains(ext)) {
          iconColor = Colors.green;
          iconData = Icons.table_view;
        }

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor),
          ),
          title: Text(
            filename,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.sender.fullName} - ${DateFormat('dd/MM HH:mm').format(item.sentAt.toLocal())}',
            style: TextStyle(color: textSecondaryColor, fontSize: 11),
          ),
          onTap: resolved == null
              ? null
              : () => launchUrl(
                  Uri.parse(resolved),
                  mode: LaunchMode.externalApplication,
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    final textSecondaryColor = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 54,
            color: textSecondaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String? _firstLink(String content) {
    final matches = RegExp(r'(https?://[^\s]+)').allMatches(content);
    return matches.isEmpty ? null : matches.first.group(0);
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  final ChatConversation conversation;
  final bool isDark;

  const _PinnedMessageBanner({
    required this.conversation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = conversation.pinnedMessage;
    if (pinned == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFFFFBEB),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFFDE68A),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.push_pin_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${pinned.senderName}: ${pinned.content.isEmpty ? pinned.messageType : pinned.content}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          PermissionGate(
            permission: AppPermission.pinMessages,
            child: IconButton(
              tooltip: 'Bỏ ghim tin nhắn',
              onPressed: () async {
                await context.read<ChatProvider>().unpinMessage(
                  conversation.id,
                );
              },
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final bool isOutgoing;
  final bool showMetadata;
  final bool showSender;
  final bool showAvatar;
  final bool showDeliveryStatus;
  final VoidCallback onReply;
  final VoidCallback onTap;

  const _ChatMessageBubble({
    required this.message,
    required this.isDark,
    required this.isOutgoing,
    required this.showMetadata,
    required this.showSender,
    required this.showAvatar,
    required this.showDeliveryStatus,
    required this.onReply,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final plain = hasPlainBubble(message);
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final name = message.sender.fullName.trim();
    final initials = name.isEmpty
        ? '?'
        : name.split(' ').last.characters.first.toUpperCase();
    final bubble = ChatMessageGestures(
      key: ValueKey('message-gestures-${message.id}'),
      enabled: !message.isRecalled,
      onReply: context.watch<AuthProvider>().can(AppPermission.sendMessages)
          ? onReply
          : null,
      onTap: message.messageType == 'TEXT' ? onTap : null,
      onDoubleTap:
          context.watch<AuthProvider>().can(AppPermission.reactMessages)
          ? () => _runChatAction(
              context,
              (provider) => provider.reactToMessage(
                message.conversationId,
                message.id,
                '❤️',
              ),
            )
          : null,
      onLongPress: () => _showMessageActionSheet(
        context,
        message: message,
        canEdit:
            isOutgoing && message.messageType == 'TEXT' && !message.isRecalled,
        canRecall: isOutgoing && !message.isRecalled,
        onReply: onReply,
      ),
      child: Container(
        padding: plain
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
            : EdgeInsets.zero,
        decoration: plain
            ? BoxDecoration(
                color: isOutgoing
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: isOutgoing
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.parentMessage != null)
              _ReplyPreviewWidget(
                parentMessage: message.parentMessage!,
                isOutgoing: isOutgoing && plain,
                isDark: isDark,
              ),
            _MessageContent(
              message: message,
              isOutgoing: isOutgoing,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: isOutgoing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isOutgoing && showSender)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              message.sender.fullName,
              style: TextStyle(fontSize: 11, color: secondary),
            ),
          ),
        bubble,
        if (message.reactions.isNotEmpty) ...[
          const SizedBox(height: 4),
          _ReactionPill(message: message),
        ],
        if (showMetadata) ...[
          const SizedBox(height: 4),
          Text(
            '${DateFormat('HH:mm').format(message.sentAt.toLocal())}${isOutgoing && showDeliveryStatus ? (message.readByUserIds.any((id) => id != message.sender.userId) ? ' Đã xem' : ' Đã gửi') : ''}',
            key: ValueKey('message-metadata-${message.id}'),
            style: TextStyle(fontSize: 10, color: secondary),
          ),
        ],
      ],
    );
    return Row(
      mainAxisAlignment: isOutgoing
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isOutgoing) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: showAvatar
                ? CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        Colors.primaries[message.sender.fullName.hashCode
                                .abs() %
                            Colors.primaries.length],
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: content),
      ],
    );
  }
}

const _reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

void _showMessageActionSheet(
  BuildContext context, {
  required ChatMessage message,
  required bool canEdit,
  required bool canRecall,
  required VoidCallback onReply,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalTopBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: _reactionEmojis
                    .map(
                      (emoji) => PermissionGate(
                        permission: AppPermission.reactMessages,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _runChatAction(
                              context,
                              (provider) => provider.reactToMessage(
                                message.conversationId,
                                message.id,
                                emoji,
                              ),
                            );
                          },
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            PermissionGate(
              permission: AppPermission.sendMessages,
              child: ListTile(
                leading: const Icon(Icons.reply_outlined),
                title: const Text('Trả lời'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReply();
                },
              ),
            ),
            if (!message.isRecalled && message.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Sao chép'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.content));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            if (canEdit)
              PermissionGate(
                permission: AppPermission.updateMessages,
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Sửa tin nhắn'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditMessageDialog(context, message);
                  },
                ),
              ),
            if (!message.isRecalled)
              PermissionGate(
                permission: AppPermission.pinMessages,
                child: ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text('Ghim tin nhắn'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _runChatAction(
                      context,
                      (provider) => provider.pinMessage(
                        message.conversationId,
                        message.id,
                      ),
                    );
                  },
                ),
              ),
            PermissionGate(
              permission: AppPermission.deleteMessages,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xóa phía tôi'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runChatAction(
                    context,
                    (provider) => provider.deleteMessage(
                      message.conversationId,
                      message.id,
                      forEveryone: false,
                    ),
                  );
                },
              ),
            ),
            if (canRecall)
              PermissionGate(
                permission: AppPermission.deleteMessages,
                child: ListTile(
                  leading: const Icon(Icons.undo_outlined),
                  title: const Text('Thu hồi mọi người'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _runChatAction(
                      context,
                      (provider) => provider.deleteMessage(
                        message.conversationId,
                        message.id,
                        forEveryone: true,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showEditMessageDialog(
  BuildContext context,
  ChatMessage message,
) async {
  final controller = TextEditingController(text: message.content);
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sửa tin nhắn'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isEmpty) return;
              await context.read<ChatProvider>().editMessage(
                message.conversationId,
                message.id,
                content,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _MessageContent extends StatelessWidget {
  final ChatMessage message;
  final bool isOutgoing;
  final bool isDark;

  const _MessageContent({
    required this.message,
    required this.isOutgoing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final mediaPath = message.mediaUrl;
    final textColor = isOutgoing && hasPlainBubble(message)
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final textStyle = TextStyle(
      fontSize: 13,
      color: textColor,
      fontStyle: message.isRecalled ? FontStyle.italic : FontStyle.normal,
      fontWeight: isOutgoing ? FontWeight.w600 : FontWeight.normal,
    );

    if (message.isRecalled) {
      return Text('Tin nhắn đã bị thu hồi', style: textStyle);
    }

    final orderCard = message.messageType == 'TEXT'
        ? ChatRepairOrderCard.tryParse(message.content)
        : null;
    if (orderCard != null) {
      return RepairOrderMessageCard(card: orderCard, color: textColor);
    }

    if (isJumboEmoji(message)) {
      return Text(message.content.trim(), style: const TextStyle(fontSize: 42));
    }

    if (message.messageType == 'SYSTEM') {
      return Text(message.content, style: textStyle);
    }

    if (mediaPath == null || message.messageType == 'TEXT') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.content, style: textStyle),
          if (message.isEdited) ...[
            const SizedBox(height: 4),
            Text(
              'Đã sửa',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }

    final mediaUrl = context.read<ChatProvider>().mediaUrl(mediaPath);
    if (message.messageType == 'FILE' && isVoiceAttachment(mediaPath)) {
      return VoiceMessagePlayer(url: mediaUrl, color: textColor);
    }
    if (message.messageType == 'IMAGE' ||
        message.messageType == 'STICKER' ||
        message.messageType == 'GIF') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatMediaImage(
            imageUrl: mediaUrl,
            caption: message.content.isEmpty ? null : message.content,
            isSticker: message.messageType == 'STICKER',
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message.content, style: textStyle),
          ],
        ],
      );
    }

    if (message.messageType == 'VIDEO') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VideoMessageWidget(
            videoUrl: mediaUrl,
            senderName: message.sender.fullName,
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message.content, style: textStyle),
          ],
        ],
      );
    }

    final isVideo = message.messageType == 'VIDEO';
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo
                ? Icons.play_circle_outline
                : Icons.download_for_offline_outlined,
            color: textColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.content.isEmpty
                  ? (isVideo ? 'Mở video' : 'Mở tệp đính kèm')
                  : message.content,
              style: textStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  final ChatMessage message;

  const _ReactionPill({required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message.reactions
        .where((reaction) => reaction.emoji.isNotEmpty && reaction.count > 0)
        .map((reaction) => '${reaction.emoji} ${reaction.count}')
        .join('  ');
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceDark
            : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NewChatDialog extends StatefulWidget {
  final List<User> employees;
  final ValueChanged<ChatConversation> onChatCreated;

  const _NewChatDialog({required this.employees, required this.onChatCreated});

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  bool _isGroup = false;
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _loading = false;
  String _error = '';

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (_isGroup && name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên nhóm');
      return;
    }
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Vui lòng chọn ít nhất 1 thành viên');
      return;
    }
    if (_isGroup && _selectedIds.length < 2) {
      setState(() => _error = 'Nhóm cần ít nhất 2 thành viên khác');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      final type = _isGroup ? 'GROUP' : 'DIRECT';
      await chatProvider.createConversation(
        type,
        _isGroup ? name : '',
        _selectedIds.toList(),
      );

      // Find the created conversation in the provider
      final created = chatProvider.conversations.firstWhere(
        (c) =>
            c.type == type &&
            (_isGroup
                ? c.name == name
                : c.members.any((m) => _selectedIds.contains(m.userId))),
        orElse: () => chatProvider.conversations.first,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onChatCreated(created);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Lỗi tạo cuộc hội thoại: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Tạo cuộc trò chuyện',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Trực tiếp'),
                    selected: !_isGroup,
                    onSelected: (val) {
                      setState(() {
                        _isGroup = false;
                        _selectedIds.clear();
                        _error = '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Nhóm'),
                    selected: _isGroup,
                    onSelected: (val) {
                      setState(() {
                        _isGroup = true;
                        _selectedIds.clear();
                        _error = '';
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isGroup) ...[
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Tên nhóm',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  hintText: 'Nhập tên nhóm chat...',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Chọn thành viên:',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: widget.employees.isEmpty
                  ? Center(
                      child: Text(
                        'Không có nhân viên nào khác',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.employees.length,
                      itemBuilder: (context, index) {
                        final emp = widget.employees[index];
                        final isSelected = _selectedIds.contains(emp.id);

                        return CheckboxListTile(
                          title: Text(
                            emp.name,
                            style: TextStyle(color: textColor, fontSize: 13),
                          ),
                          subtitle: Text(
                            emp.department ?? emp.username,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          value: isSelected,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() {
                              if (_isGroup) {
                                if (val == true) {
                                  _selectedIds.add(emp.id);
                                } else {
                                  _selectedIds.remove(emp.id);
                                }
                              } else {
                                _selectedIds.clear();
                                if (val == true) {
                                  _selectedIds.add(emp.id);
                                }
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Tạo'),
        ),
      ],
    );
  }
}

class _ChatDetailInfoPage extends StatefulWidget {
  final ChatConversation conversation;
  final bool isDark;
  final Future<void> Function() onMuteToggle;
  final VoidCallback onSearch;
  final VoidCallback onGallery;

  const _ChatDetailInfoPage({
    required this.conversation,
    required this.isDark,
    required this.onMuteToggle,
    required this.onSearch,
    required this.onGallery,
  });

  @override
  State<_ChatDetailInfoPage> createState() => _ChatDetailInfoPageState();
}

class _ChatDetailInfoPageState extends State<_ChatDetailInfoPage> {
  bool _busy = false;
  ChatConversation get conversation => widget.conversation;
  bool get isDark => widget.isDark;
  VoidCallback get onSearch => widget.onSearch;
  VoidCallback get onGallery => widget.onGallery;
  Future<void> Function() get onMuteToggle => widget.onMuteToggle;

  Future<bool> _perform(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Không thể thực hiện thao tác. Vui lòng thử lại.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _addMembers(ChatConversation conversation) async {
    final backend = context.read<BackendDataProvider>();
    if (!await _perform(() => backend.loadEmployees(notify: false)) ||
        !mounted) {
      return;
    }
    final ids = conversation.members.map((m) => m.userId).toSet();
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => AddMembersDialog(
        employees: backend.employees
            .where(
              (user) =>
                  !ids.contains(user.id) && user.status == UserStatus.active,
            )
            .toList(),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _perform(
      () => context.read<ChatProvider>().addMembers(conversation.id, selected),
    );
  }

  Future<void> _leaveGroup(ChatConversation conversation) async {
    if (!await _confirm(
          'Rời khỏi nhóm?',
          'Bạn sẽ không còn nhận tin nhắn từ ${conversation.name}.',
          'Rời nhóm',
        ) ||
        !mounted) {
      return;
    }
    final success = await _perform(
      () => context.read<ChatProvider>().leaveConversation(conversation.id),
    );
    if (success && mounted) Navigator.pop(context);
  }

  Future<void> _manageMember(
    ChatConversation conversation,
    ConversationMemberInfo member,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                member.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PermissionGate(
              permission: AppPermission.updateConversationMemberRole,
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  member.isAdmin
                      ? 'Bỏ quyền quản trị viên'
                      : 'Đặt làm quản trị viên',
                ),
                onTap: () => Navigator.pop(sheetContext, 'role'),
              ),
            ),
            PermissionGate(
              permission: AppPermission.removeConversationMembers,
              child: ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: const Text('Xóa khỏi nhóm'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final label = action == 'remove'
        ? 'Xóa khỏi nhóm'
        : member.isAdmin
        ? 'Bỏ quyền quản trị viên'
        : 'Đặt làm quản trị viên';
    if (!await _confirm(
          '$label?',
          'Áp dụng cho ${member.fullName}.',
          'Xác nhận',
        ) ||
        !mounted) {
      return;
    }
    await _perform(
      () => action == 'remove'
          ? context.read<ChatProvider>().removeMember(
              conversation.id,
              member.userId,
            )
          : context.read<ChatProvider>().updateMemberRole(
              conversation.id,
              member.userId,
              member.isAdmin ? 'MEMBER' : 'ADMIN',
            ),
    );
  }

  String get _avatarText {
    if (conversation.name.isEmpty) return '??';
    final parts = conversation.name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0])
          .toUpperCase();
    }
    return conversation.name[0].toUpperCase();
  }

  Color get _avatarColor {
    final hash = conversation.name.hashCode;
    final index = hash.abs() % Colors.primaries.length;
    return Colors.primaries[index];
  }

  @override
  Widget build(BuildContext context) {
    final conversation =
        context
            .watch<ChatProvider>()
            .conversations
            .where((item) => item.id == this.conversation.id)
            .firstOrNull ??
        this.conversation;
    final textPrimaryColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;

    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final canManage = conversation.members.any(
      (m) => m.userId == currentUserId && (m.isAdmin || m.role == 'ADMIN'),
    );

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: AppBackButton(
              isDark: isDark,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          'Chi tiết cuộc trò chuyện',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _avatarColor,
                shape: BoxShape.circle,
              ),
              child: conversation.type == 'GROUP'
                  ? const Icon(
                      LucideIcons.usersRound,
                      color: Colors.white,
                      size: 44,
                    )
                  : Center(
                      child: Text(
                        _avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                conversation.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conversation.type == 'GROUP'
                  ? '${conversation.members.length} thành viên'
                  : 'Đang hoạt động',
              style: TextStyle(fontSize: 13, color: textSecondaryColor),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('File phương tiện & tài liệu'),
            _buildMenuItem(
              icon: Icons.image_outlined,
              iconColor: Colors.green,
              title: 'Ảnh, file & liên kết',
              onTap: onGallery,
            ),
            _buildSectionHeader('Cài đặt cuộc trò chuyện'),
            _buildMenuItem(
              icon: Icons.search,
              iconColor: Colors.blue,
              title: 'Tìm kiếm trong cuộc trò chuyện',
              onTap: onSearch,
            ),
            PermissionGate(
              permission: AppPermission.muteConversations,
              child: _buildMenuItem(
                icon: conversation.notificationsMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_none_outlined,
                iconColor: Colors.orange,
                title: conversation.notificationsMuted
                    ? 'Bật thông báo'
                    : 'Tắt thông báo',
                onTap: () async {
                  await onMuteToggle();
                },
              ),
            ),
            if (conversation.type == 'GROUP') ...[
              _buildSectionHeader('Thành viên nhóm'),
              if (canManage)
                PermissionGate(
                  permission: AppPermission.addConversationMembers,
                  child: _buildMenuItem(
                    icon: Icons.person_add_outlined,
                    iconColor: AppColors.primary,
                    title: 'Thêm thành viên',
                    onTap: () => _addMembers(conversation),
                  ),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: conversation.members.length,
                itemBuilder: (context, index) {
                  final member = conversation.members[index];
                  final memberAvatarText = member.fullName.isEmpty
                      ? '?'
                      : member.fullName.trim().split(' ').last[0].toUpperCase();
                  final memberHash = member.fullName.hashCode;
                  final memberColor = Colors
                      .primaries[memberHash.abs() % Colors.primaries.length];

                  return ListTile(
                    trailing:
                        canManage &&
                            context.watch<AuthProvider>().canAny([
                              AppPermission.updateConversationMemberRole,
                              AppPermission.removeConversationMembers,
                            ]) &&
                            member.userId != currentUserId
                        ? IconButton(
                            icon: const Icon(Icons.manage_accounts_outlined),
                            tooltip: 'Quản lý ${member.fullName}',
                            onPressed: _busy
                                ? null
                                : () => _manageMember(conversation, member),
                          )
                        : null,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: memberColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          memberAvatarText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      member.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    subtitle: Text(
                      member.isAdmin ? 'Quản trị viên' : 'Thành viên',
                      style: TextStyle(fontSize: 12, color: textSecondaryColor),
                    ),
                  );
                },
              ),
            ],
            _buildSectionHeader('Quyền riêng tư & hỗ trợ'),
            _buildMenuItem(
              icon: Icons.error_outline,
              iconColor: Colors.redAccent,
              title: 'Báo cáo sự cố',
              onTap: () {},
            ),
            if (conversation.type == 'GROUP')
              PermissionGate(
                permission: AppPermission.leaveConversations,
                child: _buildMenuItem(
                  icon: conversation.type == 'GROUP'
                      ? Icons.logout
                      : Icons.block,
                  iconColor: Colors.red,
                  title: conversation.type == 'GROUP'
                      ? 'Rời khỏi nhóm'
                      : 'Chặn người dùng',
                  onTap: () => _leaveGroup(conversation),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ],
      ),
      onTap: _busy ? null : onTap,
    );
  }
}

class _VideoMessageWidget extends StatefulWidget {
  final String videoUrl;
  final String senderName;

  const _VideoMessageWidget({required this.videoUrl, required this.senderName});

  @override
  State<_VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<_VideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
            httpHeaders: mediaAuthHeaders(context, widget.videoUrl),
          )
          ..initialize()
              .then((_) {
                if (mounted) {
                  setState(() {
                    _initialized = true;
                  });
                }
              })
              .catchError((error) {
                debugPrint('Error initializing video player: $error');
                if (mounted) {
                  setState(() {
                    _hasError = true;
                  });
                }
              });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return Container(
        width: 220,
        height: 150,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
              SizedBox(height: 8),
              Text(
                'Lỗi tải video',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        width: 220,
        height: 150,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => VideoPlayerDialog(
              videoUrl: widget.videoUrl,
              title: 'Video',
              senderName: widget.senderName,
            ),
          );
        },
        child: Container(
          width: 220,
          height: 150,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
              // Play Button Overlay
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyPreviewWidget extends StatelessWidget {
  final ParentMessageInfo parentMessage;
  final bool isOutgoing;
  final bool isDark;

  const _ReplyPreviewWidget({
    required this.parentMessage,
    required this.isOutgoing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = isOutgoing ? Colors.white70 : AppColors.primary;
    final senderColor = isOutgoing ? Colors.white : AppColors.primary;
    final textColor = isOutgoing
        ? Colors.white.withValues(alpha: 0.9)
        : (isDark ? Colors.white70 : Colors.black87);

    String displayContent = parentMessage.isRecalled
        ? 'Tin nhắn đã bị thu hồi'
        : parentMessage.content;
    if (!parentMessage.isRecalled && displayContent.isEmpty) {
      if (parentMessage.messageType == 'IMAGE') {
        displayContent = 'Đã gửi một hình ảnh';
      } else if (parentMessage.messageType == 'VIDEO') {
        displayContent = 'Đã gửi một video';
      } else if (parentMessage.messageType == 'FILE') {
        displayContent = 'Đã gửi một tệp đính kèm';
      } else {
        displayContent = 'Tin nhắn đính kèm';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutgoing
            ? Colors.black.withValues(alpha: 0.1)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, color: barColor),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    parentMessage.senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: senderColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayContent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor,
                      fontStyle: parentMessage.isRecalled
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
