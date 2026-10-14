import 'package:flutter/widgets.dart' show StringCharacters;
import '../../models/chat_message.dart';

/// Emoji size follows visible graphemes, so families and flags count once.
bool isJumboEmoji(ChatMessage message) {
  if (message.isRecalled || message.messageType != 'TEXT') return false;
  final clusters = message.content.trim().characters.toList();
  return clusters.isNotEmpty &&
      clusters.length <= 3 &&
      clusters.every(_isEmojiCluster);
}

bool hasPlainBubble(ChatMessage message) =>
    message.isRecalled ||
    (!const {
          'IMAGE',
          'STICKER',
          'GIF',
          'VIDEO',
        }.contains(message.messageType) &&
        !isJumboEmoji(message));

bool messagesBelongToSameGroup(ChatMessage first, ChatMessage second) {
  if (first.sender.userId != second.sender.userId ||
      first.conversationId != second.conversationId ||
      first.messageType == 'SYSTEM' ||
      second.messageType == 'SYSTEM' ||
      first.isRecalled ||
      second.isRecalled) {
    return false;
  }
  final firstTime = first.sentAt.toLocal();
  final secondTime = second.sentAt.toLocal();
  return firstTime.year == secondTime.year &&
      firstTime.month == secondTime.month &&
      firstTime.day == secondTime.day &&
      firstTime.difference(secondTime).abs() <= const Duration(minutes: 1);
}

bool _isEmojiCluster(String cluster) {
  final codes = cluster.runes.toList();
  // A digit is emoji only as a complete keycap sequence.
  if (codes.last == 0x20E3) {
    return (codes.length == 2 || (codes.length == 3 && codes[1] == 0xFE0F)) &&
        (codes.first == 0x23 ||
            codes.first == 0x2A ||
            (codes.first >= 0x30 && codes.first <= 0x39));
  }
  if (_isRegionalIndicator(codes.first)) {
    return codes.length == 2 && _isRegionalIndicator(codes.last);
  }
  var index = 0;
  while (index < codes.length) {
    if (!_isEmojiBase(codes[index++])) return false;
    if (index < codes.length && codes[index] == 0xFE0F) index++;
    if (index < codes.length &&
        codes[index] >= 0x1F3FB &&
        codes[index] <= 0x1F3FF) {
      index++;
    }
    if (index == codes.length) return true;
    // Subdivision flags use a black flag followed by tag letters and a cancel tag.
    if (codes.first == 0x1F3F4 &&
        codes[index] >= 0xE0061 &&
        codes[index] <= 0xE007A) {
      return codes.last == 0xE007F &&
          codes
              .sublist(index, codes.length - 1)
              .every((code) => code >= 0xE0061 && code <= 0xE007A);
    }
    if (codes[index++] != 0x200D || index == codes.length) return false;
  }
  return false;
}

bool _isRegionalIndicator(int code) => code >= 0x1F1E6 && code <= 0x1F1FF;

bool _isEmojiBase(int code) {
  if (code >= 0x1F3FB && code <= 0x1F3FF) return false;
  if ((code >= 0x1F300 && code <= 0x1F6FF) ||
      (code >= 0x1F900 && code <= 0x1FAFF) ||
      (code >= 0x1F7E0 && code <= 0x1F7EB)) {
    return true;
  }
  return _emojiSymbols.contains(code) ||
      (code >= 0x2194 && code <= 0x2199) ||
      (code >= 0x23E9 && code <= 0x23F3) ||
      (code >= 0x23F8 && code <= 0x23FA) ||
      (code >= 0x2648 && code <= 0x2653) ||
      (code >= 0x2614 && code <= 0x2615) ||
      (code >= 0x26AA && code <= 0x26AB) ||
      (code >= 0x26BD && code <= 0x26BE) ||
      (code >= 0x2708 && code <= 0x270D) ||
      (code >= 0x2753 && code <= 0x2755) ||
      (code >= 0x2795 && code <= 0x2797) ||
      (code >= 0x2B05 && code <= 0x2B07);
}

const _emojiSymbols = <int>{
  0xA9,
  0xAE,
  0x203C,
  0x2049,
  0x2122,
  0x2139,
  0x21A9,
  0x21AA,
  0x231A,
  0x231B,
  0x2328,
  0x23CF,
  0x24C2,
  0x25AA,
  0x25AB,
  0x25B6,
  0x25C0,
  0x25FB,
  0x25FC,
  0x25FD,
  0x25FE,
  0x2600,
  0x2601,
  0x2602,
  0x2603,
  0x2604,
  0x260E,
  0x2611,
  0x2618,
  0x261D,
  0x2620,
  0x2622,
  0x2623,
  0x2626,
  0x262A,
  0x262E,
  0x262F,
  0x2638,
  0x2639,
  0x263A,
  0x2640,
  0x2642,
  0x265F,
  0x2660,
  0x2663,
  0x2665,
  0x2666,
  0x2668,
  0x267B,
  0x267E,
  0x267F,
  0x2692,
  0x2693,
  0x2694,
  0x2695,
  0x2696,
  0x2697,
  0x2699,
  0x269B,
  0x269C,
  0x26A0,
  0x26A1,
  0x26A7,
  0x26B0,
  0x26B1,
  0x26C4,
  0x26C5,
  0x26C8,
  0x26CE,
  0x26CF,
  0x26D1,
  0x26D3,
  0x26D4,
  0x26E9,
  0x26EA,
  0x26F0,
  0x26F1,
  0x26F2,
  0x26F3,
  0x26F4,
  0x26F5,
  0x26F7,
  0x26F8,
  0x26F9,
  0x26FA,
  0x26FD,
  0x2702,
  0x2705,
  0x270F,
  0x2712,
  0x2714,
  0x2716,
  0x271D,
  0x2721,
  0x2728,
  0x2733,
  0x2734,
  0x2744,
  0x2747,
  0x274C,
  0x274E,
  0x2757,
  0x2763,
  0x2764,
  0x27A1,
  0x27B0,
  0x27BF,
  0x2934,
  0x2935,
  0x2B1B,
  0x2B1C,
  0x2B50,
  0x2B55,
  0x3030,
  0x303D,
  0x3297,
  0x3299,
  0x1F004,
  0x1F0CF,
  0x1F170,
  0x1F171,
  0x1F17E,
  0x1F17F,
  0x1F18E,
  0x1F191,
  0x1F192,
  0x1F193,
  0x1F194,
  0x1F195,
  0x1F196,
  0x1F197,
  0x1F198,
  0x1F199,
  0x1F19A,
  0x1F201,
  0x1F202,
  0x1F21A,
  0x1F22F,
  0x1F232,
  0x1F233,
  0x1F234,
  0x1F235,
  0x1F236,
  0x1F237,
  0x1F238,
  0x1F239,
  0x1F23A,
  0x1F250,
  0x1F251,
  0x1F7F0,
};
