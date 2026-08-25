import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 4122 URL namespace. Must match Swift and Cloud Functions.
const _urlNamespaceBytes = <int>[
  0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1,
  0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
];

/// Deterministic UUID v5 for StoreKit 2 `appAccountToken`.
/// Apple rejects non-UUID values, so the raw Firebase uid cannot be sent.
String appAccountTokenForUid(String uid) {
  final name = utf8.encode('florien.uid:$uid');
  final input = Uint8List(_urlNamespaceBytes.length + name.length)
    ..setAll(0, _urlNamespaceBytes)
    ..setAll(_urlNamespaceBytes.length, name);
  final digest = sha1.convert(input).bytes;
  final bytes = Uint8List.fromList(digest.sublist(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
