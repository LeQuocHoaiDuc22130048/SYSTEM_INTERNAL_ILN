import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_permission.dart';
import '../utils/auth_provider.dart';

/// Unauthorized actions are absent from the widget and semantics trees.
class PermissionGate extends StatelessWidget {
  final List<AppPermission> permissions;
  final Widget child;

  const PermissionGate({
    super.key,
    required AppPermission permission,
    required this.child,
  }) : permissions = const [],
       _permission = permission;

  const PermissionGate.any({
    super.key,
    required this.permissions,
    required this.child,
  }) : _permission = null;

  final AppPermission? _permission;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allowed = _permission == null
        ? auth.canAny(permissions)
        : auth.can(_permission);
    return allowed ? child : const SizedBox.shrink();
  }
}
