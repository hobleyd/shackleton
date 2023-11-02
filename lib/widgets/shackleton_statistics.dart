import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/models/app_statistics.dart';

import '../repositories/app_statistics_repository.dart';

class ShackletonStatistics extends ConsumerWidget {
  ShackletonStatistics({Key? key,}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Clear DB Cache
    // DB Statistics
    return Consumer(builder: (context, watch, child) {
      var appStatistics = ref.watch(appStatisticsRepositoryProvider);
      return appStatistics.when(error: (error, stackTrace) {
        return Text('Failed to get statistics.', style: Theme
            .of(context)
            .textTheme
            .bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (AppStatistics appStatistics) {
        return Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: 120, child: Text('Tag Count: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall)),
                    const SizedBox(width: 15),
                    SizedBox(width: 120, child: Text('${appStatistics.tagCount}', style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: 120, child: Text('File Count: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall),),
                    const SizedBox(width: 15),
                    SizedBox(width: 120, child: Text('${appStatistics.fileCount} ', style: Theme.of(context).textTheme.bodySmall),),
                  ],
                ),
              ],
            ),
        );
      });
    });
  }
}