import 'package:intl/intl.dart';

class AppNotification {
  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String body;
  final String? refType;
  final String? refId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    this.refType,
    this.refId,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      refType: json['refType']?.toString(),
      refId: json['refId']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      refType: refType,
      refId: refId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get relativeTime {
    final value = createdAt;
    if (value == null) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Vua xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phut truoc';
    if (diff.inDays < 1) return '${diff.inHours} gio truoc';
    if (diff.inDays == 1) return 'Hom qua';
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }
}
