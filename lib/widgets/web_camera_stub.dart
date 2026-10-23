// lib/widgets/web_camera_stub.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<Uint8List?> captureFromWebCamera(
  BuildContext context,
) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Browser camera is available only on Web.',
      ),
    ),
  );

  return null;
}