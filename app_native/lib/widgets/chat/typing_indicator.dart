import 'dart:math' as math;
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.names});
  final List<String> names;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final label = names.length <= 2
        ? names.join(', ')
        : '${names.first} và ${names.length - 1} người khác';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        children: [
          ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (_, _) => Row(
                children: List.generate(
                  3,
                  (i) => Transform.translate(
                    offset: Offset(
                      0,
                      -3 *
                          math.max(
                            0,
                            math.sin(_animation.value * 2 * math.pi - i * .7),
                          ),
                    ),
                    child: Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label đang soạn tin...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
