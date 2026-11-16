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

  @override
  String get camUnavailable =>
      'Cámara no disponible. Revisa el permiso de la cámara en Ajustes.';

  @override
  String get camTagsOpenFailed =>
      'No se pudieron abrir las etiquetas privadas. Vuelve a intentarlo desde la Biblioteca.';

  @override
  String get camOrientationFailed =>
      'No se pudo actualizar la orientación de la cámara.';

  @override
  String get camPendingSave =>
      'Captura en espera de guardado seguro. Libera almacenamiento y bloquea y desbloquea para reintentar.';

  @override
  String camRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'recuperaron $count capturas',
      one: 'recuperó 1 captura',
    );
    return 'Se $_temp0.';
  }

  @override
  String get camRecoveredVideoNote =>
      'Los vídeos interrumpidos pueden estar incompletos o no reproducirse en un televisor.';

  @override
  String get camPendingCheckFailed =>
      'No se pudieron comprobar las capturas pendientes. Libera almacenamiento y vuelve a abrir la cámara.';

  @override
  String get camNone => 'Sin cámara';

  @override
  String get camFocusLockFailed =>
      'No se pudieron bloquear el enfoque y la exposición en esta cámara.';

  @override
  String get camRecordStartFailed =>
      'No se pudo iniciar la grabación. Inténtalo de nuevo.';

  @override
  String get camRecordStopFailed =>
      'No se pudo detener la grabación. Inténtalo de nuevo.';

  @override
  String get camNoFrames =>
      'No se grabó ningún fotograma de vídeo. Inténtalo de nuevo.';

  @override
  String get camPendingNoTags =>
      'Captura en espera de guardado seguro. No se aplicaron las etiquetas; revisa la Biblioteca tras la recuperación.';

  @override
  String get camSaveFailed =>
      'No se pudo guardar la captura. Inténtalo de nuevo.';

  @override
  String camSavedPhotos(int count) {
    return '$count fotos guardadas de forma segura';
  }

  @override
  String get camSwitchFailed =>
      'No se pudo cambiar de cámara. Inténtalo de nuevo.';

  @override
  String get camMicDenied =>
      'Permite el acceso al micrófono en Ajustes para grabar vídeo. Las fotos siguen disponibles.';

  @override
  String get camVideoStartFailed =>
      'No se pudo iniciar el vídeo. Revisa los permisos de cámara y micrófono en Ajustes.';

  @override
  String get camSaving => 'Guardando de forma segura…';

  @override
  String get camSaved => 'Guardado de forma segura';

  @override
  String get camTagsNotApplied =>
      'No se aplicaron las etiquetas; organízalas en la Biblioteca.';

  @override
  String get camNotCastReady =>
      'Es posible que este vídeo no se reproduzca en tu televisor.';

  @override
  String get camPreview => 'Vista previa de la cámara';

  @override
  String get camPreviewHint =>
      'Toca para enfocar. Mantén pulsado para bloquear el enfoque y la exposición.';

  @override
  String get camFocusLocked => 'Enfoque y exposición bloqueados';

  @override
  String camRecTimer(String time) {
    return 'GRAB $time';
  }

  @override
  String get camStartingVideo => 'Iniciando vídeo…';

  @override
  String get camCastFailed => 'No se pudo transmitir. Inténtalo de nuevo.';

  @override
  String camCasting(String device) {
    return 'Transmitiendo a $device';
  }

  @override
  String get camChooseTags => 'Elige etiquetas para las capturas nuevas';

  @override
  String get camTags => 'Etiquetas';

  @override
  String camTagCount(int count) {
    return '$count etiquetas';
  }

  @override
  String get camTimerOff => 'Temporizador desactivado';

  @override
  String camTimerSeconds(int seconds) {
    return 'Temporizador de $seconds segundos';
  }

  @override
  String get camGridHide => 'Ocultar cuadrícula';

  @override
  String get camGridShow => 'Mostrar cuadrícula';

  @override
  String get camSwitchRear => 'Cambiar a la cámara trasera';

  @override
  String get camSwitchFront => 'Cambiar a la cámara frontal';

  @override
  String get camStopRecording => 'Detener grabación';

  @override
  String get camRecordVideo => 'Grabar vídeo';

  @override
  String get camStop => 'Detener';

  @override
  String get camVideo => 'Vídeo';

  @override
  String get camTakePhoto => 'Hacer foto';

  @override
  String get camCancelTimer => 'Cancelar temporizador';

  @override
  String get camPhoto => 'Foto';

  @override
  String get camOpenLibrary => 'Abrir Biblioteca';

  @override
  String get camLibrary => 'Biblioteca';

  @override
  String camTakeBurst(int count) {
    return 'Hacer $count fotos';
  }
}
