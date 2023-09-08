import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';

void main() {
  test('validate isValidMoveLocation', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('/var/log'));

    expect(foi.isValidMoveLocation('/a/b'), false); // '/a' is not a directory;
    expect(foi.isValidMoveLocation('/var/log/cups'), false); // Can't move /a/b/c to /a/b/c/d;
    expect(foi.isValidMoveLocation('/var/log/'), false); // Can't move /a/b/c to /a/b/c;
  });
}