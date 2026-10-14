import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/auth_provider.dart';

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final user = auth?.currentUser;
    final color = selected ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    final words = (user?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? 'U'
        : '${words.first.characters.first}${words.length > 1 ? words.last.characters.first : ''}'
              .toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final raw = user?.avatar;
    final url = raw == null || raw.isEmpty
        ? null
        : raw.startsWith('http')
        ? raw
        : '${auth!.api.activeBaseUrl.replaceAll(RegExp(r'/+$'), '')}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
    return Container(
      key: const ValueKey('bottom-account-avatar'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : color.withValues(alpha: .14),
        border: Border.all(color: color, width: selected ? 2 : 1),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
