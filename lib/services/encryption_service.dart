import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final EncryptionService instance = EncryptionService._();
  EncryptionService._();

  static const accountRecordFormat = 'reminderhub-encrypted-account';
  static const portableBackupFormat = 'reminderhub-encrypted-backup';
  static const _formatVersion = 1;
  static const _backupKdfIterations = 600000;
  static const _keyLength = 32;
  static const _saltLength = 16;

  final AesGcm _cipher = AesGcm.with256bits();

  String generateLocalKey() => base64Encode(_randomBytes(_keyLength));

  bool isEncryptedAccountRecord(Map<String, dynamic> record) =>
      record['format'] == accountRecordFormat;

  Future<String> encryptAccountJson(String plaintext, String encodedKey) async {
    final key = _decodeLocalKey(encodedKey);
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
    );
    return jsonEncode({
      'format': accountRecordFormat,
      'version': _formatVersion,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<String> decryptAccountJson(String record, String encodedKey) async {
    final decoded = _decodeEnvelope(record, accountRecordFormat);
    if (decoded['version'] != _formatVersion) {
      throw const FormatException('Unsupported encrypted account version.');
    }
    final secretBox = _secretBoxFromMap(decoded);
    try {
      final plaintext = await _cipher.decrypt(
        secretBox,
        secretKey: SecretKey(_decodeLocalKey(encodedKey)),
      );
      return utf8.decode(plaintext);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Saved account credentials could not be unlocked. The secure key may be unavailable.',
      );
    }
  }

  Future<String> encryptBackupJson(String plaintext, String passphrase) async {
    if (passphrase.trim().runes.length < 12) {
      throw ArgumentError('Backup passphrase must be at least 12 characters.');
    }
    final salt = _randomBytes(_saltLength);
    final key = await _deriveBackupKey(passphrase, salt);
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    return jsonEncode({
      'format': portableBackupFormat,
      'version': _formatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _backupKdfIterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<String> decryptBackupJson(
    String serializedEnvelope,
    String passphrase,
  ) async {
    final decoded = _decodeEnvelope(
      serializedEnvelope,
      portableBackupFormat,
    );
    if (decoded['version'] != _formatVersion ||
        decoded['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        decoded['iterations'] != _backupKdfIterations ||
        decoded['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported encrypted backup format.');
    }
    final salt = _decodeBase64(decoded['salt'], field: 'salt');
    if (salt.length != _saltLength) {
      throw const FormatException('Invalid encrypted backup salt.');
    }
    final secretBox = _secretBoxFromMap(decoded);
    try {
      final plaintext = await _cipher.decrypt(
        secretBox,
        secretKey: await _deriveBackupKey(passphrase, salt),
      );
      return utf8.decode(plaintext);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Incorrect passphrase or damaged encrypted backup.',
      );
    }
  }

  Future<SecretKey> _deriveBackupKey(String passphrase, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _backupKdfIterations,
        bits: _keyLength * 8,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);

  Map<String, dynamic> _decodeEnvelope(String serialized, String format) {
    final decoded = jsonDecode(serialized);
    if (decoded is! Map) {
      throw const FormatException('Encrypted data must be a JSON object.');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != format) {
      throw const FormatException('Unsupported encrypted data format.');
    }
    return envelope;
  }

  SecretBox _secretBoxFromMap(Map<String, dynamic> envelope) {
    final nonce = _decodeBase64(envelope['nonce'], field: 'nonce');
    final ciphertext = _decodeBase64(
      envelope['ciphertext'],
      field: 'ciphertext',
    );
    final mac = _decodeBase64(envelope['mac'], field: 'authentication tag');
    if (nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Invalid encrypted data parameters.');
    }
    return SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
  }

  List<int> _decodeLocalKey(String encodedKey) {
    final key = _decodeBase64(encodedKey, field: 'account key');
    if (key.length != _keyLength) {
      throw const FormatException('Invalid account encryption key.');
    }
    return key;
  }

  List<int> _decodeBase64(Object? value, {required String field}) {
    if (value is! String) {
      throw FormatException('Invalid encrypted data $field.');
    }
    try {
      return base64Decode(value);
    } on FormatException {
      throw FormatException('Invalid encrypted data $field.');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
