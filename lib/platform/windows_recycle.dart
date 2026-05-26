import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

bool recycleFile(String file) {
  final hwnd = GetActiveWindow();
  final pFrom = [file].toWideCharArray();
  final lpFileOp = calloc<SHFILEOPSTRUCT>()
    ..ref.hwnd = hwnd
    ..ref.wFunc = FO_DELETE
    ..ref.pFrom = pFrom
    ..ref.pTo = nullptr
    ..ref.fFlags = FOF_ALLOWUNDO;

  try {
    final result = SHFileOperation(lpFileOp);
    return result == 0;
  } finally {
    free(pFrom);
    free(lpFileOp);
  }
}
