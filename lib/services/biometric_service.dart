import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns `true` if the device supports biometrics / device credentials.
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Triggers the biometric / PIN prompt.
  ///
  /// Returns `true` when the user successfully authenticates,
  /// `false` if they cancel or fail.
  Future<bool> authenticate({
    String reason = 'Authenticate to reveal your password',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true,     // keep prompt open if app goes to background
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
