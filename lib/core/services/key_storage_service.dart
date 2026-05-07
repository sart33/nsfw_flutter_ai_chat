import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeyStorageService {
  KeyStorageService._();

  static bool get _useMacOSFallback {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static const _secureStorage = FlutterSecureStorage();

  static Future<String> read(String key) async {
    if (_useMacOSFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? '';
    }
    return await _secureStorage.read(key: key) ?? '';
  }

  static Future<void> write(String key, String value) async {
    if (_useMacOSFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  static Future<void> delete(String key) async {
    if (_useMacOSFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }
}