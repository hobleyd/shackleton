import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/preview.dart';
import 'package:shackleton/providers/selected_entities.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../database/app_database.dart';
import '../misc/utils.dart';
import '../models/entity.dart';
import '../models/tag.dart';

class NavigationTags extends ConsumerWidget {
  const NavigationTags({Key? key,}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, watch, child) {
      var fileTagsAsync = ref.watch(fileTagsRepositoryProvider(AppDatabase()));
      return fileTagsAsync.when(error: (error, stackTrace) {
        return Text(getHomeFolder(), style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (List<Tag> tags) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Tags', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
              ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                        onTap: () => _selectTag(ref, tags[index]),
                        child: Text(tags[index].tag, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall));
                  },
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true)
            ],
          ),
        );
      });
    });
  }

  Future<void> _selectTag(WidgetRef ref, Tag tag) async {
    var db = AppDatabase();
    final List<Map<String, dynamic>> rows = await db.rawQuery(
        'select * from files where id in (select fileId from file_tags, tags where tags.id = file_tags.tagId and tags.tag = ?);',
        [tag.tag]);
    final Set<Entity> entitySet = rows.map((e) => Entity.fromMap(e)).toSet();
    ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier).addAll(entitySet.map((e) => FileOfInterest(entity: File(e.path))).toSet());
  }
}