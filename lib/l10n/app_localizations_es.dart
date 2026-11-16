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
}
