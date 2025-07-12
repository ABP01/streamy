import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class AgoraTokenService {
  static const String _appId = '28918fa47b4042c28f962d26dc5f27dd';
  static const String _appCertificate = '886c95285d784c3599237b611479205c';

  // Durée de validité du token (24 heures)
  static const int _privilegeExpiredTs = 24 * 3600;

  /// Génère un token RTC pour rejoindre un canal
  static String generateRtcToken({
    required String channelName,
    required int uid,
    String role =
        'publisher', // 'publisher' pour le host, 'subscriber' pour les viewers
    int expireTime = 0,
  }) {
    if (expireTime == 0) {
      expireTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + _privilegeExpiredTs;
    }

    final tokenBuilder = RtcTokenBuilder();
    return tokenBuilder.buildTokenWithUserAccount(
      appId: _appId,
      appCertificate: _appCertificate,
      channelName: channelName,
      uid: uid,
      role: role == 'publisher' ? Role.publisher : Role.subscriber,
      expireTime: expireTime,
    );
  }

  /// Génère un token pour un utilisateur spécifique
  static String generateUserToken({
    required String channelName,
    required String userAccount,
    String role = 'subscriber',
    int expireTime = 0,
  }) {
    if (expireTime == 0) {
      expireTime =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + _privilegeExpiredTs;
    }

    final tokenBuilder = RtcTokenBuilder();
    return tokenBuilder.buildTokenWithUserAccount(
      appId: _appId,
      appCertificate: _appCertificate,
      channelName: channelName,
      userAccount: userAccount,
      role: role == 'publisher' ? Role.publisher : Role.subscriber,
      expireTime: expireTime,
    );
  }

  /// Vérifie si un token est valide (non expiré)
  static bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Décoder la partie payload (base64)
      final payload = parts[1];
      final decoded = base64Decode(_addPadding(payload));
      final payloadStr = utf8.decode(decoded);
      final payloadJson = jsonDecode(payloadStr);

      final expireTime = payloadJson['exp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      return expireTime > currentTime;
    } catch (e) {
      return false;
    }
  }

  /// Ajoute le padding nécessaire pour le décodage base64
  static String _addPadding(String str) {
    final mod = str.length % 4;
    if (mod == 0) return str;
    return str + '=' * (4 - mod);
  }
}

enum Role {
  publisher(1),
  subscriber(2);

  const Role(this.value);
  final int value;
}

class RtcTokenBuilder {
  String buildTokenWithUserAccount({
    required String appId,
    required String appCertificate,
    required String channelName,
    dynamic uid, // peut être int ou String
    required Role role,
    required int expireTime,
    String? userAccount,
  }) {
    final message = _Message();
    message.salt = _generateSalt();
    message.ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    message.privileges = {
      1: expireTime, // kJoinChannel
      if (role == Role.publisher) 2: expireTime, // kPublishAudioStream
      if (role == Role.publisher) 3: expireTime, // kPublishVideoStream
      if (role == Role.publisher) 4: expireTime, // kPublishDataStream
    };

    final serviceType = 1; // kRtcService
    final version = '007'; // Version du token

    String uidStr;
    if (uid is String) {
      uidStr = uid;
    } else if (uid is int) {
      uidStr = uid.toString();
    } else {
      uidStr = userAccount ?? '0';
    }

    final msgRaw = _packMessage(message, serviceType, uidStr, channelName);
    final signature = _generateSignature(appCertificate, msgRaw);

    final versionBytes = utf8.encode(version);
    final appIdBytes = utf8.encode(appId);
    final signatureBytes = signature;
    final msgBytes = msgRaw;

    final totalLength =
        versionBytes.length +
        appIdBytes.length +
        signatureBytes.length +
        msgBytes.length;
    final result = Uint8List(totalLength);

    int offset = 0;
    result.setRange(offset, offset + versionBytes.length, versionBytes);
    offset += versionBytes.length;

    result.setRange(offset, offset + appIdBytes.length, appIdBytes);
    offset += appIdBytes.length;

    result.setRange(offset, offset + signatureBytes.length, signatureBytes);
    offset += signatureBytes.length;

    result.setRange(offset, offset + msgBytes.length, msgBytes);

    return base64Encode(result);
  }

  int _generateSalt() {
    final random = Random.secure();
    return random.nextInt(0xFFFFFFFF);
  }

  Uint8List _packMessage(
    _Message message,
    int serviceType,
    String uid,
    String channelName,
  ) {
    final saltBytes = _intToBytes(message.salt, 4);
    final tsBytes = _intToBytes(message.ts, 4);

    final privilegesBytes = _packPrivileges(message.privileges);
    final serviceTypeBytes = _intToBytes(serviceType, 2);
    final uidBytes = utf8.encode(uid);
    final channelNameBytes = utf8.encode(channelName);

    final uidLengthBytes = _intToBytes(uidBytes.length, 2);
    final channelNameLengthBytes = _intToBytes(channelNameBytes.length, 2);

    final totalLength =
        saltBytes.length +
        tsBytes.length +
        privilegesBytes.length +
        serviceTypeBytes.length +
        uidLengthBytes.length +
        uidBytes.length +
        channelNameLengthBytes.length +
        channelNameBytes.length;

    final result = Uint8List(totalLength);
    int offset = 0;

    result.setRange(offset, offset + saltBytes.length, saltBytes);
    offset += saltBytes.length;

    result.setRange(offset, offset + tsBytes.length, tsBytes);
    offset += tsBytes.length;

    result.setRange(offset, offset + privilegesBytes.length, privilegesBytes);
    offset += privilegesBytes.length;

    result.setRange(offset, offset + serviceTypeBytes.length, serviceTypeBytes);
    offset += serviceTypeBytes.length;

    result.setRange(offset, offset + uidLengthBytes.length, uidLengthBytes);
    offset += uidLengthBytes.length;

    result.setRange(offset, offset + uidBytes.length, uidBytes);
    offset += uidBytes.length;

    result.setRange(
      offset,
      offset + channelNameLengthBytes.length,
      channelNameLengthBytes,
    );
    offset += channelNameLengthBytes.length;

    result.setRange(offset, offset + channelNameBytes.length, channelNameBytes);

    return result;
  }

  Uint8List _packPrivileges(Map<int, int> privileges) {
    final lengthBytes = _intToBytes(privileges.length, 2);
    final privilegeBytes = <int>[];

    for (final entry in privileges.entries) {
      privilegeBytes.addAll(_intToBytes(entry.key, 2));
      privilegeBytes.addAll(_intToBytes(entry.value, 4));
    }

    return Uint8List.fromList([...lengthBytes, ...privilegeBytes]);
  }

  Uint8List _intToBytes(int value, int length) {
    final result = Uint8List(length);
    for (int i = 0; i < length; i++) {
      result[i] = (value >> (i * 8)) & 0xFF;
    }
    return result;
  }

  Uint8List _generateSignature(String appCertificate, Uint8List message) {
    final key = utf8.encode(appCertificate);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(message);
    return Uint8List.fromList(digest.bytes);
  }
}

class _Message {
  late int salt;
  late int ts;
  late Map<int, int> privileges;
}
