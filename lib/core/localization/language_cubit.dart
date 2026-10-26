import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';

class LanguageState extends Equatable {
  final Locale locale;

  const LanguageState([this.locale = const Locale('ar')]);

  bool get isArabic => locale.languageCode == 'ar';
  bool get isEnglish => locale.languageCode == 'en';

  @override
  List<Object?> get props => [locale];
}

class LanguageCubit extends Cubit<LanguageState> {
  final TokenStorage _tokenStorage;

  LanguageCubit({
    required TokenStorage tokenStorage,
    Locale? initialLocale,
  })  : _tokenStorage = tokenStorage,
        super(LanguageState(initialLocale ?? const Locale('ar')));

  /// The initial public release is Arabic-only.  A previous English preference
  /// is migrated to Arabic so a partially translated interface is never shown.
  Future<void> loadLanguage() async {
    try {
      final savedCode = await _tokenStorage.getLanguage();
      if (savedCode != 'ar') {
        await _tokenStorage.saveLanguage('ar');
      }
      emit(const LanguageState(Locale('ar')));
    } catch (_) {
      emit(const LanguageState(Locale('ar')));
    }
  }

  /// Persists the supported release locale. English remains unavailable until
  /// every participant-facing surface has a verified translation.
  Future<void> setLanguage(Locale newLocale) async {
    const code = 'ar';
    emit(const LanguageState(Locale(code)));
    try {
      await _tokenStorage.saveLanguage(code);
    } catch (_) {
      // Best-effort local persistence; memory state is updated immediately.
    }
  }

  /// Kept for backwards-compatible callers; the release locale stays Arabic.
  Future<void> toggleLanguage() async {
    await setLanguage(const Locale('ar'));
  }
}
