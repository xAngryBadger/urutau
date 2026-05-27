import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadFileBytes(List<int> bytes, String fileName) {
  final jsBytes = Uint8List.fromList(bytes).buffer.toJS;
  final blobParts = <web.BlobPart>[jsBytes].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
