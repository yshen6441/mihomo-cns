import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/api.dart';

class Crypto {
  static const int _ivLength = 16;

  static String encrypt(String key, String data) {
    if (data.isEmpty) {
      return "";
    }
    try {
      final keyBytes = _deriveKey(key);
      final iv = _randomBytes(_ivLength);
      final plain = utf8.encode(data);
      final padded = Uint8List.fromList(_pad(plain));
      final encrypted = _cipher(keyBytes, iv, true).process(padded);
      final combined = [...iv, ...encrypted];
      return base64Encode(combined);
    } catch (_) {
      return data;
    }
  }

  static String decrypt(String key, String data) {
    if (data.isEmpty) {
      return "";
    }
    try {
      final combined = base64Decode(data);
      if (combined.length <= _ivLength) {
        return data;
      }
      final iv = combined.sublist(0, _ivLength);
      final encrypted = combined.sublist(_ivLength);
      final keyBytes = _deriveKey(key);
      final decrypted = _cipher(keyBytes, iv, false).process(encrypted);
      return utf8.decode(_unpad(decrypted));
    } catch (_) {
      return data;
    }
  }

  static Uint8List _deriveKey(String key) {
    return Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes);
  }

  static Uint8List _randomBytes(int length) {
    final random = FortunaRandom()
      ..seed(KeyParameter(_deriveKey(Random().nextInt(1 << 31).toString())));
    return random.nextBytes(length);
  }

  static CBCBlockCipher _cipher(Uint8List key, Uint8List iv, bool forEncryption) {
    final aes = AESEngine();
    aes.init(forEncryption, KeyParameter(key));
    final cipher = CBCBlockCipher(aes)
      ..init(forEncryption, ParametersWithIV(KeyParameter(key), iv));
    return cipher;
  }

  static List<int> _pad(List<int> data) {
    final blockSize = AESEngine().blockSize;
    final padLength = blockSize - (data.length % blockSize);
    return [...data, ...List.filled(padLength, padLength)];
  }

  static List<int> _unpad(List<int> data) {
    if (data.isEmpty) {
      return data;
    }
    final padLength = data.last;
    if (padLength <= 0 || padLength > data.length) {
      return data;
    }
    return data.sublist(0, data.length - padLength);
  }
}
