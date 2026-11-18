import 'dart:convert';
import 'package:flutter/foundation.dart';

Uint8List _decodeBase64InIsolate(String image) {
  final separator = image.indexOf(',');
  return base64Decode(image.substring(separator + 1));
}

class Base64ImageCache {
  static final Map<int, Uint8List> _base64Bytes = {};
  static final Map<int, Future<Uint8List?>> _base64Requests = {};
  static final int _maxEntries = 12;

  static Uint8List? decodeBase64(String image) {
    if (!image.startsWith('data:image/')) return null;
    final key = Object.hash(image.length, image.hashCode);
    final cached = _base64Bytes[key];
    if (cached != null) return cached;

    final separator = image.indexOf(',');
    if (separator < 0) return null;
    try {
      final bytes = base64Decode(image.substring(separator + 1));
      if (_base64Bytes.length >= _maxEntries) {
        _base64Bytes.remove(_base64Bytes.keys.first);
      }
      _base64Bytes[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> decodeBase64Async(String image) {
    if (!image.startsWith('data:image/')) return Future.value(null);
    final key = Object.hash(image.length, image.hashCode);
    final cached = _base64Bytes[key];
    if (cached != null) return Future.value(cached);

    final pending = _base64Requests[key];
    if (pending != null) return pending;

    final request = _decodeAndCache(image, key);
    _base64Requests[key] = request;
    return request;
  }

  static Future<Uint8List?> _decodeAndCache(String image, int key) async {
    try {
      final bytes = await compute(_decodeBase64InIsolate, image);
      if (_base64Bytes.length >= _maxEntries) {
        _base64Bytes.remove(_base64Bytes.keys.first);
      }
      _base64Bytes[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _base64Requests.remove(key);
    }
  }

  static void clear() => _base64Bytes.clear();
}
