// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

// lib/widgets/web_camera.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _cameraViewCounter = 0;

Future<Uint8List?> captureFromWebCamera(
  BuildContext context,
) async {
  html.MediaStream? stream;

  try {
    // Request Chrome webcam access
    stream = await html.window.navigator.mediaDevices?.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {
          'ideal': 1280,
        },
        'height': {
          'ideal': 720,
        },
      },
      'audio': false,
    });

    if (stream == null) {
      throw Exception(
        'Camera is not available in this browser.',
      );
    }

    // Create browser video element
    final video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.backgroundColor = '#000000';

    video.srcObject = stream;

    final viewType =
        'gold-pawn-camera-${_cameraViewCounter++}';

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => video,
    );

    await video.play();

    // Wait for camera dimensions
    if (video.videoWidth == 0 ||
        video.videoHeight == 0) {
      final completer = Completer<void>();

      late StreamSubscription<html.Event> subscription;

      subscription = video.onLoadedMetadata.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }

        subscription.cancel();
      });

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }

    if (!context.mounted) {
      _stopCamera(stream);
      return null;
    }

    // Open camera dialog
    final Uint8List? result =
        await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool capturing = false;

        return StatefulBuilder(
          builder: (
            context,
            setState,
          ) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.camera_alt,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: capturing
                        ? null
                        : () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              content: SizedBox(
                width: 700,
                height: 430,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.black,
                        child: HtmlElementView(
                          viewType: viewType,
                        ),
                      ),

                      if (capturing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              actions: [
                OutlinedButton.icon(
                  onPressed: capturing
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),

                const SizedBox(width: 8),

                FilledButton.icon(
                  onPressed: capturing
                      ? null
                      : () async {
                          setState(() {
                            capturing = true;
                          });

                          try {
                            final bytes =
                                _captureVideoFrame(video);

                            if (bytes == null ||
                                bytes.isEmpty) {
                              throw Exception(
                                'Could not capture camera frame.',
                              );
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(
                                dialogContext,
                              ).pop(bytes);
                            }
                          } catch (e) {
                            setState(() {
                              capturing = false;
                            });

                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(
                                dialogContext,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Capture failed: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.camera),
                  label: const Text(
                    'Capture Photo',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _stopCamera(stream);

    return result;
  } catch (e) {
    if (stream != null) {
      _stopCamera(stream);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to access camera: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    return null;
  }
}

// Capture current webcam frame
Uint8List? _captureVideoFrame(
  html.VideoElement video,
) {
  final width = video.videoWidth;
  final height = video.videoHeight;

  if (width <= 0 || height <= 0) {
    return null;
  }

  final canvas = html.CanvasElement(
    width: width,
    height: height,
  );

  final context = canvas.context2D;

  context.drawImage(
    video,
    0,
    0,
  );

  final dataUrl = canvas.toDataUrl(
    'image/jpeg',
    0.85,
  );

  final commaIndex = dataUrl.indexOf(',');

  if (commaIndex == -1) {
    return null;
  }

  final base64Data =
      dataUrl.substring(commaIndex + 1);

  return base64Decode(base64Data);
}

// Stop webcam
void _stopCamera(
  html.MediaStream stream,
) {
  for (final track in stream.getTracks()) {
    track.stop();
  }
}