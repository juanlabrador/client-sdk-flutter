import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

const defaultRatchetSalt = 'LKFrameEncryptionKey';
const defaultMagicBytes = 'LK-ROCKS';
const defaultRatchetWindowSize = 16;

class KeyInfo {
  final String participantId;
  final int keyIndex;
  final Uint8List key;
  KeyInfo({
    required this.participantId,
    required this.keyIndex,
    required this.key,
  });
}

abstract class KeyProvider {
  Future<void> setKey(String key, {String? participantId, int keyIndex = 0});
  Future<Uint8List> ratchetKey(String participantId, int index);
  rtc.KeyProvider get keyProvider;
}

class BaseKeyProvider implements KeyProvider {
  final Map<String, Map<int, Uint8List>> _keys = {};
  Uint8List? _sharedKey;
  final rtc.KeyProviderOptions options;
  final rtc.KeyProvider _keyProvider;
  @override
  rtc.KeyProvider get keyProvider => _keyProvider;

  Uint8List? get sharedKey => _sharedKey;

  BaseKeyProvider(this._keyProvider, this.options);

  static Future<BaseKeyProvider> create({
    bool sharedKey = true,
    String? ratchetSalt,
    String? uncryptedMagicBytes,
    int? ratchetWindowSize,
  }) async {
    rtc.KeyProviderOptions options = rtc.KeyProviderOptions(
      sharedKey: sharedKey,
      ratchetSalt:
          Uint8List.fromList((ratchetSalt ?? defaultRatchetSalt).codeUnits),
      ratchetWindowSize: ratchetWindowSize ?? defaultRatchetWindowSize,
      uncryptedMagicBytes: Uint8List.fromList(
          (uncryptedMagicBytes ?? defaultMagicBytes).codeUnits),
    );
    final keyProvider = await rtc.FrameCryptorFactory.instance
        .createDefaultKeyProvider(options);
    return BaseKeyProvider(keyProvider, options);
  }

  @override
  Future<Uint8List> ratchetKey(String participantId, int index) =>
      _keyProvider.ratchetKey(participantId: participantId, index: index);

  @override
  Future<void> setKey(String key,
      {String? participantId, int keyIndex = 0}) async {
    if (options.sharedKey) {
      _sharedKey = Uint8List.fromList(key.codeUnits);
      return;
    }
    final keyInfo = KeyInfo(
      participantId: participantId ?? '',
      keyIndex: keyIndex,
      key: Uint8List.fromList(key.codeUnits),
    );
    return _setKey(keyInfo);
  }

  Future<void> _setKey(KeyInfo keyInfo) async {
    if (!_keys.containsKey(keyInfo.participantId)) {
      _keys[keyInfo.participantId] = {};
    }
    _keys[keyInfo.participantId]![keyInfo.keyIndex] = keyInfo.key;
    await _keyProvider.setKey(
      participantId: keyInfo.participantId,
      index: keyInfo.keyIndex,
      key: keyInfo.key,
    );
  }
}
