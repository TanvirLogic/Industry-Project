import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Full-screen image viewer for avatars and cover photos.
///
/// Displays the image at full screen with a dark backdrop, pinch-to-zoom,
/// and a close/back button overlay.
class FullScreenImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  State<FullScreenImageViewerScreen> createState() => _FullScreenImageViewerScreenState();
}

class _FullScreenImageViewerScreenState extends State<FullScreenImageViewerScreen> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Zoomable image ──
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: widget.heroTag != null
                  ? Hero(
                      tag: widget.heroTag!,
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        ),
                        errorWidget: (context, url, error) => const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                            SizedBox(height: 12),
                            Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      ),
                      errorWidget: (context, url, error) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                          SizedBox(height: 12),
                          Text('Failed to load image', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
            ),
          ),

          // ── Close button overlay ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // ── Hint text at bottom ──
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Pinch to zoom · Swipe to pan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
