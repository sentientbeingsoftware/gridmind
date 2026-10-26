import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gridmind/services/app_persistence_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppPersistenceService Favorites', () {
    test('getFavorites returns empty set when no favorites saved', () async {
      final service = AppPersistenceService();
      final favs = await service.getFavorites();
      expect(favs, isEmpty);
    });

    test('toggleFavorite adds a game to favorites', () async {
      final service = AppPersistenceService();
      final updated = await service.toggleFavorite('simon');
      expect(updated, contains('simon'));
      final stored = await service.getFavorites();
      expect(stored, contains('simon'));
    });

    test('toggleFavorite removes a game that is already favorited', () async {
      final service = AppPersistenceService();
      await service.toggleFavorite('simon');
      final updated = await service.toggleFavorite('simon');
      expect(updated, isNot(contains('simon')));
      final stored = await service.getFavorites();
      expect(stored, isEmpty);
    });

    test('toggleFavorite can favorite multiple games', () async {
      final service = AppPersistenceService();
      await service.toggleFavorite('simon');
      final updated = await service.toggleFavorite('collapse');
      expect(updated, containsAll(['simon', 'collapse']));
      final stored = await service.getFavorites();
      expect(stored.length, 2);
    });

    test('setFavorites overwrites the entire favorites set', () async {
      final service = AppPersistenceService();
      await service.toggleFavorite('simon');
      await service.setFavorites({'wordsearch', 'color_flood'});
      final stored = await service.getFavorites();
      expect(stored, containsAll(['wordsearch', 'color_flood']));
      expect(stored.length, 2);
    });
  });
}
