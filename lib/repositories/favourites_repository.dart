import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/misc/utils.dart';
import 'package:shackleton/models/favourite.dart';

import '../database/app_database.dart';

part 'favourites_repository.g.dart';

@riverpod
class FavouritesRepository extends _$FavouritesRepository {
  late AppDatabase _database;

  static const String tableName = 'favourites';
  static const String createFavourites = '''
        create table if not exists favourites(
          id integer primary key,
          path text not null,
          name text not null,
          sort_order int not null,
          unique (path) on conflict ignore);
          ''';

  static const String createFavouritesIndex = 'create index ${tableName}_idx on $tableName(path);';

  @override
  Future<List<Favourite>> build() async {
    _database = AppDatabase();

    return _getFavourites();
  }

  Future<int> insertFavourite(Favourite favourite) async {
    int rowid = -1;
    List<Map<String, dynamic>> result = await _database.query('favourites', where: 'path = ?', whereArgs: [favourite.path]);
    if (result.isNotEmpty) {
      if (result.first['sort_order'] != favourite.sortOrder) {
        rowid = await _database.update('favourites', { 'sort_order' : favourite.sortOrder }, 'path = ?', [favourite.path]);
      }
      rowid = result.first['id'];
    } else {
      rowid = await _database.insert('favourites', favourite.toMap());
    }

    updateFavourites();
    return rowid;
  }

  Future<void> updateFavourites() async {
    state = await AsyncValue.guard(() => _getFavourites());
  }

  Future<List<Favourite>> _getFavourites() async {
    List<Map<String, dynamic>> results = await _database.query('favourites', orderBy: 'sort_order');
    if (results.isEmpty) {
      Favourite root = Favourite(path: '/', name: 'My Computer', sortOrder: 1);
      Favourite home = Favourite(path: getHomeFolder(), sortOrder: 2);
      root.id = await insertFavourite(root);
      home.id = await insertFavourite(home);
      return [root, home];
    }
    return results.map((row) => Favourite.fromMap(row)).toList();
  }

}