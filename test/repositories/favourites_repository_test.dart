import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/favourite.dart';
import 'package:shackleton/repositories/favourites_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() {
    container.dispose();
  });

  group('FavouritesRepository', () {
    test('initial state seeds root and home favourites', () async {
      final favourites = await container.read(favouritesRepositoryProvider.future);
      expect(favourites.length, 2);
      expect(favourites.any((f) => f.path == '/'), isTrue);
    });

    test('insertFavourite adds a new entry', () async {
      await container.read(favouritesRepositoryProvider.future);
      final repo = container.read(favouritesRepositoryProvider.notifier);

      final newFav = Favourite(path: '/custom/path', name: 'Custom', sortOrder: 10);
      await repo.insertFavourite(newFav);

      final favourites = await repo.getFavourites();
      expect(favourites.any((f) => f.path == '/custom/path'), isTrue);
    });

    test('inserting a duplicate path does not create a new row', () async {
      await container.read(favouritesRepositoryProvider.future);
      final repo = container.read(favouritesRepositoryProvider.notifier);

      final fav = Favourite(path: '/unique', name: 'One', sortOrder: 5);
      await repo.insertFavourite(fav);
      await repo.insertFavourite(fav);

      final favourites = await repo.getFavourites();
      expect(favourites.where((f) => f.path == '/unique').length, 1);
    });

    test('getFavourites returns entries sorted by sort_order', () async {
      await container.read(favouritesRepositoryProvider.future);
      final repo = container.read(favouritesRepositoryProvider.notifier);

      await repo.insertFavourite(Favourite(path: '/z', name: 'Z', sortOrder: 99));
      await repo.insertFavourite(Favourite(path: '/a', name: 'A', sortOrder: 3));

      final favourites = await repo.getFavourites();
      final orders = favourites.map((f) => f.sortOrder).toList();
      expect(orders, equals([...orders]..sort()), reason: 'should be sorted ascending');
    });
  });
}
