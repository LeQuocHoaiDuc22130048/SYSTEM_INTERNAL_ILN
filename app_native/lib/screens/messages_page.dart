import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../utils/chat_provider.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
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

      return _ChatDetailPage(
        conversation: currentConv,
        isDark: isDark,
        onBack: () {
          chatProvider.clearActiveChat();
        },
      );
    }

    return _ConversationListPage(
      isDark: isDark,
      onSelect: (conversation) {
        chatProvider.loadMessages(conversation.id);
      },
    );
  }
}

class _ConversationListPage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<ChatConversation> onSelect;

  const _ConversationListPage({required this.isDark, required this.onSelect});

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
                  IconButton(
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
            Divider(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            Expanded(
              child: chatProvider.isLoadingConversations
                  ? const Center(child: CircularProgressIndicator())
                  : filteredConversations.isEmpty
                  ? Center(
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
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filteredConversations.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 78,
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                      itemBuilder: (context, index) {
                        final conversation = filteredConversations[index];
                        return _ConversationTile(
                          conversation: conversation,
                          isDark: isDark,
                          onTap: () => widget.onSelect(conversation),
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

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.onTap,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 12, 30, 12),
        child: Row(
          children: [
            Container(
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
                  Text(
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

class _ChatDetailPage extends StatefulWidget {
  final ChatConversation conversation;
  final bool isDark;
  final VoidCallback onBack;

  const _ChatDetailPage({
    required this.conversation,
    required this.isDark,
    required this.onBack,
  });

  @override
  State<_ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<_ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().clearActiveChat();
    });
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(widget.conversation.id, text);
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) {
      await _uploadMedia(await file.readAsBytes(), file.name, 'IMAGE');
    }
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      await _uploadMedia(await file.readAsBytes(), file.name, 'VIDEO');
    }
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
      await context.read<ChatProvider>().sendMediaMessage(
        widget.conversation.id,
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
        messageType: type,
        content: caption,
      );
      if (caption.isNotEmpty) {
        _controller.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Khong the gui tep: $error')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_file_outlined),
              title: const Text('Gui video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Dinh kem tep'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
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
                  IconButton(
                    onPressed: widget.onBack,
                    icon: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Container(
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.name,
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
                ],
              ),
            ),
            Expanded(
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
                      controller: _scrollController,
                      reverse: true, // Auto-scrolls to bottom
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      itemCount: chatProvider.activeMessages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.activeMessages[index];
                        final isMe = message.sender.userId == currentUser?.id;

                        if (isMe) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OutgoingMessage(
                              message: message,
                              isDark: widget.isDark,
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _IncomingMessage(
                            message: message,
                            isDark: widget.isDark,
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
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
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading ? null : _showAttachmentOptions,
                    icon: const Icon(LucideIcons.paperclip, size: 19),
                    color: AppColors.textSecondaryLight,
                  ),
                  IconButton(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(LucideIcons.image, size: 18),
                    color: AppColors.textSecondaryLight,
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _handleSend(),
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          filled: true,
                          fillColor: widget.isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: widget.isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: widget.isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _isUploading ? null : _handleSend,
                    borderRadius: BorderRadius.circular(19),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              LucideIcons.send,
                              size: 18,
                              color: Colors.white,
                            ),
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

class _IncomingMessage extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _IncomingMessage({required this.message, required this.isDark});

  String get _avatarText {
    final name = message.sender.fullName;
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0])
          .toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color get _avatarColor {
    final hash = message.sender.fullName.hashCode;
    final index = hash.abs() % Colors.primaries.length;
    return Colors.primaries[index];
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.sentAt.toLocal());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: _avatarColor,
          child: Text(
            _avatarText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  message.sender.fullName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: _MessageContent(
                  message: message,
                  isOutgoing: false,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OutgoingMessage extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _OutgoingMessage({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.sentAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _MessageContent(
            message: message,
            isOutgoing: true,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$timeStr ✓✓',
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
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
    final textColor = isOutgoing
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final textStyle = TextStyle(
      fontSize: 13,
      color: textColor,
      fontWeight: isOutgoing ? FontWeight.w600 : FontWeight.normal,
    );

    if (mediaPath == null || message.messageType == 'TEXT') {
      return Text(message.content, style: textStyle);
    }

    final mediaUrl = context.read<ChatProvider>().mediaUrl(mediaPath);
    if (message.messageType == 'IMAGE') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              mediaUrl,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 220,
                height: 100,
                child: Center(child: Icon(Icons.image_not_supported_outlined)),
              ),
            ),
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
                  ? (isVideo ? 'Mo video' : 'Mo tep dinh kem')
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
