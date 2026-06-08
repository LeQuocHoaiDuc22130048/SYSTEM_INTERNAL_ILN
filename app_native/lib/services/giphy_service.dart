import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _giphyApiKey = String.fromEnvironment('GIPHY_API_KEY');

class GiphyItem {
  final String id;
  final String title;
  final String previewUrl;
  final String mediaUrl;

  const GiphyItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.mediaUrl,
  });

  factory GiphyItem.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final preview = _imageUrl(images, 'fixed_width_small') ??
        _imageUrl(images, 'fixed_height_small') ??
        _imageUrl(images, 'downsized') ??
        _imageUrl(images, 'original') ??
        '';
    final media = _imageUrl(images, 'downsized_medium') ??
        _imageUrl(images, 'fixed_height') ??
        _imageUrl(images, 'original') ??
        preview;

    return GiphyItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      previewUrl: preview,
      mediaUrl: media,
    );
  }

  static String? _imageUrl(Map<String, dynamic> images, String key) {
    final value = images[key];
    if (value is Map<String, dynamic>) {
      final url = value['url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }
}

class GiphyService {
  static bool get hasApiKey => _giphyApiKey.isNotEmpty;

  Future<List<GiphyItem>> search({
    required String query,
    required String type,
    int limit = 24,
  }) async {
    if (!hasApiKey) {
      throw const GiphyMissingApiKeyException();
    }

    final endpoint = type == 'STICKER' ? 'stickers' : 'gifs';
    final uri = Uri.https('api.giphy.com', '/v1/$endpoint/search', {
      'api_key': _giphyApiKey,
      'q': query,
      'limit': limit.toString(),
      'rating': 'g',
      'lang': 'vi',
      'bundle': 'messaging_non_clips',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GiphyException('Giphy search failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(GiphyItem.fromJson)
        .where((item) => item.previewUrl.isNotEmpty && item.mediaUrl.isNotEmpty)
        .toList();
  }
}

class GiphyException implements Exception {
  final String message;

  const GiphyException(this.message);

  @override
  String toString() => message;
}

class GiphyMissingApiKeyException extends GiphyException {
  const GiphyMissingApiKeyException() : super('Missing GIPHY_API_KEY');
}
