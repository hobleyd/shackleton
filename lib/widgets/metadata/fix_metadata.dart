import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/exif.dart';
import 'package:shackleton/providers/metadata.dart';

import '../../models/file_of_interest.dart';

class FixMetadata extends ConsumerStatefulWidget {
  final FileOfInterest file;

  const FixMetadata({super.key, required this.file, });

  @override
  ConsumerState<FixMetadata> createState() => _FixMetadata();
}

class _FixMetadata extends ConsumerState<FixMetadata> {
  late bool fixedExifTags;

  @override
  Widget build(BuildContext context,) {
    Map<String, ({ String orig, String reset })> exifData = ref.watch(exifProvider(widget.file.path));
    List<String> exifTags = exifData.keys.toList();
    exifTags.sort();

    return Scaffold(
        appBar: AppBar(
          elevation: 2,
          shadowColor: Theme.of(context).shadowColor,
          title: Text('Fix Metadata for file', style: Theme.of(context).textTheme.labelSmall),
        ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text('exif tag...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text('(Corrupted) data...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                    ),
                    if (fixedExifTags) ... [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text('(Fixed) data...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                    const SizedBox(width: 10.0),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: ListView.builder(
                            itemCount: exifTags.length,
                            itemBuilder: (context, index) {
                              TextEditingController source = TextEditingController();
                              source.text = exifTags[index];
                              return InkWell(
                                  onTap: () => {},
                                  onDoubleTap: () => {},
                                  child: Container(
                                    //color: entity.willImport ? Colors.lime : Colors.redAccent,
                                    padding: const EdgeInsets.only(left: 5.0),
                                    child: TextField(
                                        autofocus: true,
                                        controller: source,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.text,
                                        maxLines: 1,
                                        readOnly: true,
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ));
                            },
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            shrinkWrap: true),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        child: ListView.builder(
                            itemCount: exifTags.length,
                            itemBuilder: (context, index) {
                              TextEditingController source = TextEditingController();
                              source.text = fixedExifTags ? exifData[exifTags[index]]!.reset : exifData[exifTags[index]]!.orig;
                              return InkWell(
                                  onTap: () => {},
                                  onDoubleTap: () => {},
                                  child: Container(
                                    color: exifData[exifTags[index]]!.orig == exifData[exifTags[index]]!.reset ? Colors.lime : Colors.redAccent,
                                    padding: const EdgeInsets.only(left: 5.0),
                                    child: TextField(
                                        autofocus: true,
                                        controller: source,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.text,
                                        maxLines: 1,
                                        readOnly: true,
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ));
                            },
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            shrinkWrap: true),
                      ),
                      if (fixedExifTags) ...[
                        const SizedBox(width: 48),
                        Expanded(
                          child: ListView.builder(
                              itemCount: exifTags.length,
                              itemBuilder: (context, index) {
                                TextEditingController source = TextEditingController();
                                source.text = exifData[exifTags[index]]!.orig;
                                return InkWell(
                                    onTap: () => {},
                                    onDoubleTap: () => {},
                                    child: Container(
                                      color: exifData[exifTags[index]]!.orig == exifData[exifTags[index]]!.reset ? Colors.lime : Colors.redAccent,
                                      padding: const EdgeInsets.only(left: 5.0),
                                      child: TextField(
                                          autofocus: true,
                                          controller: source,
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.text,
                                          maxLines: 1,
                                          readOnly: true,
                                          style: Theme.of(context).textTheme.bodySmall),
                                    ));
                              },
                              physics: const NeverScrollableScrollPhysics(),
                              scrollDirection: Axis.vertical,
                              shrinkWrap: true),
                        ),
                      ],
                      const SizedBox(width: 10.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 10.0),
                    const Spacer(),
                    if (!fixedExifTags)
                        ElevatedButton(
                          onPressed: () => _fixMetadata(),
                          child: Text('Fix Metadata', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                        ),
                    if (fixedExifTags) ...[
                      ElevatedButton(
                        onPressed: () => _renameOriginal(),
                        child: Text('Reject update', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _deleteOriginal(),
                        child: Text('Accept update', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(width: 10.0),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fixedExifTags = false;
  }

  void _deleteOriginal() {
    FileOfInterest foi = FileOfInterest(entity: File('${widget.file.path}_original'));
    foi.delete();
    ref.read(metadataProvider(widget.file).notifier).saveMetadata(updateFile: true);

    setState(() {
      fixedExifTags = false;
    });

    Navigator.of(context, rootNavigator: true).maybePop(context);
  }

  void _fixMetadata() async {
    bool fixed = await ref.read(exifProvider(widget.file.path).notifier).fixMetadata(widget.file.path);
    setState(() {
      fixedExifTags = fixed;
    });
  }

  void _renameOriginal() {
    File original = File('${widget.file.path}_original');
    if (original.existsSync()) {
      widget.file.delete();
      original.rename(widget.file.path);
    }
  }
}