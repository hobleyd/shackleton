import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/file_of_interest.dart';

class VideoPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;

  const VideoPreview({super.key, required this.entity, required this.isSelected,});

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreview();
}

class _VideoPreview extends ConsumerState<VideoPreview> {
  late final _player = Player();
  late final VideoController _controller = VideoController(_player);

  get entityPreview  => widget.entity;
  get isSelected => widget.isSelected;

  @override
  void dispose() {
    _player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color background = isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            Expanded(
                child: Container(
                    alignment: Alignment.center,
                    color: background,
                    child: Text(entityPreview.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall,),
                ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            color: background,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Video(controller: _controller),
          ),
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    _player.open(Media(widget.entity.path), play: false);
  }
}
