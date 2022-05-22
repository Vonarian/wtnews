import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void createShortcut(String path, String pathLink, String? description) {
  final shellLink = ShellLink.createInstance();
  final lpPath = path.toNativeUtf16();
  final lpPathLink = pathLink.toNativeUtf16();
  final lpDescription = description?.toNativeUtf16() ?? nullptr;
  final ptrIIDIPersistFile = convertToCLSID(IID_IPersistFile);
  final ppf = calloc<COMObject>();

  try {
    shellLink.SetPath(lpPath);
    if (description != null) shellLink.SetDescription(lpDescription);

    final hr = shellLink.QueryInterface(ptrIIDIPersistFile, ppf.cast());
    if (SUCCEEDED(hr)) {
      IPersistFile(ppf)
        ..Save(lpPathLink, TRUE)
        ..Release();
    }
    shellLink.Release();
  } finally {
    free(lpPath);
    free(lpPathLink);
    if (lpDescription != nullptr) free(lpDescription);
    free(ptrIIDIPersistFile);
    free(ppf);
  }
}
