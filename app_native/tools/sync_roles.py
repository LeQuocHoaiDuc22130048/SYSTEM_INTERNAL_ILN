import os
import re

# File paths
script_dir = os.path.dirname(os.path.abspath(__file__))
java_file_path = os.path.abspath(os.path.join(script_dir, '../../backend/src/main/java/com/suachuabientan/system_internal/modules/auth/enums/UserRole.java'))
dart_file_path = os.path.abspath(os.path.join(script_dir, '../lib/models/user.dart'))

# Label and color mappings for known roles
ROLE_LABELS = {
    'SUPER_ADMIN': 'Super Admin',
    'ADMIN': 'Admin',
    'MANAGER': 'Quản lý',
    'TECHNICIAN': 'Kỹ thuật viên',
    'WAREHOUSE': 'Thủ kho',
    'EMPLOYEE': 'Nhân viên',
}

ROLE_COLORS = {
    'SUPER_ADMIN': 'AppColors.purple',
    'ADMIN': 'AppColors.primary',
    'MANAGER': 'const Color(0xFF6366F1)', # indigo
    'TECHNICIAN': 'const Color(0xFF0D9488)', # teal
    'WAREHOUSE': 'const Color(0xFFD97706)', # amber/orange
    'EMPLOYEE': 'AppColors.success',
}

def to_camel_case(snake_str):
    components = snake_str.split('_')
    # We want camelCase: first component lowercase, rest capitalized
    if components[0] == 'SUPER' and len(components) > 1 and components[1] == 'ADMIN':
        return 'superAdmin'
    return components[0].lower() + ''.join(x.title() for x in components[1:])

