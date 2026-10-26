import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/localization/language_cubit.dart';

class _FakeTokenStorage extends TokenStorage {
  String? _savedLanguage;

  _FakeTokenStorage([this._savedLanguage]);

  @override
  Future<String?> getLanguage() async => _savedLanguage;

  @override
  Future<void> saveLanguage(String languageCode) async {
    _savedLanguage = languageCode;
  }

  @override
  Future<void> clearLanguage() async {
    _savedLanguage = null;
  }
}

void main() {
  group('LanguageCubit', () {
    test('initial state defaults to Arabic (Locale("ar"))', () {
      final storage = _FakeTokenStorage();
      final cubit = LanguageCubit(tokenStorage: storage);

      expect(cubit.state.locale, const Locale('ar'));
      expect(cubit.state.isArabic, isTrue);
      expect(cubit.state.isEnglish, isFalse);
    });

    test('loadLanguage migrates a prior English preference to Arabic',
        () async {
      final storage = _FakeTokenStorage('en');
      final cubit = LanguageCubit(tokenStorage: storage);

      await cubit.loadLanguage();

      expect(cubit.state.locale, const Locale('ar'));
      expect(cubit.state.isArabic, isTrue);
      expect(await storage.getLanguage(), 'ar');
    });

    test(
        'loadLanguage defaults to Arabic when stored language is null or unknown',
        () async {
      final storage = _FakeTokenStorage(null);
      final cubit = LanguageCubit(tokenStorage: storage);

      await cubit.loadLanguage();

      expect(cubit.state.locale, const Locale('ar'));
      expect(cubit.state.isArabic, isTrue);
    });

    test('setLanguage keeps the release locale Arabic', () async {
      final storage = _FakeTokenStorage();
      final cubit = LanguageCubit(tokenStorage: storage);

      await cubit.setLanguage(const Locale('en'));

      expect(cubit.state.locale, const Locale('ar'));
      expect(await storage.getLanguage(), 'ar');

      await cubit.setLanguage(const Locale('ar'));

      expect(cubit.state.locale, const Locale('ar'));
      expect(await storage.getLanguage(), 'ar');
    });

    test('toggleLanguage keeps Arabic while English is not released', () async {
      final storage = _FakeTokenStorage();
      final cubit = LanguageCubit(tokenStorage: storage);

      expect(cubit.state.isArabic, isTrue);

      await cubit.toggleLanguage();
      expect(cubit.state.locale, const Locale('ar'));
      expect(await storage.getLanguage(), 'ar');

      await cubit.toggleLanguage();
      expect(cubit.state.locale, const Locale('ar'));
      expect(await storage.getLanguage(), 'ar');
    });
  });
}
