import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/folder_path.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../misc/utils.dart';
import '../models/favourite.dart';
import '../repositories/favourites_repository.dart';

class NavigationFavourites extends ConsumerStatefulWidget {
  const NavigationFavourites({Key? key,}) : super(key: key);

  @override
  ConsumerState<NavigationFavourites> createState() => _NavigationFavourites();
}

class _NavigationFavourites extends ConsumerState<NavigationFavourites> {
  List<String> hoverPaths = [];

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      var favouritesAsync = ref.watch(favouritesRepositoryProvider);
      return favouritesAsync.when(error: (error, stackTrace) {
        return Text(getHomeFolder(), style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (List<Favourite> favourites) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('Favourites', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            ListView.builder(
                itemCount: favourites.length,
                itemBuilder: (context, index) {
                  return DropRegion(
                    formats: Formats.standardFormats,
                    hitTestBehavior: HitTestBehavior.opaque,
                    onDropOver: (event) {
                      return _onDropOver(event);
                    },
                    onDropEnter: (event) {
                      setState(() {
                        hoverPaths.add(favourites[index].path);
                      });
                    },
                    onDropLeave: (event) {
                      setState(() {
                        hoverPaths.remove(favourites[index].path);
                      });
                    },
                    onPerformDrop: (event) => _onPerformDrop(ref, event, favourites, index),
                    child: Material(
                      color: hoverPaths.contains(favourites[index].path) ? const Color.fromRGBO(217, 217, 217, 100) : Colors.transparent,
                      child: InkWell(
                        onTap: () => ref.read(folderPathProvider.notifier).setFolder(favourites[index].directory),
                        child: DragItemWidget(
                          allowedOperations: () => [DropOperation.move],
                          canAddItemToExistingSession: true,
                          dragItemProvider: (request) async {
                            final item = DragItem();
                            item.add(Formats.fileUri(favourites[index].uri));
                            item.add(Formats.htmlText.lazy(() => favourites[index].path));
                            return item;
                          },
                          child: DraggableWidget(
                              child: Text(
                            favourites[index].name!,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          )),
                        ),
                      ),
                    ),
                  );
                },
                scrollDirection: Axis.vertical,
                shrinkWrap: true)
          ],
        );
      });
    });
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final item = event.session.items.first;
    if (item.canProvide(Formats.fileUri)) {
      return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
    }
    return DropOperation.none;
  }

  Future<void> _onPerformDrop(WidgetRef ref, PerformDropEvent event, List<Favourite> favourites, index) async {
    if (event.session.items.isNotEmpty) {
      var item = event.session.items.first;
      final reader = item.dataReader!;
      if (reader.canProvide(Formats.fileUri)) {
        reader.getValue(Formats.fileUri, (uri) async {
          if (uri != null) {
            Favourite newFave = Favourite(path: Uri.decodeComponent(uri.path), sortOrder: index+1);
            favourites.insert(newFave.sortOrder, newFave);
            for (int i = 0; i < favourites.length; i++) {
              favourites[i].sortOrder = i;
              ref.read(favouritesRepositoryProvider.notifier).insertFavourite(favourites[i]);
            }
          }
        });
      }
    }
  }
}