def main():
    print(f"Reading Backend roles from: {java_file_path}")
    if not os.path.exists(java_file_path):
        print(f"Error: Backend role file not found at {java_file_path}")
        return

    with open(java_file_path, 'r', encoding='utf-8') as f:
        java_content = f.read()

    # Find the enum declaration block
    enum_match = re.search(r'public enum UserRole\s*\{([^}]+)\}', java_content)
    if not enum_match:
        print("Error: Could not parse UserRole enum from Java file.")
        return

    enum_body = enum_match.group(1)
    # Extract enum constants (comma separated, ignoring comments and annotations)
    # Strip comments first
    enum_body_clean = re.sub(r'//.*', '', enum_body)
    enum_body_clean = re.sub(r'/\*.*?\*/', '', enum_body_clean, flags=re.DOTALL)
    
    raw_constants = [x.strip() for x in enum_body_clean.split(',')]
    java_roles = [x for x in raw_constants if x and re.match(r'^[A-Z_]+$', x)]

    if not java_roles:
        print("Error: No role constants found.")
        return

    print(f"Found roles: {java_roles}")

    # Generate Dart code segments
    # 1. Enum declaration
    dart_enum_members = []
    for role in java_roles:
        dart_enum_members.append(to_camel_case(role))
    
    dart_enum_code = f"enum UserRole {{ {', '.join(dart_enum_members)} }}"

    # 2. roleLabel mapping (in User class)
    dart_role_label_code = "  String get roleLabel => role.label;"

    # 2b. label getter (in UserRolePermissions)
    role_label_getter_lines = ["  String get label {", "    switch (this) {"]
    for role in java_roles:
        camel = to_camel_case(role)
        label = ROLE_LABELS.get(role, role.replace('_', ' ').title())
        role_label_getter_lines.append(f"      case UserRole.{camel}:")
        role_label_getter_lines.append(f"        return '{label}';")
    role_label_getter_lines.extend(["    }", "  }"])
    dart_role_label_getter_code = "\n".join(role_label_getter_lines)

    # 3. roleFromBackend mapping
    role_from_backend_lines = [
        "  static UserRole roleFromBackend(String? role) {",
        "    switch (role) {"
    ]
    # We map explicit ones, and fallback to the last one (usually EMPLOYEE)
    default_role = 'EMPLOYEE' if 'EMPLOYEE' in java_roles else java_roles[-1]
    default_camel = to_camel_case(default_role)
    for role in java_roles:
        if role == default_role:
            continue
        camel = to_camel_case(role)
        role_from_backend_lines.append(f"      case '{role}':")
        role_from_backend_lines.append(f"        return UserRole.{camel};")
    role_from_backend_lines.extend([
        "      default:",
        f"        return UserRole.{default_camel};",
        "    }",
        "  }"
    ])
    dart_role_from_backend_code = "\n".join(role_from_backend_lines)

    # 4. backendCode getter
    backend_code_lines = [
        "  String get backendCode {",
        "    switch (this) {"
    ]
    for role in java_roles:
        camel = to_camel_case(role)
        backend_code_lines.append(f"      case UserRole.{camel}:")
        backend_code_lines.append(f"        return '{role}';")
    backend_code_lines.extend(["    }", "  }"])
    dart_backend_code = "\n".join(backend_code_lines)

    # 5. avatarColor getter
    avatar_color_lines = [
        "  Color get avatarColor {",
        "    switch (this) {"
    ]
    for role in java_roles:
        camel = to_camel_case(role)
        color = ROLE_COLORS.get(role, 'AppColors.success')
        avatar_color_lines.append(f"      case UserRole.{camel}:")
        avatar_color_lines.append(f"        return {color};")
    avatar_color_lines.extend(["    }", "  }"])
    dart_avatar_color_code = "\n".join(avatar_color_lines)

    # 6. permissions switch
    permissions_switch_lines = [
        "    switch (this) {",
        "      case UserRole.superAdmin:",
        "        return AppPermission.values.toSet();",
        "      case UserRole.admin:",
        "        return adminPermissions;",
        "      case UserRole.manager:",
        "        return managerPermissions;"
    ]
    other_roles = [r for r in java_roles if r not in ('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'EMPLOYEE')]
    for r in other_roles:
        permissions_switch_lines.append(f"      case UserRole.{to_camel_case(r)}:")
    permissions_switch_lines.extend([
        "      case UserRole.employee:",
        "        return employeePermissions;",
        "    }"
    ])
    dart_permissions_switch_code = "\n".join(permissions_switch_lines)

    print(f"Reading Frontend user.dart from: {dart_file_path}")
    if not os.path.exists(dart_file_path):
        print(f"Error: Frontend file not found at {dart_file_path}")
        return

    with open(dart_file_path, 'r', encoding='utf-8') as f:
        dart_content = f.read()

    # Replace blocks
    def replace_block(content, start_marker, end_marker, replacement):
        pattern = re.escape(start_marker) + r'.*?' + re.escape(end_marker)
        replacement_with_markers = f"{start_marker}\n{replacement}\n{end_marker}"
        new_content, count = re.subn(pattern, replacement_with_markers, content, flags=re.DOTALL)
        if count == 0:
            print(f"Warning: Marker block not found: {start_marker} ... {end_marker}")
        return new_content

    dart_content = replace_block(dart_content, '// {{START_USER_ROLE_ENUM}}', '// {{END_USER_ROLE_ENUM}}', dart_enum_code)
    dart_content = replace_block(dart_content, '  // {{START_ROLE_LABEL}}', '  // {{END_ROLE_LABEL}}', dart_role_label_code)
    dart_content = replace_block(dart_content, '  // {{START_ROLE_LABEL_GETTER}}', '  // {{END_ROLE_LABEL_GETTER}}', dart_role_label_getter_code)
    dart_content = replace_block(dart_content, '  // {{START_ROLE_FROM_BACKEND}}', '  // {{END_ROLE_FROM_BACKEND}}', dart_role_from_backend_code)
    dart_content = replace_block(dart_content, '  // {{START_ROLE_BACKEND_CODE}}', '  // {{END_ROLE_BACKEND_CODE}}', dart_backend_code)
    dart_content = replace_block(dart_content, '  // {{START_ROLE_AVATAR_COLOR}}', '  // {{END_ROLE_AVATAR_COLOR}}', dart_avatar_color_code)
    dart_content = replace_block(dart_content, '    // {{START_ROLE_PERMISSIONS_SWITCH}}', '    // {{END_ROLE_PERMISSIONS_SWITCH}}', dart_permissions_switch_code)

    with open(dart_file_path, 'w', encoding='utf-8') as f:
        f.write(dart_content)

    print("Role synchronization complete! Code updated successfully.")

if __name__ == '__main__':
    main()
