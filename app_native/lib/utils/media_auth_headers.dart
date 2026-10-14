import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

Map<String, String> mediaAuthHeaders(BuildContext context, String url) =>
    context.read<AuthProvider?>()?.api.mediaHeadersFor(url) ?? const {};
