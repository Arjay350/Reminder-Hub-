import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._internal();
  SecurityService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final availableBiometrics = await _auth.getAvailableBiometrics();
      return (canCheckBiometrics || isSupported) &&
          (availableBiometrics.isNotEmpty || canCheckBiometrics);
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFingerprintSupported() async {
    try {
      final available = await getAvailableBiometrics();
      return available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          await isBiometricsAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Scan your fingerprint to unlock Reminder Hub',
  }) async {
    try {
      final isAvail = await isBiometricsAvailable();
      if (!isAvail) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setAppPin(String pin) async {
    await _storage.write(key: 'app_pin', value: pin);
  }

  Future<String?> getAppPin() async {
    return await _storage.read(key: 'app_pin');
  }

  Future<void> removeAppPin() async {
    await _storage.delete(key: 'app_pin');
  }

  Future<bool> verifyPin(String enteredPin) async {
    final savedPin = await getAppPin();
    return savedPin == enteredPin;
  }
}
