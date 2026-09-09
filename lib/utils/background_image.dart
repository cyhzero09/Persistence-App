import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 处理选中的背景图字节：
/// - 非 Web：image_picker 已按 maxWidth/imageQuality 压缩，直接返回
/// - Web：picker 忽略压缩参数，手动降采样到宽 1280px 并编码为 PNG，
///   避免 base64 存 localStorage 超出配额
Future<Uint8List?> processPickedImage(Uint8List rawBytes) async {
  if (!kIsWeb) return rawBytes;
  const targetWidth = 1280;
  final buffer = await ui.ImmutableBuffer.fromUint8List(rawBytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final codec = await descriptor.instantiateCodec(
    targetWidth: descriptor.width > targetWidth ? targetWidth : null,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  return data?.buffer.asUint8List();
}
