// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get recentlyDeletedTitle => 'Eliminados recientemente';

  @override
  String get recentlyDeletedEmpty => 'Nada eliminado recientemente';

  @override
  String recentlyDeletedNote(int days) {
    return 'Las capturas eliminadas permanecen cifradas en este teléfono durante $days días y luego se eliminan definitivamente.';
  }

  @override
  String get recentlyDeletedLoadFailed =>
      'No se pudieron leer las capturas eliminadas. Reintentar';

  @override
  String recentlyDeletedDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count días',
      one: 'Queda 1 día',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedRestore => 'Restaurar';

  @override
  String get recentlyDeletedDeleteNow => 'Eliminar ahora';

  @override
  String get recentlyDeletedDeleteNowTitle => '¿Eliminar ahora?';

  @override
  String get recentlyDeletedDeleteNowBody =>
      'Esta captura se elimina de forma permanente de este teléfono y de tu NAS configurado. No se puede restaurar.';

  @override
  String get recentlyDeletedAllTitle => '¿Eliminar todo ahora?';

  @override
  String recentlyDeletedAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count capturas se eliminan de forma permanente de este teléfono y de tu NAS configurado. No se pueden restaurar.',
      one: '1 captura se elimina de forma permanente de este teléfono y de tu NAS configurado. No se puede restaurar.',
    );
    return '$_temp0';
  }

  @override
  String get recentlyDeletedAllNow => 'Eliminar todo ahora';

  @override
  String get recentlyDeletedRestoreFailed =>
      'No se pudo restaurar. Inténtalo de nuevo.';

  @override
  String get recentlyDeletedDeleteFailed =>
      'No se pudo terminar de eliminar. Inténtalo de nuevo.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get lockUnlockReason => 'Desbloquear Quietake';

  @override
  String get lockBiometricUnavailable =>
      'El desbloqueo biométrico no está disponible. Usa tu código de acceso.';

  @override
  String get lockFailed =>
      'No se pudo desbloquear. Inténtalo de nuevo o usa tu clave de recuperación.';

  @override
  String get lockMessage => 'Desbloquea tu bóveda privada.';

  @override
  String get passcodeLabel => 'Código de acceso';

  @override
  String get lockUnlock => 'Desbloquear';

  @override
  String get lockUseBiometrics => 'Usar biometría';

  @override
  String get lockForgot => '¿Olvidaste tu código de acceso?';

  @override
  String get recoveryKeyLabel => 'Clave de recuperación';

  @override
  String get recoveryKeyIntro =>
      'Guarda esta clave en tu gestor de contraseñas, separada de tus archivos cifrados. Necesitas ambos para recuperar tus capturas si olvidas el código de acceso o pierdes este dispositivo. Una frase de contraseña de copia en el NAS es otra opción de recuperación solo si la has activado.';

  @override
  String recoveryFingerprint(String fingerprint) {
    return 'Huella $fingerprint';
  }

  @override
  String get recoveryFingerprintNote =>
      'Guarda la huella junto con la clave. Un teléfono nuevo la muestra para que puedas comprobar la clave que escribiste.';

  @override
  String get recoverySaved => 'Ya la guardé';

  @override
  String get changePasscodeTitle => 'Cambiar código de acceso';

  @override
  String get changePasscodeNote =>
      'Tus capturas y tu clave de recuperación no cambian.';

  @override
  String get currentPasscodeLabel => 'Código de acceso actual';

  @override
  String get newPasscodeLabel => 'Nuevo código de acceso';

  @override
  String get confirmNewPasscodeLabel => 'Confirmar nuevo código de acceso';

  @override
  String get passcodesDoNotMatch => 'Los códigos de acceso no coinciden';

  @override
  String get currentPasscodeIncorrect =>
      'El código de acceso actual es incorrecto';

  @override
  String get changePasscodeFailed =>
      'No se pudo cambiar el código de acceso. Inténtalo de nuevo.';

  @override
  String get changePasscodeBusy => 'Cambiando…';

  @override
  String get setupConfirmKeyTitle => 'Confirmar clave de recuperación';

  @override
  String get setupConfirmKeyBody =>
      'Este teléfono aún no tiene capturas, por lo que la clave no se puede comprobar con ellas. Compara esta huella con la guardada junto a tu clave de recuperación.';

  @override
  String get setupNotMine => 'No es mía';

  @override
  String get setupMatches => 'Coincide';

  @override
  String get setupCreateFailed =>
      'No se pudo crear la bóveda. Revisa el almacenamiento e inténtalo de nuevo.';

  @override
  String get setupRestoreFailed =>
      'No se pudo restaurar la bóveda. Revisa el almacenamiento e inténtalo de nuevo.';

  @override
  String get setupRestoreTitle => 'Restaurar bóveda';

  @override
  String get setupCreateTitle => 'Establece un código de acceso';

  @override
  String get setupRestoreMessage =>
      'Desbloquea tus archivos cifrados con tu clave de recuperación guardada.';

  @override
  String get setupTagline => 'Tu cámara. Tus capturas. Tu control.';

  @override
  String setupPasscodeHelper(int count) {
    return 'Al menos $count caracteres';
  }

  @override
  String get confirmPasscodeLabel => 'Confirmar código de acceso';

  @override
  String get restore => 'Restaurar';

  @override
  String get setupCreateVault => 'Crear bóveda';

  @override
  String get setupStartNew => 'Empezar una bóveda nueva';

  @override
  String get setupHaveKey => 'Tengo una clave de recuperación';

  @override
  String get setupRestoreZip => 'Restaurar un ZIP cifrado';

  @override
  String get setupRestoreNas =>
      'Restaurar desde el NAS con la frase de contraseña de la copia';

  @override
  String get privacyPolicy => 'Política de privacidad';
}
