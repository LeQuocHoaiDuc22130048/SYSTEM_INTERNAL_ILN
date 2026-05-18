// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;

Future<bool> hasInternetConnection() async => html.window.navigator.onLine ?? true;
