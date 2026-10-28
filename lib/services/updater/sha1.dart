import 'dart:typed_data';

/// Streaming SHA-1 (the release workflow publishes `.sha1` files). Written here because
/// `crypto` is not a direct dependency of the app.
Future<String> sha1OfStream(Stream<List<int>> chunks) async {
  final h = Uint32List.fromList([0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]);
  final w = Uint32List(80);
  final block = Uint8List(64);
  var filled = 0;
  var total = 0;

  void process() {
    for (var i = 0; i < 16; i++) {
      w[i] = (block[i * 4] << 24) | (block[i * 4 + 1] << 16) | (block[i * 4 + 2] << 8) | block[i * 4 + 3];
    }
    for (var i = 16; i < 80; i++) {
      final x = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
      w[i] = ((x << 1) | (x >>> 31)) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
    for (var i = 0; i < 80; i++) {
      int f, k;
      if (i < 20) {
        f = (b & c) | ((~b & 0xFFFFFFFF) & d);
        k = 0x5A827999;
      } else if (i < 40) {
        f = b ^ c ^ d;
        k = 0x6ED9EBA1;
      } else if (i < 60) {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8F1BBCDC;
      } else {
        f = b ^ c ^ d;
        k = 0xCA62C1D6;
      }
      final t = ((((a << 5) | (a >>> 27)) & 0xFFFFFFFF) + f + e + k + w[i]) & 0xFFFFFFFF;
      e = d;
      d = c;
      c = ((b << 30) | (b >>> 2)) & 0xFFFFFFFF;
      b = a;
      a = t;
    }
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
  }

  void add(int byte) {
    block[filled++] = byte;
    if (filled == 64) {
      process();
      filled = 0;
    }
  }

  await for (final chunk in chunks) {
    for (final byte in chunk) {
      add(byte);
    }
    total += chunk.length;
  }
  add(0x80);
  while (filled != 56) {
    add(0);
  }
  final bits = total * 8;
  for (var i = 7; i >= 0; i--) {
    add((bits >> (i * 8)) & 0xFF);
  }
  return [for (final v in h) v.toRadixString(16).padLeft(8, '0')].join();
}

/// The hex digest at the start of a `sha1sum` line (`<hex>  <file>`), lower-cased, or null.
String? parseSha1File(String text) {
  final m = RegExp(r'^\s*([0-9a-fA-F]{40})\b').firstMatch(text);
  return m?.group(1)?.toLowerCase();
}
