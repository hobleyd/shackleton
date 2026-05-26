import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/misc/utils.dart';
import 'package:shackleton/models/favourite.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_favourites_repository.dart';

part 'favourites_repository.g.dart';

@riverpod
class FavouritesRepository extends _$FavouritesRepository implements IFavouritesRepository {
  static const String tableName = 'favourites';

  late final AppDatabase _db;

  @override
  Future<List<Favourite>> build() async {
    ref.keepAlive();
    _db = ref.read(appDatabaseProvider.notifier);
    return _getFavourites();
  }

  @override
  Future<List<Favourite>> getFavourites() => _getFavourites();

  @override
  Future<int> insertFavourite(Favourite favourite) async {
    int rowid = -1;
    List<Map<String, dynamic>> result = await _db.query('favourites', where: 'path = ?', whereArgs: [favourite.path]);
    if (result.isNotEmpty) {
      if (result.first['sort_order'] != favourite.sortOrder) {
        rowid = await _db.updateTable('favourites', { 'sort_order' : favourite.sortOrder }, 'path = ?', [favourite.path]);
      }
      rowid = result.first['id'];
    } else {
      rowid = await _db.insert('favourites', favourite.toMap());
    }

    updateFavourites();
    return rowid;
  }

  @override
  Future<void> updateFavourites() async {
    final result = await AsyncValue.guard(() => _getFavourites());
    if (ref.mounted) state = result;
  }

  Future<List<Favourite>> _getFavourites() async {
    List<Map<String, dynamic>> results = await _db.query('favourites', orderBy: 'sort_order');
    if (results.isEmpty) {
      Favourite root = Favourite(path: '/', name: 'My Computer', sortOrder: 1);
      Favourite home = Favourite(path: getHomeFolder(), sortOrder: 2);
      // Insert directly to avoid triggering state updates during build.
      root.id = await _db.insert('favourites', root.toMap());
      home.id = await _db.insert('favourites', home.toMap());
      return [root, home];
    }
    return results.map((row) => Favourite.fromMap(row)).toList();
  }

}