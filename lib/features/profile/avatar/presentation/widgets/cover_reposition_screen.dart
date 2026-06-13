import 'dart:io';
import 'dart:ui' as ui;

import 'package:edtech/global/core/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Facebook-style cover reposition: shows the image at the exact banner aspect
/// ratio (full width × [bannerHeight]), so the user sees precisely how
/// BoxFit.cover will clip. Drag vertically to adjust focal area, tap "Done"
/// to extract via manual dart:ui (no native crop — crashes on Android 16).
class CoverRepositionScreen extends StatefulWidget {
  /// The image file picked at full phone quality.
  final XFile imageFile;

  /// Height of the banner in logical pixels (default: 195).
  final double bannerHeight;

  const CoverRepositionScreen({
    super.key,
    required this.imageFile,
    this.bannerHeight = 195,
  });

  @override
  State<CoverRepositionScreen> createState() => _CoverRepositionScreenState();
}

class _CoverRepositionScreenState extends State<CoverRepositionScreen> {
  ui.Image? _image;
  Size _nativeSize = Size.zero;
  Size _displaySize = Size.zero;
  bool _isProcessing = false;

  final TransformationController _transformController =
      TransformationController();

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _nativeSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ToastService.showError('Failed to load image. Please try again.');
      Navigator.pop(context);
    }
  }

  // ── Crop / extraction logic ──────────────────────────────────────────────

  /// Called when the user taps "Done".
  ///
  /// Uses manual [dart:ui] extraction directly (skips native [ImageCropper]
  /// which crashes on Android 16 / API 36).
  Future<void> _onDone() async {
    if (_image == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    final bannerW = MediaQuery.of(context).size.width;
    final bannerH = widget.bannerHeight;

    try {
      final manualResult = await _extractVisibleArea(
        bannerW: bannerW,
        bannerH: bannerH,
      );
      if (manualResult != null && mounted) {
        Navigator.pop(context, CroppedFile(manualResult.path));
        return;
      }
    } catch (_) {
      // fall through to error
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      ToastService.showError('Failed to extract image. Please try again.');
    }
  }

  /// Manual extraction using [dart:ui] entirely in Dart.
  ///
  /// Calculates the portion of the native image visible within the banner
  /// viewport container (accounting for the user's drag/zoom transform),
  /// extracts it, and saves as PNG.
  Future<File?> _extractVisibleArea({
    required double bannerW,
    required double bannerH,
  }) async {
    try {
      final image = _image!;
      final native = _nativeSize;

      // ── Compute display size dynamically (same logic as _buildBody) ──
      final imageAspect = native.width / native.height;
      double displayW = bannerW;
      double displayH = bannerW / imageAspect;
      if (displayH < bannerH) {
        displayH = bannerH;
        displayW = bannerH * imageAspect;
      }

      if (displayW <= 0 || displayH <= 0) return null;

      // Map viewport corners to image-display coordinates via the inverse
      // InteractiveViewer transform matrix.
      final inverse = Matrix4.inverted(_transformController.value);
      final vpTL = MatrixUtils.transformPoint(inverse, Offset.zero);
      final vpBR = MatrixUtils.transformPoint(
        inverse,
        Offset(bannerW, bannerH),
      );

      // Scale from display coordinates to native image pixels.
      final scaleX = native.width / displayW;
      final scaleY = native.height / displayH;

      final srcX = (vpTL.dx * scaleX).round().clamp(
        0,
        native.width.toInt() - 1,
      );
      final srcY = (vpTL.dy * scaleY).round().clamp(
        0,
        native.height.toInt() - 1,
      );
      final srcW = ((vpBR.dx - vpTL.dx) * scaleX).round().clamp(
        1,
        native.width.toInt() - srcX,
      );
      final srcH = ((vpBR.dy - vpTL.dy) * scaleY).round().clamp(
        1,
        native.height.toInt() - srcY,
      );

      // Output at max 1920px wide, maintaining banner aspect ratio.
      final outW = srcW < 1920 ? srcW.toDouble() : 1920.0;
      final outH = outW * bannerH / bannerW;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          srcX.toDouble(),
          srcY.toDouble(),
          srcW.toDouble(),
          srcH.toDouble(),
        ),
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW.round(), outH.round());

      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final dir = widget.imageFile.path.substring(
        0,
        widget.imageFile.path.lastIndexOf(Platform.pathSeparator),
      );
      final outPath =
          '$dir/cover_repos_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(outPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file;
    } catch (_) {
      return null;
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Reposition Cover Photo',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        actions: [
          _isProcessing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _onDone,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: _image == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerW = constraints.maxWidth;
        final bannerH = widget.bannerHeight;

        // Scale the image so its width always fills the banner width.
        // For portrait images, scale so height fills the banner instead.
        final imageAspect = _nativeSize.width / _nativeSize.height;
        double displayW = bannerW;
        double displayH = bannerW / imageAspect;
        if (displayH < bannerH) {
          displayH = bannerH;
          displayW = bannerH * imageAspect;
        }

        // Persist the display size for extraction.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_displaySize != Size(displayW, displayH)) {
            setState(() => _displaySize = Size(displayW, displayH));
          }
        });

        // Vertically center the image on first render.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_transformController.value == Matrix4.identity()) {
            final dy = (bannerH - displayH) / 2;
            _transformController.value = Matrix4.translationValues(0, dy, 0);
          }
        });

        return Column(
          children: [
            // ── Banner preview ──
            Expanded(
              child: Center(
                child: Container(
                  width: bannerW,
                  height: bannerH,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.8,
                    maxScale: 3.0,
                    constrained: false,
                    boundaryMargin: EdgeInsets.symmetric(
                      vertical: (displayH - bannerH).clamp(50, 2000) + 100,
                      horizontal: (displayW - bannerW).clamp(50, 2000) + 100,
                    ),
                    child: RawImage(
                      image: _image,
                      width: displayW,
                      height: displayH,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            // ── Hint ──
            const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Text(
                'Drag to reposition your cover photo',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        );
      },
    );
  }
}
