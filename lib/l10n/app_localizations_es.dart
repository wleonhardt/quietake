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

  @override
  String get save => 'Guardar';

  @override
  String get tagsTitle => 'Etiquetas';

  @override
  String get tagsMoments => 'Momentos';

  @override
  String get tagsSortName => 'Ordenar por nombre';

  @override
  String get tagsSortCount => 'Ordenar por más capturas';

  @override
  String get tagsCreate => 'Crear etiqueta';

  @override
  String get tagsFind => 'Buscar etiquetas';

  @override
  String get tagsCountFailed =>
      'No se pudieron contar las capturas. Reintentar';

  @override
  String get tagsUntagged => 'Sin etiquetar';

  @override
  String tagsCaptureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capturas',
      one: '1 captura',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoMatch => 'Ninguna etiqueta coincide';

  @override
  String get tagsNone => 'Aún no hay etiquetas';

  @override
  String get tagsNoMatchHint => 'Prueba con otro nombre o crea esta.';

  @override
  String get tagsNoneHint =>
      'Las etiquetas agrupan capturas en toda la Biblioteca.';

  @override
  String tagsCreateNamed(String name) {
    return 'Crear «$name»';
  }

  @override
  String get tagsCreateFirst => 'Crear la primera etiqueta';

  @override
  String get tagsOptions => 'Opciones de la etiqueta';

  @override
  String get tagsRename => 'Cambiar nombre';

  @override
  String get tagsRenameTitle => 'Cambiar nombre de la etiqueta';

  @override
  String get tagsSetCover => 'Elegir portada';

  @override
  String get tagsClearCover => 'Quitar portada';

  @override
  String get tagsMergeInto => 'Combinar con…';

  @override
  String get tagsDelete => 'Eliminar etiqueta';

  @override
  String get tagsDeleteTitle => '¿Eliminar la etiqueta?';

  @override
  String tagsDeleteBody(String name) {
    return '¿Quitar «$name» de todas las capturas? Las fotos y los vídeos permanecen en tu bóveda.';
  }

  @override
  String get tagsMergeTitle => '¿Combinar etiquetas?';

  @override
  String tagsMergeBody(String source, String target, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capturas usarán',
      one: '1 captura usará',
    );
    return '¿Combinar «$source» con «$target»? $_temp0 la etiqueta restante. La etiqueta de origen se elimina. Las fotos, los vídeos y las demás etiquetas no cambian.';
  }

  @override
  String get tagsMergeConfirm => 'Combinar etiquetas';

  @override
  String get mergeChoose => 'Elige la etiqueta que se conserva';

  @override
  String get mergeCancel => 'Cancelar la combinación';

  @override
  String get mergeFindDestination => 'Buscar etiqueta de destino';

  @override
  String get libraryNameLabel => 'Nombre';

  @override
  String get librarySaveFailed => 'No se pudo guardar. Reintentar.';

  @override
  String get libraryUpdateFailed =>
      'No se pudo actualizar la biblioteca privada. Reintentar.';

  @override
  String get momentsLoadFailed =>
      'No se pudieron leer las capturas. Reintentar';

  @override
  String get momentsEmpty => 'Aún no hay capturas con fecha';

  @override
  String get viewTitle => 'Vista';

  @override
  String get viewAll => 'Todo';

  @override
  String get viewPhotos => 'Fotos';

  @override
  String get viewVideos => 'Vídeos';

  @override
  String get viewFavoritesOnly => 'Solo favoritos';

  @override
  String get viewSort => 'Ordenar';

  @override
  String get viewNewest => 'Más recientes primero';

  @override
  String get viewOldest => 'Más antiguas primero';

  @override
  String get viewName => 'Nombre';

  @override
  String get viewApply => 'Aplicar vista';

  @override
  String viewShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count capturas',
      one: 'Mostrar 1 captura',
    );
    return '$_temp0';
  }

  @override
  String get viewReset => 'Restablecer';

  @override
  String get pickerCameraTitle => 'Etiquetas para las capturas nuevas';

  @override
  String get pickerRemoveTitle => 'Quitar etiquetas';

  @override
  String get pickerAddTitle => 'Añadir etiquetas';

  @override
  String get pickerCameraNote =>
      'Se borra al bloquear o pasar a segundo plano.';

  @override
  String pickerSelectionNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capturas',
      one: '1 captura',
    );
    return '$_temp0 · las demás etiquetas no cambian';
  }

  @override
  String get pickerCancel => 'Cancelar la selección de etiquetas';

  @override
  String get pickerNoTags => 'Sin etiquetas';

  @override
  String pickerAlreadyTagged(int tagged, int total) {
    return '$tagged de $total ya etiquetadas';
  }

  @override
  String get pickerManage => 'Gestionar etiquetas';

  @override
  String get pickerStale =>
      'Una etiqueta seleccionada ha cambiado. Revisa tu selección.';

  @override
  String get pickerReview => 'Revisar';

  @override
  String pickerUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usar $count etiquetas',
      one: 'Usar 1 etiqueta',
    );
    return '$_temp0';
  }

  @override
  String pickerAddCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count etiquetas',
      one: 'Añadir 1 etiqueta',
    );
    return '$_temp0';
  }

  @override
  String pickerRemoveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quitar $count etiquetas',
      one: 'Quitar 1 etiqueta',
    );
    return '$_temp0';
  }

  @override
  String get galleryActions => 'Acciones de la biblioteca';

  @override
  String get galleryActionsClose => 'Cerrar acciones de la biblioteca';

  @override
  String get gallerySelectCaptures => 'Seleccionar capturas';

  @override
  String get gallerySearchEdit => 'Editar búsqueda';

  @override
  String get gallerySearchHint => 'Buscar nombres y etiquetas';

  @override
  String get galleryRemovedTag => 'Etiqueta eliminada';

  @override
  String get galleryScopeAny => 'Toda la biblioteca · Cualquier etiqueta';

  @override
  String get galleryScopeAll => 'Toda la biblioteca · Todas las etiquetas';

  @override
  String get gallerySortNewest => 'Capturas más recientes';

  @override
  String get gallerySortOldest => 'Capturas más antiguas';

  @override
  String get gallerySortName => 'Orden por nombre';

  @override
  String get galleryTagMatching => 'Coincidencia de etiquetas';

  @override
  String get galleryMatchAll => 'Todas las etiquetas';

  @override
  String get galleryMatchAny => 'Cualquier etiqueta';

  @override
  String get galleryFavorites => 'Favoritos';

  @override
  String get galleryResetView => 'Restablecer vista';

  @override
  String get galleryAddTag => 'Añade una etiqueta';

  @override
  String get galleryAddTagHint =>
      'Elige etiquetas existentes o busca nombres con el texto de arriba.';

  @override
  String get galleryCancelSelection => 'Cancelar selección';

  @override
  String gallerySelectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get gallerySelectAll => 'Seleccionar todos los resultados';

  @override
  String get galleryShareCopies => 'Compartir copias';

  @override
  String get galleryUnfavorite => 'Quitar de favoritos';

  @override
  String get galleryFavorite => 'Favorito';

  @override
  String get galleryNameCapture => 'Poner nombre a la captura';

  @override
  String get galleryNasReadFailed =>
      'No se pudieron leer los datos guardados del NAS. Inténtalo de nuevo.';

  @override
  String get galleryImportTooltip => 'Importar copias desde Archivos';

  @override
  String get gallerySyncCancel => 'Cancelar sincronización';

  @override
  String get gallerySyncSetup => 'Configurar copia de seguridad';

  @override
  String get gallerySyncNow => 'Sincronizar con el NAS';

  @override
  String get galleryCloseSearch => 'Cerrar búsqueda';

  @override
  String get gallerySearchTitle => 'Buscar';

  @override
  String get gallerySettings => 'Ajustes';

  @override
  String get galleryOrgUnavailable =>
      'Organización no disponible. Los originales están a salvo. Reintentar';

  @override
  String get galleryOpenFailed => 'No se pudo abrir la bóveda. Reintentar';

  @override
  String get galleryEmptyTitle => 'Tu biblioteca empieza aquí';

  @override
  String get galleryEmptyMessage =>
      'Haz una foto o importa copias desde Archivos.';

  @override
  String get galleryOpenCamera => 'Abrir cámara';

  @override
  String get galleryImportCopies => 'Importar copias';

  @override
  String get galleryNoMatchTitle => 'Ninguna captura coincide';

  @override
  String get galleryNoMatchMessage =>
      'Borra la búsqueda y los filtros para ver todas las capturas.';

  @override
  String get galleryClearFilters => 'Borrar búsqueda y filtros';

  @override
  String galleryTileSelect(String label) {
    return 'Seleccionar $label';
  }

  @override
  String galleryTileOpen(String label) {
    return 'Abrir $label';
  }

  @override
  String get galleryTileFavorite => 'favorito';

  @override
  String galleryTilePosition(int position, int total) {
    return '$position de $total';
  }

  @override
  String galleryTileDuration(String time) {
    return 'duración $time';
  }

  @override
  String get galleryPreviewUnavailable => 'Vista previa no disponible';

  @override
  String get importIntro =>
      'Copia fotos y vídeos desde Archivos a tu Biblioteca. Los originales no se modifican, incluidas la ubicación y otros metadatos. No se elimina ni se comparte nada.';

  @override
  String get importChooseFiles => 'Elegir archivos';

  @override
  String get importChooseFolder => 'Elegir carpeta';

  @override
  String get importSupportedTitle => 'Archivos admitidos y límites';

  @override
  String get importSupportedBody =>
      'JPEG, PNG o MP4 reproducible. Hasta 20 archivos y 512 MiB en total; fotos de hasta 32 MiB y 64 MP. Una carpeta importa sus archivos (no las subcarpetas), hasta 10 000, de 20 en 20; elige la misma carpeta de nuevo para reanudar. La reproducción en TV depende de los códecs. Las importaciones usan la fecha de incorporación. Las copias seleccionadas pueden terminar de cifrarse mientras Quietake está bloqueado.';

  @override
  String get importCancelling => 'Cancelando tras el archivo actual…';

  @override
  String get importCancelRemaining => 'Cancelar el resto';

  @override
  String importFolderCount(int handled, int total) {
    return '$handled de $total archivos';
  }

  @override
  String get importBusyPrevious =>
      'La importación anterior está terminando. Inténtalo de nuevo en breve.';

  @override
  String get importOpenFailed =>
      'No se pudo abrir la importación. Revisa el almacenamiento e inténtalo de nuevo.';

  @override
  String get importStoppedEarly =>
      'La importación se detuvo antes de tiempo. Las copias indicadas como importadas están guardadas.';

  @override
  String get importCleanupFailed =>
      'Falló la limpieza temporal. Reinicia Quietake antes de volver a intentarlo.';

  @override
  String get importFolderStopped =>
      'La importación de la carpeta se detuvo. Elige la carpeta de nuevo para continuar; los archivos terminados están guardados.';

  @override
  String importImported(int count) {
    return '$count importadas';
  }

  @override
  String importDuplicates(int count) {
    return '$count duplicadas omitidas';
  }

  @override
  String importAlreadyDone(int count) {
    return '$count ya importadas antes';
  }

  @override
  String importFailedCount(int count) {
    return '$count con error';
  }

  @override
  String importNotStarted(int count) {
    return '$count sin empezar';
  }

  @override
  String importSummaryEnd(String summary) {
    return '$summary.';
  }

  @override
  String importSummaryContinue(String summary) {
    return '$summary. Elige la misma carpeta de nuevo para continuar.';
  }
}
