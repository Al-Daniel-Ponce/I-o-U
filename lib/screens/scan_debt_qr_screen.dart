import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/received_debt_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';

/// Camera screen that scans a lender's debt QR and imports a read-only copy.
///
/// The scan loop is deliberately forgiving: an unreadable or foreign QR shows
/// a snackbar and keeps the camera running, because mis-scans are routine.
/// A valid code imports immediately and pops with the result so the caller
/// can refresh and confirm.
///
/// OOP principles:
/// - Single Responsibility : camera + feedback only. Decoding, upserting and
///   validation all live in [ReceivedDebtService].
/// - Encapsulation : the `_handled` guard is private state, invisible to
///   callers, and prevents double-import of a single frame.
class ScanDebtQrScreen extends StatefulWidget {
  const ScanDebtQrScreen({super.key});

  @override
  State<ScanDebtQrScreen> createState() => _ScanDebtQrScreenState();
}

class _ScanDebtQrScreenState extends State<ScanDebtQrScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  /// True while a detected code is being imported.
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _processing = true;

    final QrImportResult result;
    try {
      result =
          await ServiceLocator.instance.receivedDebtService.importFromQr(raw);
    } catch (_) {
      _processing = false;
      if (mounted) _showFeedback('Could not save that. Please try again.');
      return;
    }

    if (!mounted) return;

    if (!result.isSuccess) {
      // Not one of our codes — let the user aim at the right one.
      HapticFeedback.lightImpact();
      _processing = false;
      _showFeedback(result.message);
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context, result);
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Receive a debt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildScannerArea()),
          _buildInstructionBar(),
        ],
      ),
    );
  }

  Widget _buildScannerArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _buildErrorState(error),
        ),
        // Scrim keeps the frame readable against a bright camera feed.
        IgnorePointer(
          child: CustomPaint(painter: _ScanFramePainter()),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Align the QR code inside the frame',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(MobileScannerException error) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              permissionDenied ? Icons.no_photography_rounded : Icons.camera_alt_outlined,
              color: AppTheme.textMuted,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              permissionDenied
                  ? 'Camera access is needed to scan a debt code.'
                  : 'The camera is unavailable right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              permissionDenied
                  ? 'Allow camera access in your device settings, then come back.'
                  : 'Close this screen and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Ask the lender to open their debt and tap the QR icon.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _enterCodeManually,
            icon: const Icon(Icons.keyboard_rounded, size: 16),
            label: Text('Enter code manually', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );
  }

  /// Fallback for when there is no second device to scan — the borrower
  /// pastes the code text the lender's QR screen shows.
  Future<void> _enterCodeManually() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _PasteCodeDialog(),
    );

    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty || !mounted || _processing) return;

    _processing = true;
    try {
      final result = await ServiceLocator.instance.receivedDebtService
          .importFromQr(trimmed);
      if (!mounted) return;
      if (result.isSuccess) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, result);
      } else {
        _processing = false;
        _showFeedback(result.message);
      }
    } catch (_) {
      _processing = false;
      if (mounted) _showFeedback('Could not save that. Please try again.');
    }
  }
}

/// Darkens everything outside the square scan window.
class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 40.0;
    final frameSide = (size.width - inset * 2).clamp(180.0, 300.0);
    final frameRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: frameSide,
      height: frameSide,
    );

    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.55));

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(24)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Manual-entry variant of the scan: paste the text a QR encodes.
///
/// Owns its [TextEditingController] so disposal happens with the route's
/// widget, never while the dialog is still animating away.
class _PasteCodeDialog extends StatefulWidget {
  const _PasteCodeDialog();

  @override
  State<_PasteCodeDialog> createState() => _PasteCodeDialogState();
}

class _PasteCodeDialogState extends State<_PasteCodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        'Paste the shared code',
        style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'Paste the code here'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.textMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Import', style: GoogleFonts.dmSans()),
        ),
      ],
    );
  }
}
