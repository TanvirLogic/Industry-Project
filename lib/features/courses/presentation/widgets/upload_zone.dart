import 'package:flutter/material.dart';
import '../../../../global/core/widgets/dashed_border.dart';

class UploadZone extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onTap;
  final String? selectedFileName;

  const UploadZone({
    super.key,
    required this.cs,
    required this.isDark,
    this.onTap,
    this.selectedFileName,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        decoration: ShapeDecoration(
          color: isDark
              ? cs.surfaceContainerLow.withValues(alpha: 0.6)
              : const Color(0x99F5F5F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        foregroundDecoration: ShapeDecoration(
          shape: DashedBorder(color: cs.outlineVariant, width: 1.5, radius: 16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _UploadIcon(cs: cs),
            const SizedBox(height: 12),
            Text(
              selectedFileName ?? 'Upload Video File',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
                children: [
                  if (selectedFileName == null) ...[
                    const TextSpan(text: 'Drag & drop your video here or tap to\n'),
                    TextSpan(
                      text: 'browse',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ] else
                    TextSpan(
                      text: 'Tap to change video',
                      style: TextStyle(color: cs.primary),
                    ),
                ],
              ),
            ),
            if (selectedFileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Optional',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadIcon extends StatelessWidget {
  final ColorScheme cs;

  const _UploadIcon({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: ShapeDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.3),
        shape: const CircleBorder(),
      ),
      foregroundDecoration: ShapeDecoration(
        shape: DashedBorder(color: cs.outlineVariant, width: 1.5, radius: 28),
      ),
      child: Icon(Icons.cloud_upload_outlined, color: cs.onSurface, size: 28),
    );
  }
}