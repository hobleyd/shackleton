import 'package:Shackleton/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'notifiers/file_cache.dart';
import 'notifiers/folder.dart';
import 'theme/theme.dart';
import 'widgets/shackleton.dart';

void main() {
  runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider<Folder>(create: (_) => Folder()),
        ChangeNotifierProvider<FileCache>(create: (_) => FileCache()),
      ],
      child: MaterialApp(title: 'Shackleton', home: const Shackleton(), theme: ShackletonTheme.normal,
      )
  ));
}