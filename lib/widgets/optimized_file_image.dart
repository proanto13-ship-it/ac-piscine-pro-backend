import 'dart:io';

import 'package:flutter/material.dart';

class OptimizedFileImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? errorWidget;

  const OptimizedFileImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFFF2F4F7),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined),
          ),
    );
  }
}
