import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/error.dart';
import '../providers/notification.dart';

class ShackletonNotifications extends ConsumerWidget {
  const ShackletonNotifications({super.key, require});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ItemScrollController scrollController = ItemScrollController();
    final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

    List<Error> errors = ref.watch(notificationProvider);

    return errors.isNotEmpty
        ? Container(
            color: Colors.pink[50],
            width: 300,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      itemCount: errors.length,
                      itemBuilder: (context, index) {
                        return Text(
                          errors[index].message,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.left,
                        );
                      },
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                    ),
                  ),
                ),
                Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 3),
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: ElevatedButton(
                    onPressed: () => ref.read(notificationProvider.notifier).clear(),
                    child: Text('Clear', style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
              ]),
            ),
          )
        : SizedBox(width: 1);
  }
}
