import 'dart:io';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Streams the authenticated media to disk, then imports it into Photos.
Future<void> saveVideoToGallery(
  String url, {
  required Map<String, String> headers,
}) async {
  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
    throw GalException.fromCode(
      code: 'ACCESS_DENIED',
      platformException: PlatformException(code: 'ACCESS_DENIED'),
      stackTrace: StackTrace.current,
    );
  }
  final client = http.Client();
  Directory? temporary;
  try {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri)
      // Do not forward private authorization headers to a redirect target.
      ..followRedirects = false
      ..headers.addAll(headers);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('Video download failed (${response.statusCode})');
    }
    var extension = path.extension(uri.path).toLowerCase();
    if (!{
      '.mp4',
      '.mov',
      '.m4v',
      '.webm',
      '.mkv',
      '.avi',
      '.3gp',
    }.contains(extension)) {
      extension = switch (response.headers['content-type']
          ?.split(';')
          .first
          .trim()) {
        'video/quicktime' => '.mov',
        'video/webm' => '.webm',
        'video/x-matroska' => '.mkv',
        _ => '.mp4',
      };
    }
    final root = await getTemporaryDirectory();
    temporary = await Directory(root.path).createTemp('chat-video-');
    final file = File(path.join(temporary.path, 'video$extension'));
    final sink = file.openWrite();
    try {
      await sink.addStream(
        response.stream.timeout(const Duration(seconds: 30)),
      );
    } finally {
      await sink.close();
    }
    if (await file.length() == 0) {
      throw const HttpException('Empty video download');
    }
    await Gal.putVideo(file.path);
  } finally {
    client.close();
    if (temporary != null) await temporary.delete(recursive: true);
  }
}
