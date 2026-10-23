// lib/widgets/image_picker_widget.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'web_camera_stub.dart'
    if (dart.library.html) 'web_camera.dart';

class ImagePickerWidget extends StatefulWidget {
  final String? initialImageUrl;

  /// Allowed values:
  /// customers
  /// gold
  final String uploadType;

  final Function(String imageUrl) onImageUploaded;

  final String label;

  const ImagePickerWidget({
    super.key,
    this.initialImageUrl,
    required this.uploadType,
    required this.onImageUploaded,
    this.label = 'Photo (Optional)',
  });

  @override
  State<ImagePickerWidget> createState() =>
      _ImagePickerWidgetState();
}

class _ImagePickerWidgetState
    extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _localBytes;

  String? _uploadedUrl;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();

    _uploadedUrl = widget.initialImageUrl;
  }

  @override
  void didUpdateWidget(
    covariant ImagePickerWidget oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialImageUrl !=
        widget.initialImageUrl) {
      _uploadedUrl =
          widget.initialImageUrl;
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _openCamera() async {
    if (_isUploading) return;

    try {
      // On Flutter Web, image_picker's camera implementation can
      // fall back to the browser file chooser. Use the dedicated
      // getUserMedia camera dialog instead so Camera always opens
      // the real webcam directly.
      if (kIsWeb) {
        final bytes = await captureFromWebCamera(context);

        if (bytes == null || bytes.isEmpty) {
          return;
        }

        await _processBytes(bytes);
        return;
      }

      // Android/iOS: keep the native image_picker camera flow.
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) return;
      await _processSelectedImage(photo);
    } catch (e) {
      if (!mounted) return;
      _showError('Unable to open camera: $e');
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> _openGallery() async {
    if (_isUploading) return;

    try {
      final XFile? photo =
          await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) {
        return;
      }

      await _processSelectedImage(photo);
    } catch (e) {
      if (!mounted) return;

      _showError(
        'Unable to open gallery: $e',
      );
    }
  }

  // ============================================================
  // PROCESS IMAGE
  // ============================================================

  Future<void> _processSelectedImage(XFile photo) async {
    final bytes = await photo.readAsBytes();
    await _processBytes(bytes);
  }

  Future<void> _processBytes(Uint8List bytes) async {
    try {
      if (bytes.isEmpty) {
        _showError('Selected image is empty.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _localBytes = bytes;
        _isUploading = true;
      });

      final base64String =
          'data:image/jpeg;base64,${base64Encode(bytes)}';

      final url = await ApiService.uploadImageBase64(
        base64String,
        widget.uploadType,
      );

      if (!mounted) return;

      final cleanUrl = url.trim();
      if (cleanUrl.isEmpty) {
        throw Exception('Server did not return an image URL.');
      }

      setState(() {
        _uploadedUrl = cleanUrl;
        _isUploading = false;
      });

      widget.onImageUploaded(cleanUrl);
      _showSuccess('Photo uploaded successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showError('Photo upload failed: $e');
    }
  }

  // ============================================================
  // RESOLVE IMAGE URL
  // ============================================================

  String? _resolveImageUrl(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    final raw =
        value.trim();

    if (raw.isEmpty) {
      return null;
    }

    /*
     * Already absolute.
     */
    if (raw.startsWith('http://') ||
        raw.startsWith('https://')) {
      return raw;
    }

    /*
     * Data URLs are represented by
     * _localBytes for newly selected images.
     */
    if (raw.startsWith('data:image/')) {
      return null;
    }

    final base =
        ApiService.baseUrl
            .trim()
            .replaceFirst(
              RegExp(r'/$'),
              '',
            );

    if (base.isEmpty) {
      return raw;
    }

    /*
     * Root-relative:
     *
     * /uploads/gold/example.jpg
     */
    if (raw.startsWith('/')) {
      final uri =
          Uri.tryParse(base);

      if (uri != null &&
          uri.scheme.isNotEmpty &&
          uri.host.isNotEmpty) {
        return
            '${uri.scheme}://${uri.authority}$raw';
      }

      return '$base$raw';
    }

    /*
     * Relative:
     *
     * uploads/gold/example.jpg
     */
    return '$base/$raw';
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  Widget _buildImagePreview() {
    final theme =
        Theme.of(context);

    /*
     * Newly selected local image.
     */
    if (_localBytes != null) {
      return ClipRRect(
        borderRadius:
            BorderRadius.circular(12),
        child: Image.memory(
          _localBytes!,
          width: double.infinity,
          height: 190,
          fit: BoxFit.cover,
        ),
      );
    }

    final imageUrl =
        _resolveImageUrl(
      _uploadedUrl,
    );

    if (imageUrl == null) {
      return _buildEmptyPreview();
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        loadingBuilder:
            (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: double.infinity,
            height: 190,
            color:
                theme.colorScheme.surface,
            alignment:
                Alignment.center,
            child:
                const CircularProgressIndicator(),
          );
        },
        errorBuilder:
            (
          context,
          error,
          stackTrace,
        ) {
          return _buildBrokenPreview(
            imageUrl,
          );
        },
      ),
    );
  }

  Widget _buildEmptyPreview() {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              theme.colorScheme.outline,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .add_a_photo_outlined,
            size: 48,
            color:
                theme.colorScheme
                    .onSurfaceVariant,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            'No photo selected',
            style: TextStyle(
              color:
                  theme.colorScheme
                      .onSurfaceVariant,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokenPreview(
    String imageUrl,
  ) {
    final theme =
        Theme.of(context);

    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surface,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              theme.colorScheme.outline,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .broken_image_outlined,
            size: 44,
            color:
                theme.colorScheme.error,
          ),
          const SizedBox(
            height: 8,
          ),
          const Text(
            'Photo could not be loaded',
            textAlign:
                TextAlign.center,
          ),
          const SizedBox(
            height: 5,
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Text(
              imageUrl,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color:
                    theme.colorScheme
                        .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _isUploading
                    ? null
                    : _openCamera,
            icon: const Icon(
              Icons.camera_alt_outlined,
            ),
            label:
                const Text('Camera'),
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _isUploading
                    ? null
                    : _openGallery,
            icon: const Icon(
              Icons.photo_library_outlined,
            ),
            label:
                const Text('Gallery'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // UPLOAD STATUS
  // ============================================================

  Widget _buildUploadStatus() {
    if (!_isUploading) {
      return const SizedBox.shrink();
    }

    final theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 12,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            'Uploading photo...',
            style: TextStyle(
              color:
                  theme.colorScheme
                      .onSurfaceVariant,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  void _clearPhoto() {
    if (_isUploading) return;

    setState(() {
      _localBytes = null;
      _uploadedUrl = null;
    });

    widget.onImageUploaded('');
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) return;

    final theme =
        Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          backgroundColor:
              theme.colorScheme
                  .primary,
        ),
      );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    final theme =
        Theme.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            maxLines: 3,
            overflow:
                TextOverflow.ellipsis,
          ),
          backgroundColor:
              theme.colorScheme.error,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        _buildImagePreview(),

        const SizedBox(
          height: 12,
        ),

        _buildActionButtons(),

        _buildUploadStatus(),

        if ((_uploadedUrl != null &&
                _uploadedUrl!
                    .trim()
                    .isNotEmpty) ||
            _localBytes != null) ...[
          const SizedBox(
            height: 10,
          ),
          Align(
            alignment:
                Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  _isUploading
                      ? null
                      : _clearPhoto,
              icon: const Icon(
                Icons.delete_outline,
              ),
              label:
                  const Text(
                'Remove Photo',
              ),
            ),
          ),
        ],
      ],
    );
  }
}