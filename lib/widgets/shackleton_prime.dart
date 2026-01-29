import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'shackleton.dart';

class ShackletonPrime extends ConsumerWidget {
  const ShackletonPrime({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Open the Database here. Need to ensure it is open before we proceed.
    var asyncDb = ref.watch(appDatabaseProvider);

    return asyncDb.when(error: (error, stackTrace) {
      return const Text("It's time to panic; we can't open the database!");
    }, loading: () {
      return const Center(child: CircularProgressIndicator());
    }, data: (var db) {
      return Scaffold(
        appBar: null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Shackleton(),
          ),
        ),
      );
    });
  }
}
