import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';
import 'package:reminder_hub/services/encryption_service.dart';
import 'package:reminder_hub/services/hive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const passphrase = 'a memorable backup phrase';
  final encryption = EncryptionService.instance;
  final hive = HiveService.instance;
  late Directory tempDir;
  late String localKey;

  UserAccount account() => UserAccount(
    id: 'account-1',
    serviceName: 'Private service',
    accountName: 'Primary',
    username: 'private-user',
    email: 'private@example.test',
    password: 'secret-password-value',
    pin: 'secret-pin-value',
    recoveryEmail: 'recovery@example.test',
    recoveryPhone: '+15551234567',
    securityQuestion: 'private answer',
    accountNumber: 'private-account-number',
    website: 'https://example.test',
    category: 'Finance',
    notes: 'private notes',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );

  setUp(() async {
    await hive.resetForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('reminder_crypto_test_');
    localKey = base64Encode(List<int>.filled(32, 7));
    await hive.init(
      directoryPath: tempDir.path,
      testCredentialEncryptionKey: localKey,
    );
  });

  tearDown(() async {
    await hive.resetForTesting();
    await tempDir.delete(recursive: true);
  });

  test(
    'account records are encrypted at rest and decrypt after restart',
    () async {
      await hive.saveUserAccount(account());
      final stored = hive.getUserAccountStorageRecords()['account-1']!;

      expect(stored, contains(EncryptionService.accountRecordFormat));
      expect(stored, isNot(contains('secret-password-value')));
      expect(stored, isNot(contains('secret-pin-value')));
      expect(hive.getUserAccounts().single.password, 'secret-password-value');

      await hive.resetForTesting();
      await hive.init(
        directoryPath: tempDir.path,
        testCredentialEncryptionKey: localKey,
      );
      expect(hive.getUserAccounts().single.password, 'secret-password-value');
    },
  );

  test(
    'legacy plaintext account migration is resumable and idempotent',
    () async {
      final legacy = account().toJson();
      await hive.writeRawUserAccountRecordForTesting(
        'account-1',
        jsonEncode(legacy),
      );
      await hive.resetForTesting();

      await hive.init(
        directoryPath: tempDir.path,
        testCredentialEncryptionKey: localKey,
      );
      final migrated = hive.getUserAccountStorageRecords()['account-1']!;
      expect(migrated, contains(EncryptionService.accountRecordFormat));
      expect(migrated, isNot(contains('secret-password-value')));
      expect(hive.getUserAccounts().single.password, 'secret-password-value');

      await hive.resetForTesting();
      await hive.init(
        directoryPath: tempDir.path,
        testCredentialEncryptionKey: localKey,
      );
      expect(hive.getUserAccountStorageRecords()['account-1'], migrated);
    },
  );

  test('missing device key locks records without deleting them', () async {
    await hive.saveUserAccount(account());
    final stored = hive.getUserAccountStorageRecords();
    await hive.resetForTesting();
    FlutterSecureStorage.setMockInitialValues({});

    await hive.init(directoryPath: tempDir.path);
    expect(() => hive.getUserAccounts(), throwsStateError);
    expect(hive.getUserAccountStorageRecords(), stored);
  });

  test(
    'portable backup uses authenticated encryption and rejects wrong phrase',
    () async {
      final envelope = await encryption.encryptBackupJson(
        jsonEncode({'private': 'secret-password-value'}),
        passphrase,
      );

      expect(envelope, contains(EncryptionService.portableBackupFormat));
      expect(envelope, isNot(contains('secret-password-value')));
      expect(
        await encryption.decryptBackupJson(envelope, passphrase),
        jsonEncode({'private': 'secret-password-value'}),
      );
      await expectLater(
        encryption.decryptBackupJson(envelope, 'a different backup phrase'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('portable backup rejects tampered ciphertext', () async {
    final encoded = await encryption.encryptBackupJson(
      '{"private":"payload"}',
      passphrase,
    );
    final envelope = jsonDecode(encoded) as Map<String, dynamic>;
    final ciphertext = envelope['ciphertext'] as String;
    final replacement = ciphertext[0] == 'A' ? 'B' : 'A';
    envelope['ciphertext'] = '$replacement${ciphertext.substring(1)}';

    await expectLater(
      encryption.decryptBackupJson(jsonEncode(envelope), passphrase),
      throwsA(isA<FormatException>()),
    );
  });
}
