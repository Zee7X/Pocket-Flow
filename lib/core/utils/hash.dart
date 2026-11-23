// lib/core/utils/hash.dart
import 'dart:convert';

/// FNV-1a 64-bit, dipakai untuk hash dedupe (bukan untuk keamanan).
/// Dihitung dengan dua bagian 32-bit agar hasilnya sama di web (JS) dan native.
String stableHash(String input) {
  final bytes = utf8.encode(input);
  // offset basis 0xcbf29ce484222325, prime 0x100000001b3
  var hi = 0xcbf29ce4;
  var lo = 0x84222325;
  for (final b in bytes) {
    lo ^= b;
    // (hi:lo) * (0x100:0x000001b3)
    final loMul = lo * 0x1b3;
    final carry = (loMul / 0x100000000).floor();
    final newLo = loMul % 0x100000000;
    final newHi = (hi * 0x1b3 + lo * 0x100 + carry) % 0x100000000;
    hi = newHi;
    lo = newLo;
  }
  return hi.toRadixString(16).padLeft(8, '0') +
      lo.toRadixString(16).padLeft(8, '0');
}
