import '../../models/favourite.dart';

abstract class IFavouritesRepository {
  Future<List<Favourite>> getFavourites();
  Future<int> insertFavourite(Favourite favourite);
  Future<void> updateFavourites();
}
