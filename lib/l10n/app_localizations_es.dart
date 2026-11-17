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
  String get lockCamera => 'Cámara';

  @override
  String get lockedCameraSaved =>
      'Foto sellada. Aparece en tu biblioteca después de desbloquear.';

  @override
  String get lockedCameraFailed => 'No se pudo guardar la foto.';

  @override
  String get lockedCameraClose => 'Cerrar la cámara';

  @override
  String lockedCapturesPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fotos de la cámara de la pantalla de bloqueo ya están en tu biblioteca.',
      one: '1 foto de la cámara de la pantalla de bloqueo ya está en tu biblioteca.',
    );
    return '$_temp0';
  }

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
  String get importSubfolders => 'Incluir subcarpetas';

  @override
  String get importSubfoldersBody =>
      'También lee las fotos y vídeos de las carpetas dentro de la elegida.';

  @override
  String get importOpenShare => 'Abrir compartición cifrada';

  @override
  String get importSharePassphraseTitle =>
      'Frase de contraseña de esta compartición';

  @override
  String get importSharePassphraseLabel => 'Frase de contraseña';

  @override
  String get importShareOpenButton => 'Abrir';

  @override
  String get importShareFailed =>
      'No se pudo abrir la compartición. Revisa la frase de contraseña y el archivo.';

  @override
  String get importSupportedTitle => 'Archivos admitidos y límites';

  @override
  String get importSupportedBody =>
      'JPEG, PNG o MP4 reproducible. Hasta 20 archivos y 512 MiB en total; fotos de hasta 32 MiB y 64 MP. Una carpeta importa sus archivos (no las subcarpetas), hasta 10 000, de 20 en 20; elige la misma carpeta de nuevo para reanudar. La reproducción en TV depende de los códecs. Las importaciones usan la fecha de incorporación. Las copias seleccionadas pueden terminar de cifrarse mientras Quietake está bloqueado. Una compartición cifrada (.quietake-share) se abre con su frase de contraseña; sus fotos y vídeos se importan después como otros archivos.';

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

  @override
  String get shareTitleOne => '¿Compartir una copia?';

  @override
  String shareTitleMany(int count) {
    return '¿Compartir $count copias?';
  }

  @override
  String get shareWarning =>
      'La app que elijas recibe copias sin cifrar y puede conservarlas.';

  @override
  String get shareStripTitle =>
      'Quitar los metadatos de las copias de fotos JPEG';

  @override
  String get shareStripOn =>
      'Las copias JPEG conservan solo su orientación: se eliminan la ubicación, la cámara, la hora, los comentarios y las miniaturas. Las copias PNG y de vídeo no cambian.';

  @override
  String get shareStripOff =>
      'Las copias conservan todos los metadatos originales, incluida la ubicación si existe.';

  @override
  String shareLimits(int items, int mib) {
    return 'Hasta $items capturas y $mib MiB por lote.';
  }

  @override
  String shareProgress(int prepared, int total) {
    return 'Preparando $prepared de $total';
  }

  @override
  String get shareFailed =>
      'No se pudo compartir. Puede que otro uso compartido aún esté terminando. Inténtalo de nuevo.';

  @override
  String get shareChooseApp => 'Elegir app';

  @override
  String get viewerShareFailed => 'No se pudo compartir. Inténtalo de nuevo.';

  @override
  String get viewerDetails => 'Detalles';

  @override
  String viewerType(String kind) {
    return 'Tipo: $kind';
  }

  @override
  String viewerCaptured(String when) {
    return 'Capturada: $when';
  }

  @override
  String get viewerUnknown => 'Desconocida';

  @override
  String viewerTags(String tags) {
    return 'Etiquetas: $tags';
  }

  @override
  String get viewerNone => 'Ninguna';

  @override
  String viewerSize(int bytes) {
    return 'Tamaño cifrado: $bytes bytes';
  }

  @override
  String get viewerSizeUnavailable => 'Tamaño cifrado: no disponible';

  @override
  String get viewerClose => 'Cerrar';

  @override
  String viewerSetCover(String tag) {
    return 'Usar como portada de $tag';
  }

  @override
  String viewerCoverSet(String tag) {
    return 'Portada de $tag actualizada.';
  }

  @override
  String get viewerDeletePhotoTitle => '¿Eliminar esta foto?';

  @override
  String get viewerDeleteVideoTitle => '¿Eliminar este vídeo?';

  @override
  String viewerDeleteKeepNas(int days) {
    return '«Eliminados recientemente» la conserva en este teléfono, cifrada, durante $days días para que puedas restaurarla. Tu copia en el NAS se mantiene hasta entonces. «Eliminar ahora» la quita de forma permanente de este teléfono y de tu NAS configurado.';
  }

  @override
  String viewerDeleteKeep(int days) {
    return '«Eliminados recientemente» la conserva en este teléfono, cifrada, durante $days días para que puedas restaurarla. «Eliminar ahora» la quita de forma permanente de este teléfono.';
  }

  @override
  String get viewerDeleteNasNow =>
      'Se eliminará de forma permanente de este teléfono y de tu NAS configurado.';

  @override
  String get viewerDeleteNow =>
      'Se eliminará de forma permanente de este teléfono.';

  @override
  String get viewerDeleteNasTail =>
      'Si el NAS no está disponible, la eliminación termina cuando la sincronización se complete.';

  @override
  String get viewerDeletePendingTail =>
      'Las eliminaciones pendientes se aplican si vuelves a conectar una copia de seguridad en el NAS.';

  @override
  String get viewerDeleteEnd =>
      'Las demás copias de seguridad y las copias compartidas no se ven afectadas. La transmisión activa se detendrá.';

  @override
  String get viewerDelete => 'Eliminar';

  @override
  String get viewerRemoveFavorite => 'Quitar favorito';

  @override
  String get viewerAddFavorite => 'Añadir a favoritos';

  @override
  String get viewerSlideshowStart => 'Iniciar presentación';

  @override
  String get viewerSlideshowStop => 'Detener presentación';

  @override
  String get viewerShare => 'Compartir una copia';

  @override
  String get viewerDeletePhoto => 'Eliminar foto';

  @override
  String get viewerDeleteVideo => 'Eliminar vídeo';

  @override
  String get viewerHideControls => 'Ocultar controles';

  @override
  String get viewerShowControls => 'Mostrar controles';

  @override
  String viewerCasting(String device) {
    return 'transmitiendo a $device';
  }

  @override
  String get viewerPhotoUnavailable => 'Foto no disponible. Reintentar';

  @override
  String get viewerPrivatePhoto => 'Foto privada';

  @override
  String get viewerResetFit => 'Ajustar a la pantalla';

  @override
  String get viewerVideoUnavailable => 'Vídeo no disponible. Reintentar';

  @override
  String get viewerReplay => 'Repetir vídeo';

  @override
  String get viewerPlay => 'Reproducir vídeo';

  @override
  String get viewerPause => 'Pausar vídeo';

  @override
  String get viewerVideoPosition => 'Posición del vídeo';

  @override
  String get viewerBack10 => 'Retroceder 10 segundos';

  @override
  String get viewerForward10 => 'Avanzar 10 segundos';

  @override
  String get viewerMute => 'Silenciar vídeo';

  @override
  String get viewerUnmute => 'Activar sonido del vídeo';

  @override
  String get lockNow => 'Bloquear ahora';

  @override
  String get brandTagline => 'Cámara privada';

  @override
  String get backupTitle => 'Comprobar copia de seguridad';

  @override
  String get backupIntro =>
      'Comprueba cada archivo cifrado de tu copia de seguridad guardada en el NAS con la clave de esta bóveda. Las bibliotecas grandes necesitan tiempo, datos y espacio temporal. Esta comprobación no modifica los originales.';

  @override
  String get backupNeverChecked =>
      'Esta copia de seguridad nunca se ha comprobado por completo. Compruébala para confirmar que tus copias se pueden leer.';

  @override
  String backupStale(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'La última comprobación completa fue hace $_temp0. Vuelve a comprobar para confirmar que tus copias aún se pueden leer.';
  }

  @override
  String get backupCancelCheck => 'Cancelar comprobación';

  @override
  String get backupCancelQueued => 'Cancelar comprobación en cola';

  @override
  String get backupCheckSaved => 'Comprobar copia guardada';

  @override
  String backupCheckedAt(String date, String time, String state) {
    return 'Comprobada el $date a las $time · $state';
  }

  @override
  String get backupUnchanged => 'Nada ha cambiado desde entonces';

  @override
  String get backupChanged => 'Ha cambiado desde entonces; vuelve a comprobar';

  @override
  String get backupKeepKey =>
      'Guarda tu clave de recuperación por separado. Una comprobación correcta no prueba la copia de la clave que guardaste en otro sitio.';

  @override
  String get backupLeaveNote =>
      'Puedes salir de esta pantalla mientras se comprueba. Las subidas de capturas esperan a que termine la comprobación. Las comprobaciones se detienen si se cierra el proceso de la app.';

  @override
  String get castSearchFailed =>
      'No se pudo buscar televisores. Revisa el Wi-Fi e inténtalo de nuevo.';

  @override
  String castConnected(String device) {
    return 'Conectado a $device. Abre una captura para transmitirla.';
  }

  @override
  String get castTitle => 'Transmitir a un televisor';

  @override
  String get castClose => 'Cerrar selector de transmisión';

  @override
  String get castUnencrypted =>
      'Los archivos seleccionados se transmiten sin cifrar por tu red local mientras dura la transmisión.';

  @override
  String get castLooking => 'Buscando televisores en esta red';

  @override
  String get castNoneFound => 'No se encontró ningún televisor';

  @override
  String get castSameWifi =>
      '¿Está el televisor en el mismo Wi-Fi que este teléfono?';

  @override
  String get castRetry => 'Reintentar';

  @override
  String castStop(String device) {
    return 'Dejar de transmitir a $device';
  }

  @override
  String get castCancelConnection => 'Cancelar conexión';

  @override
  String get castToTv => 'Transmitir al televisor';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsPrivacySection => 'Privacidad y acceso';

  @override
  String get settingsIdleLabel => 'Bloquear tras inactividad';

  @override
  String get settingsIdleOff => 'Desactivado';

  @override
  String settingsIdleMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get settingsIdleNote =>
      'La grabación y la reproducción de vídeo retrasan el bloqueo por inactividad. Bloquear ahora guarda una grabación activa, pausa la reproducción y detiene la transmisión.';

  @override
  String get settingsScreenshotsIos =>
      'Las vistas previas del selector de apps están ocultas. Las capturas de pantalla de iOS no se pueden bloquear.';

  @override
  String get settingsScreenshotsAndroid =>
      'Las capturas de pantalla, la grabación de pantalla y las vistas previas del selector de apps están protegidas en Android.';

  @override
  String get settingsPrivacySaveFailed =>
      'No se pudieron guardar los ajustes de privacidad. Inténtalo de nuevo.';

  @override
  String get settingsPasscodeChanged => 'Código cambiado';

  @override
  String get settingsBackupSection => 'Copia de seguridad';

  @override
  String get settingsBackupIntro =>
      'Copia de seguridad opcional de los archivos cifrados en tu propio recurso WebDAV.';

  @override
  String get settingsUrlLabel => 'URL de la carpeta WebDAV';

  @override
  String get settingsUsername => 'Usuario';

  @override
  String get settingsPassword => 'Contraseña';

  @override
  String get settingsBackgroundTitle => 'Copia de seguridad con la app cerrada';

  @override
  String get settingsBackgroundBody =>
      'Android programa las subidas cifradas cuando la red y la batería lo permiten. Guarda y completa antes una sincronización en primer plano. Forzar la detención pausa el trabajo hasta que vuelvas a abrir Quietake.';

  @override
  String get settingsMobileTitle => 'Permitir datos móviles';

  @override
  String get settingsMobileBody =>
      'Desactivado usa solo redes sin límite de datos. Los vídeos grandes pueden consumir muchos datos.';

  @override
  String get settingsBgChecking => 'Comprobando el programador de Android…';

  @override
  String get settingsBgScheduled =>
      'Programada para cuando la red y la batería lo permitan.';

  @override
  String get settingsBgUploading => 'Android está subiendo copias cifradas.';

  @override
  String get settingsBgTransferred =>
      'La última pasada en segundo plano terminó. La verificación completa de la copia es independiente.';

  @override
  String get settingsBgReconcile =>
      'Abre la bóveda y sincroniza para comprobar esta copia antes de que se reanuden las subidas en segundo plano.';

  @override
  String get settingsBgPending =>
      'Copia en segundo plano pendiente. Android lo reintentará.';

  @override
  String get settingsBgOff =>
      'La copia en segundo plano está desactivada o espera su primera sincronización correcta.';

  @override
  String get settingsBgUnavailable =>
      'Programador no disponible. La sincronización en primer plano sigue disponible.';

  @override
  String get settingsSave => 'Guardar ajustes de copia';

  @override
  String get settingsTest => 'Probar conexión';

  @override
  String get settingsTesting => 'Probando la conexión…';

  @override
  String settingsConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '1 archivo',
    );
    return 'Conectado · $_temp0';
  }

  @override
  String settingsErrHttp(int status) {
    return 'Error de conexión (HTTP $status). Revisa la URL de la carpeta, el usuario y la contraseña.';
  }

  @override
  String get settingsErrReach =>
      'No se pudo contactar con el NAS. Revisa la URL y el Wi-Fi.';

  @override
  String get settingsErrGeneric =>
      'Error de conexión. Revisa los datos guardados e inténtalo de nuevo.';

  @override
  String get settingsSaveFirst =>
      'Guarda los cambios de conexión antes de comprobar la copia.';

  @override
  String get settingsEnterDetails =>
      'Introduce una URL de carpeta, un usuario y una contraseña';

  @override
  String get settingsSaveFailed =>
      'No se pudieron guardar los datos de conexión. Inténtalo de nuevo.';

  @override
  String get settingsDisconnectFailed =>
      'No se pudo desconectar la copia en el NAS. Inténtalo de nuevo.';

  @override
  String get settingsWrongPasscode => 'Código incorrecto. Inténtalo de nuevo.';

  @override
  String get settingsRecoveryReadFailed =>
      'No se pudo leer la clave de recuperación. Inténtalo de nuevo.';

  @override
  String get settingsDisconnectTitle => '¿Desconectar la copia en el NAS?';

  @override
  String get settingsClearTitle => '¿Borrar los datos guardados del NAS?';

  @override
  String get settingsDisconnectBody =>
      'Detiene la copia automática y elimina los datos de conexión guardados. Las capturas permanecen en tu teléfono y en el NAS. Las eliminaciones pendientes en el NAS no terminarán hasta que vuelvas a conectar esa copia.';

  @override
  String get settingsDisconnectAction => 'Desconectar';

  @override
  String get settingsClearAction => 'Borrar datos';

  @override
  String get settingsDisconnectButton => 'Desconectar la copia en el NAS';

  @override
  String get settingsClearButton => 'Borrar los datos guardados del NAS';

  @override
  String get settingsRecoverySection => 'Recuperación y exportación';

  @override
  String get settingsShowRecovery => 'Mostrar clave de recuperación';

  @override
  String get settingsNasPassTitle =>
      'Frase de contraseña de la copia en el NAS';

  @override
  String get settingsNasPassBody =>
      'Activa, cambia o desactiva la recuperación sin tu clave de recuperación';

  @override
  String get settingsPortableTitle => 'Copia cifrada portátil';

  @override
  String get settingsPortableBody =>
      'Guarda un ZIP en Archivos usando tu clave de recuperación';

  @override
  String get settingsCameraSection => 'Cámara';

  @override
  String get settingsBurstLabel => 'Fotos por ráfaga';

  @override
  String get settingsBurstHelp => 'Mantén pulsado el disparador.';

  @override
  String settingsBurstChoice(int count) {
    return '$count fotos';
  }

  @override
  String get settingsStorageSection => 'Almacenamiento';

  @override
  String get settingsStorageUnreadable => 'No se pudo leer el almacenamiento.';

  @override
  String get settingsStorageCounting => 'Contando capturas…';

  @override
  String get settingsStorageNone => 'Aún no hay capturas en este teléfono.';

  @override
  String settingsStorageSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capturas',
      one: '1 captura',
    );
    return '$_temp0, $size cifrados en este teléfono.';
  }

  @override
  String settingsStorageTrashed(int count, int days) {
    return '$count en Eliminados recientemente, se borran definitivamente tras $days días.';
  }

  @override
  String settingsSizeBytes(int value) {
    return '$value bytes';
  }

  @override
  String settingsSizeKb(String value) {
    return '$value KB';
  }

  @override
  String settingsSizeMb(String value) {
    return '$value MB';
  }

  @override
  String get settingsPlainIcon => 'Usar un icono y un nombre discretos';

  @override
  String get settingsPlainIconBody =>
      'Muestra un icono gris llamado Herramientas en lugar de Quietake. La app puede cerrarse un momento al cambiar. Quietake sigue apareciendo en la lista de apps y en los ajustes del sistema.';

  @override
  String get settingsPlainIconBodyIos =>
      'Muestra otro icono gris. El nombre sigue siendo Quietake y iOS muestra un aviso al cambiar. Quietake sigue apareciendo en la lista de apps y en los ajustes del sistema.';

  @override
  String get settingsPlainIconFailed =>
      'No se pudo cambiar el icono de la app.';

  @override
  String get settingsKeepDeleted => 'Conservar las capturas eliminadas 30 días';

  @override
  String get settingsKeepDeletedBody =>
      'Eliminar mueve primero una captura a Eliminados recientemente. Sigue cifrada.';

  @override
  String get settingsLicenses => 'Licencias';

  @override
  String get settingsShow => 'Mostrar';

  @override
  String get portableTitleRestore => 'Restaurar copia cifrada';

  @override
  String get portableTitleExport => 'Copia portátil';

  @override
  String get portableIntroRestore =>
      'Restaura solo en una bóveda nueva y vacía. Tu clave de recuperación abre el ZIP y las capturas cifradas. No se pueden combinar bibliotecas existentes.';

  @override
  String get portableIntroExport =>
      'Guarda un ZIP cifrado con tus capturas y su organización. Tu clave de recuperación actual lo abre; guárdala por separado. No se incluyen credenciales ni archivos de clave.';

  @override
  String get portableChoose => 'Elegir ZIP de copia';

  @override
  String get portableCheckOnly => 'Solo comprobar la copia';

  @override
  String get portableRestoreButton => 'Restaurar bóveda vacía';

  @override
  String get portableCreateButton => 'Crear ZIP cifrado';

  @override
  String get portableLimitsTitle => 'Límites y almacenamiento de la copia';

  @override
  String get portableLimitsBody =>
      'Hasta 10 000 capturas y 2 GiB por ZIP. La preparación necesita almacenamiento temporal privado. Los originales de la bóveda no se modifican. No se incluyen credenciales ni archivos de clave.';

  @override
  String get portableCancelPrep => 'Cancelar preparación';

  @override
  String get portablePicking => 'Elige un ZIP cifrado en Archivos.';

  @override
  String get portablePickCancelled => 'Selección cancelada.';

  @override
  String get portablePicked =>
      'Copia seleccionada. Introduce su clave de recuperación y un código nuevo.';

  @override
  String get portableCopyFailed =>
      'No se pudo copiar la copia. Revisa el almacenamiento e inténtalo de nuevo.';

  @override
  String get portableStillFinishing =>
      'La copia anterior está terminando. Inténtalo de nuevo en breve.';

  @override
  String get portableNeedKey =>
      'Elige una copia e introduce su clave de recuperación.';

  @override
  String get portableNeedPasscode =>
      'Elige una copia y confirma un código de al menos seis caracteres.';

  @override
  String get portablePreparing => 'Preparando la copia cifrada…';

  @override
  String portableChecking(int done, int total) {
    return 'Comprobando archivos cifrados: $done de $total…';
  }

  @override
  String get portableChecked =>
      'Copia comprobada: cada archivo cifrado y el catálogo se autentican con esta clave. No se restauró nada. Elige el archivo de nuevo para restaurarlo.';

  @override
  String get portableRestored =>
      'Bóveda restaurada. Usa tu código nuevo una vez para activar el desbloqueo biométrico.';

  @override
  String portableExporting(int done, int total) {
    return 'Preparando archivos cifrados: $done de $total…';
  }

  @override
  String get portableSaved =>
      'Copia cifrada guardada. Guarda su clave de recuperación por separado.';

  @override
  String get portableSaveCancelled =>
      'Guardado cancelado. Se conservan los originales de la bóveda.';

  @override
  String get portableBadKey =>
      'Introduce la clave de recuperación guardada para esta copia.';

  @override
  String get portableCancelled =>
      'Cancelado. Se conservan los originales de la bóveda.';

  @override
  String get portableFailed =>
      'No se pudo restaurar ni guardar la copia. Revisa su clave, el archivo, el almacenamiento disponible y el requisito de bóveda vacía.';

  @override
  String get nasTitleRestore => 'Restaurar desde el NAS';

  @override
  String get nasTitleManage => 'Frase de contraseña de la copia';

  @override
  String get nasIntroRestore =>
      'Usa la frase de contraseña de copia que activaste antes en tu NAS. El código corto del teléfono no puede recuperar esta copia. La restauración autentica todos los archivos en una bóveda vacía; no se combina nada. Tu NAS permanece en solo lectura.';

  @override
  String get nasIntroManage =>
      'Protege la recuperación en el NAS con una frase de contraseña fuerte y distinta. Cualquiera que tenga el archivo cifrado puede probar combinaciones sin conexión. Prefiere seis palabras aleatorias; la longitud por sí sola no garantiza la fortaleza. Completa antes una sincronización con el NAS guardado. El NAS debe admitir bloqueo seguro de archivos; de lo contrario no se escribe nada.';

  @override
  String get nasUrlLabel => 'URL de la carpeta WebDAV HTTPS';

  @override
  String get nasUserLabel => 'Usuario del NAS';

  @override
  String get nasPasswordLabel => 'Contraseña del NAS';

  @override
  String get nasPinNew => 'Código local nuevo';

  @override
  String get nasPinCurrent => 'Código local actual';

  @override
  String get nasPinConfirm => 'Confirmar código local nuevo';

  @override
  String get nasPhraseLabel => 'Frase de contraseña de la copia';

  @override
  String get nasPhraseConfirm => 'Confirmar frase de contraseña de la copia';

  @override
  String get nasGenerate => 'Generar seis palabras';

  @override
  String get nasHide => 'Ocultar frase de contraseña';

  @override
  String get nasShow => 'Mostrar frase de contraseña';

  @override
  String get nasWordsCredit =>
      'Palabras: Electronic Frontier Foundation · CC BY 4.0';

  @override
  String get nasWordLicenses => 'Licencias de la lista de palabras';

  @override
  String get nasEnableButton => 'Activar o cambiar la frase de contraseña';

  @override
  String get nasDisableButton =>
      'Desactivar la recuperación con frase de contraseña';

  @override
  String get nasFootRestore =>
      'Hasta 10 000 capturas. Se necesita espacio temporal privado. Después, desbloquea con tu código nuevo. La subida en segundo plano sigue desactivada.';

  @override
  String get nasFootManage =>
      'Esto solo cambia la protección de recuperación. Nunca cambia el código del teléfono ni vuelve a cifrar las capturas. Quitar la recuperación actual no revoca las instantáneas antiguas del servidor.';

  @override
  String get nasGenerateFailed =>
      'No se pudo generar una frase de contraseña. Inténtalo de nuevo.';

  @override
  String get nasConfirmDisableTitle =>
      '¿Desactivar la recuperación con frase de contraseña?';

  @override
  String get nasConfirmSaveTitle =>
      '¿Guardar la frase de contraseña de la copia?';

  @override
  String get nasConfirmDisableBody =>
      'Elimina el archivo de recuperación actual de la carpeta guardada del NAS. Las capturas se conservan. Las instantáneas antiguas del servidor pueden seguir aceptando una frase de contraseña anterior. Conserva tu clave de recuperación independiente.';

  @override
  String get nasConfirmSaveBody =>
      'Crea o reemplaza la recuperación en la carpeta guardada del NAS. Guarda la nueva frase de contraseña por separado. Las instantáneas antiguas del servidor pueden seguir aceptando una frase anterior; esto no cambia la clave de tu bóveda.';

  @override
  String get nasDisableAction => 'Desactivar recuperación';

  @override
  String get nasSaveAction => 'Guardar frase de contraseña';

  @override
  String get nasSeparatePhrase =>
      'Usa una frase de contraseña de copia distinta, no tu código local.';

  @override
  String get nasNeedPasscode =>
      'Elige y confirma un código nuevo de al menos seis caracteres.';

  @override
  String get nasNeedDetails =>
      'Introduce la carpeta, el usuario y la contraseña guardados del NAS.';

  @override
  String get nasMismatch =>
      'Las frases de contraseña de la copia no coinciden.';

  @override
  String get nasCheckingRestore => 'Comprobando la copia cifrada del NAS…';

  @override
  String get nasCheckingSaved =>
      'Comprobando la recuperación guardada del NAS…';

  @override
  String get nasRestoredTitle => 'Bóveda restaurada';

  @override
  String get nasRestoredUnsaved =>
      'No se pudo guardar la conexión con el NAS. Tus capturas están restauradas; vuelve a añadir la conexión en Ajustes para reanudar las copias.';

  @override
  String get nasContinue => 'Continuar';

  @override
  String get nasDisabledDone =>
      'Recuperación con frase de contraseña desactivada. Se conservan las capturas.';

  @override
  String get nasSavedDone =>
      'Frase de contraseña de la copia guardada. Guárdala por separado, junto con tu clave de recuperación.';

  @override
  String get nasWrongCurrent => 'Código actual incorrecto. Inténtalo de nuevo.';

  @override
  String get nasCancelled => 'Cancelado. Se conservan los originales.';

  @override
  String get nasRestoreFailed =>
      'No se pudo restaurar. Revisa la conexión con el NAS, la frase de contraseña de la copia y el requisito de bóveda vacía. Se conservan los originales.';

  @override
  String get nasChangeFailed =>
      'No se pudo cambiar la recuperación. Revisa la copia guardada del NAS, el archivo de recuperación compatible y la compatibilidad del servidor. Sincroniza primero y vuelve a intentarlo. Se conservan los originales.';

  @override
  String get coverChooseTitle => 'Elegir portada';

  @override
  String get coverEmpty =>
      'Etiqueta primero algunas capturas y luego elige una como portada.';

  @override
  String get coverUse => 'Usar esta captura como portada';

  @override
  String get restoreGateFailed =>
      'No se pudo terminar la restauración interrumpida de la copia. Los archivos cifrados preparados se conservan. Revisa el almacenamiento disponible y vuelve a intentarlo.';

  @override
  String get restoreGateRetry => 'Reintentar restauración';

  @override
  String get settingsCheckRecovery => 'Comprobar mi clave de recuperación';

  @override
  String get recoveryCheckTitle => 'Comprobar clave de recuperación';

  @override
  String get recoveryCheckIntro =>
      'Escribe la clave de recuperación que guardaste en otro sitio. Se compara en este teléfono y nunca se guarda.';

  @override
  String get recoveryCheckAction => 'Comprobar';

  @override
  String get recoveryCheckClose => 'Cerrar';

  @override
  String get recoveryCheckNever => 'Nunca comprobada.';

  @override
  String recoveryCheckLast(String date) {
    return 'Última coincidencia: $date.';
  }

  @override
  String recoveryCheckDue(String date) {
    return 'Última coincidencia: $date. Vuelve a comprobarla cada pocos meses.';
  }

  @override
  String get recoveryCheckMatch =>
      'Coincide con la clave de recuperación de tu bóveda.';

  @override
  String get recoveryCheckMismatch =>
      'Esta clave no coincide con esta bóveda. Revisa dónde la guardaste e inténtalo de nuevo.';

  @override
  String get recoveryCheckInvalid =>
      'No es una clave de recuperación válida. Comprueba si faltan caracteres o sobran.';

  @override
  String get redactTitle => 'Ocultar partes de la foto';

  @override
  String get redactUndo => 'Deshacer la última zona';

  @override
  String get redactDone => 'Listo';

  @override
  String redactStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se ocultarán $count zonas.',
      one: 'Se ocultará 1 zona.',
      zero: 'Arrastra sobre la foto para ocultar una zona.',
    );
    return '$_temp0';
  }

  @override
  String get redactFailed => 'No se pudo abrir esta foto para editarla.';

  @override
  String get shareRedactButton => 'Ocultar partes de esta foto…';

  @override
  String shareRedactEdit(int count) {
    return 'Zonas ocultas: $count. Cambiar…';
  }

  @override
  String get shareRedactNote =>
      'La copia compartida será un PNG con esas zonas pixeladas y sin metadatos. El original no cambia en tu bóveda.';

  @override
  String redactCell(int row, int column) {
    return 'Fila $row, columna $column';
  }

  @override
  String get redactSections => 'O oculta una sección de la foto';

  @override
  String get settingsRenameRemote =>
      'Dar nombres aleatorios a los archivos del NAS';

  @override
  String get settingsRenameRemoteNone =>
      'Ningún archivo del NAS necesita un nombre nuevo.';

  @override
  String get settingsRenameRemoteTitle => '¿Renombrar los archivos del NAS?';

  @override
  String settingsRenameRemoteBody(int count) {
    return '$count archivos cifrados del NAS reciben nombres aleatorios, así que sus nombres y horas ya no se ven allí. Actualiza antes Quietake en los demás teléfonos: las versiones antiguas no encuentran los archivos renombrados. Tus originales se quedan en este teléfono.';
  }

  @override
  String get settingsRenameRemoteAction => 'Renombrar';

  @override
  String settingsRenameRemoteDone(int count) {
    return 'Se renombraron $count archivos en el NAS.';
  }

  @override
  String get settingsRenameRemoteFailed =>
      'El cambio de nombres se detuvo. Vuelve a ejecutarlo para continuar. No se perdió nada.';

  @override
  String get shareEncryptedTitle => 'Cifrar con una contraseña';

  @override
  String get shareEncryptedBody =>
      'Las copias van en un solo archivo que solo se abre con una contraseña. Quietake la muestra una vez. Envíala por una vía distinta a la del archivo.';

  @override
  String get sharePassphraseTitle => 'Contraseña de este envío';

  @override
  String get sharePassphraseBody =>
      'Anótala o envíala por separado ahora. Quietake no la guarda y no puede mostrarla otra vez.';

  @override
  String get sharePassphraseContinue => 'Elegir app';
}
