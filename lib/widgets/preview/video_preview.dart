import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class ShackletonVideoPlayer extends ConsumerStatefulWidget {
  final String path;

  const ShackletonVideoPlayer({super.key, required this.path});

  @override
  ConsumerState<ShackletonVideoPlayer> createState() => _ShackletonVideoPlayer();
}

class _ShackletonVideoPlayer extends ConsumerState<ShackletonVideoPlayer> {
  late final _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void dispose() {
    _player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(controller: _controller);
  }

  @override
  void initState() {
    super.initState();
    _player.open(Media(widget.path), play: false);
  }
}
