import 'package:florien/core/l10n/app_language.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the phone language when it is supported', () {
    expect(
      resolveAppLanguage(savedOverride: null, deviceLocale: const Locale('de')),
      'de',
    );
    expect(
      resolveAppLanguage(
        savedOverride: null,
        deviceLocale: const Locale('pt', 'BR'),
      ),
      'pt',
    );
    expect(
      resolveAppLanguage(
        savedOverride: null,
        deviceLocale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      ),
      'zh',
    );
  });

  test('falls back to English when the phone language is unsupported', () {
    expect(
      resolveAppLanguage(savedOverride: null, deviceLocale: const Locale('hi')),
      'en',
    );
  });

  test('keeps a manual override saved on the phone', () {
    expect(
      resolveAppLanguage(savedOverride: 'tr', deviceLocale: const Locale('en')),
      'tr',
    );
    expect(
      resolveAppLanguage(savedOverride: 'ja', deviceLocale: const Locale('fr')),
      'ja',
    );
  });

  test('keeps existing Turkish copy and English premium strings', () {
    expect(const S('tr').choosePlan, 'Planını seç');
    expect(const S('en').choosePlan, 'Choose your plan');
    expect(const S('tr')('Ayarlar'), 'Ayarlar');
    expect(const S('en')('Ayarlar'), 'Settings');
    expect(const S('de')('Ayarlar'), 'Einstellungen');
    expect(const S('en')('Hazır rutinler'), 'Ready-made routines');
    expect(const S('en')('Tarih seç'), 'Choose a date');
    expect(const S('en')('PLANLANDI'), 'PLANNED');
    expect(const S('en')('TAMAMLANDI'), 'DONE');
    expect(const S('en')('Tarihe git'), 'Go to date');
    expect(
      const S('en')('Son ana kadar erteliyorum'),
      'I put it off until the last minute',
    );
    expect(const S('en')('Premium ol'), 'Go Premium');
    expect(const S('en')('Küçük bir adımla başla'), 'Start with a small step');
    expect(const S('en')('Liste adı'), 'List name');
    expect(const S('en')('Temizle'), 'Clear');
    expect(const S('en')('Yinelemek'), 'Repeat');
    expect(const S('en')('Sesli planlama'), 'Voice planning');
    expect(const S('en')('Odak'), 'Focus');
    expect(const S('en')('Sohbet'), 'Chat');
    expect(const S('tr').premiumDailyPrice('₺3,33'), 'Günde yaklaşık ₺3,33');
    expect(const S('en').premiumDailyPrice('{price}'), 'About {price} per day');
  });

  test('onboarding survey answers have English translations', () {
    const answers = [
      'Yapacaklarım kafamda birbirine giriyor',
      'Nereden başlayacağımı bulamıyorum',
      'Bir şeye başlayıp başka bir şeye geçiyorum',
      'Zamanın nasıl geçtiğini anlamıyorum',
      'Bunlardan birkaçı birden oluyor',
      'Gözümde büyütüyorum',
      'Doğru zamanı bekliyorum',
      'Başka küçük işlerle oyalanıyorum',
      'Son ana kadar erteliyorum',
      'Duruma göre değişiyor',
      'DEHB tanısı aldım',
      'DEHB olabileceğimi düşünüyorum',
      'Başka bir nöroçeşitliliğim var',
      'Kendimi bunlardan biriyle tanımlamıyorum',
      'Emin değilim',
      'Birkaç gün iyi gidiyor, sonra bırakıyorum',
      'Daha başlarken gözümde büyüyor',
      'Bir şey aksayınca tamamen vazgeçiyorum',
      'Planı unutup akışına bırakıyorum',
      'Bir işin ne kadar süreceğini kestiremiyorum',
      'Saate baksam da yine yetişemiyorum',
      'Bir işe dalınca diğerlerini unutuyorum',
      'Günün nasıl bittiğini anlamıyorum',
      'Kendime yükleniyorum',
      'Her şeye baştan başlamam gerektiğini düşünüyorum',
      'Plan yapmayı bırakıyorum',
      'Nasıl toparlanacağımı bulamıyorum',
      'Nereden başlayacağımı bilmek',
      'Kafamı biraz toparlamak',
      'Günü daha kolay geçirmek',
      'Başladığım şeyi sürdürebilmek',
      'Henüz bilmiyorum',
    ];
    for (final answer in answers) {
      expect(const S('en')(answer), isNot(answer), reason: answer);
    }
  });
}
