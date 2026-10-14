import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/chat_message.dart';
import 'package:system_inverter_likenew/widgets/chat/message_presentation.dart';

ChatMessage message({
  String content = '',
  String type = 'TEXT',
  String sender = 'a',
  String conversation = 'c',
  DateTime? at,
  bool recalled = false,
}) => ChatMessage(
  id: 'm',
  conversationId: conversation,
  sender: SenderInfo(userId: sender, fullName: sender),
  content: content,
  messageType: type,
  sentAt: at ?? DateTime(2026, 10, 13, 12),
  deletedForEveryoneAt: recalled ? DateTime(2026) : null,
  readByUserIds: const [],
);

void main() {
  test('jumbo emoji counts complete emoji graphemes and rejects plaintext', () {
    for (final content in [
      '👍',
      '👍🏽',
      '❤️',
      '👨‍👩‍👧‍👦',
      '🇻🇳',
      '1️⃣',
      '#️⃣',
      '😀❤️👍🏽',
      '  😀  ',
    ]) {
      expect(isJumboEmoji(message(content: content)), isTrue, reason: content);
    }
    for (final content in [
      '',
      '1',
      '123',
      '#',
      'hello 😀',
      '😀a',
      '😀😀😀😀',
      '🏽',
      '\uFE0F',
      '🇻',
      'a\uFE0F',
      '☖',
    ]) {
      expect(isJumboEmoji(message(content: content)), isFalse, reason: content);
    }
    expect(isJumboEmoji(message(content: '😀', recalled: true)), isFalse);
    expect(isJumboEmoji(message(content: '😀', type: 'IMAGE')), isFalse);
  });

  test('only media and jumbo emoji omit plain bubbles', () {
    for (final type in ['IMAGE', 'STICKER', 'GIF', 'VIDEO']) {
      expect(hasPlainBubble(message(type: type)), isFalse);
      expect(hasPlainBubble(message(type: type, recalled: true)), isTrue);
    }
    expect(hasPlainBubble(message(content: '❤️')), isFalse);
    expect(hasPlainBubble(message(content: 'Hello')), isTrue);
    expect(hasPlainBubble(message(type: 'FILE')), isTrue);
  });

  test('groups only same sender conversation day within sixty seconds', () {
    final first = message();
    expect(
      messagesBelongToSameGroup(
        first,
        message(at: DateTime(2026, 10, 13, 12, 1)),
      ),
      isTrue,
    );
    expect(
      messagesBelongToSameGroup(
        message(at: DateTime(2026, 10, 13, 12, 1)),
        first,
      ),
      isTrue,
    );
    expect(
      messagesBelongToSameGroup(
        first,
        message(at: DateTime(2026, 10, 13, 12, 1, 0, 1)),
      ),
      isFalse,
    );
    expect(messagesBelongToSameGroup(first, message(sender: 'b')), isFalse);
    expect(
      messagesBelongToSameGroup(first, message(conversation: 'other')),
      isFalse,
    );
    expect(messagesBelongToSameGroup(first, message(type: 'SYSTEM')), isFalse);
    expect(messagesBelongToSameGroup(message(type: 'SYSTEM'), first), isFalse);
    expect(messagesBelongToSameGroup(first, message(recalled: true)), isFalse);
    expect(messagesBelongToSameGroup(message(recalled: true), first), isFalse);
    expect(
      messagesBelongToSameGroup(
        message(at: DateTime(2026, 10, 13, 23, 59, 40)),
        message(at: DateTime(2026, 10, 14)),
      ),
      isFalse,
    );
  });
}
