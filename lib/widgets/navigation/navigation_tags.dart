import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../misc/utils.dart';
import '../../models/tag.dart';
import '../../providers/contents/grid_contents.dart';
import '../../repositories/file_tags_repository.dart';

class NavigationTags extends ConsumerWidget {
  const NavigationTags({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, watch, child) {
      final fileTagsAsync = ref.watch(fileTagsRepositoryProvider);
      return fileTagsAsync.when(
        error: (error, stackTrace) =>
            Text(getHomeFolder(), style: Theme.of(context).textTheme.bodySmall),
        loading: () => const CircularProgressIndicator(),
        data: (List<Tag> tags) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Tags',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall),
              ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) => InkWell(
                      onTap: () => _selectTag(ref, tags[index]),
                      child: Text(tags[index].tag,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall)),
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _selectTag(WidgetRef ref, Tag tag) async {
    final files = await ref.read(fileTagsRepositoryProvider.notifier).getFilesForTag(tag);
    ref.read(gridContentsProvider.notifier).replaceAll(files.toSet());
  }
}
