import 'dart:async';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/debt.dart';
import '../models/debt_share_payload.dart';
import '../services/logger.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';

/// Turns the receipt widget tree into a shareable image file.
///
/// Sealed as a typedef so tests can hand in a fake capturer and the share
/// flow can be verified without rasterising any real pixels.
typedef ReceiptCapturer = Future<XFile> Function(GlobalKey receiptKey);

/// Rasterises the widget registered under [receiptKey] into a PNG file.
///
/// Runs at 3x device pixels so the saved image stays crisp in chat apps.
Future<XFile> captureReceiptAsPng(GlobalKey receiptKey) async {
  final boundary = receiptKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError('Receipt is not mounted on screen');
  }
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  if (bytes == null) throw StateError('Could not rasterise the receipt');
  return XFile.fromData(
    bytes.buffer.asUint8List(),
    name: 'iou-receipt.png',
    mimeType: 'image/png',
  );
}

/// Shows a scannable QR carrying a snapshot of [debt].
///
/// This is the lender's half of the sharing flow: the lender creates a debt,
/// this screen renders it, the borrower's "Receive a debt" scanner imports
/// a read-only copy. The lender's own record is unaffected.
///
/// OOP principles:
/// - Single Responsibility : render + gather the profile name. Decoding and
///   storage live in [DebtSharePayload] / ReceivedDebtService.
/// - Dependency Inversion  : name comes through [ProfileService], the share
///   sheet through [sharePlus] and rasterisation through [receiptCapturer],
///   so tests inject their own and nothing real is touched.
class DebtQrScreen extends StatefulWidget {
  final Debt debt;

  /// Where the saved receipt image goes. Defaults to the real share sheet.
  final SharePlus sharePlus;

  /// How the receipt becomes a PNG. Defaults to [captureReceiptAsPng].
  final ReceiptCapturer receiptCapturer;

  DebtQrScreen({
    super.key,
    required this.debt,
    SharePlus? sharePlus,
    ReceiptCapturer? receiptCapturer,
  })  : sharePlus = sharePlus ?? SharePlus.instance,
        receiptCapturer = receiptCapturer ?? captureReceiptAsPng;

  @override
  State<DebtQrScreen> createState() => _DebtQrScreenState();
}

class _DebtQrScreenState extends State<DebtQrScreen> {
  late Future<DebtSharePayload> _future;

  /// Guards against re-opening the name dialog on every rebuild; reset by
  /// [_reload] so "Add your name" can ask again deliberately.
  bool _prompted = false;

  final GlobalKey _receiptKey = GlobalKey();

  /// True while the receipt is being rasterised, so a double tap can not
  /// start two captures (and Android's share sheet is not stacked).
  bool _isPreparingReceipt = false;

  @override
  void initState() {
    super.initState();
    _future = _buildPayload();
  }

  void _reload() {
    _prompted = false;
    final future = _buildPayload();
    setState(() {
      _future = future;
    });
  }

  Future<DebtSharePayload> _buildPayload() async {
    final name = await ServiceLocator.instance.profileService.getName();
    return DebtSharePayload.fromDebt(debt: widget.debt, lenderName: name);
  }

  /// After the QR is ready, a first-time user is asked once for the name
  /// that should appear on it. Asked *after* the future completes so the
  /// screen never sits behind an endless spinner while the dialog is open.
  void _maybePromptForName() {
    if (_prompted) return;
    _prompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final name = await _promptForName();
      if (!mounted || name.isEmpty) return;
      await ServiceLocator.instance.profileService.setName(name);
      if (mounted) _reload();
    });
  }

  Future<String> _promptForName() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ProfileNameDialog(),
    );
    return (result ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Share this debt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DebtSharePayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not prepare the code. Please try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final payload = snapshot.data!;
          final shareable = payload.lenderName.trim().isNotEmpty;
          if (payload.lenderName.isEmpty) {
            // Ask (once) for the name this code should carry.
            _maybePromptForName();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  key: _receiptKey,
                  child: _buildReceiptPaper(payload),
                ),
                const SizedBox(height: 16),
                if (shareable)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _isPreparingReceipt ? null : _shareReceipt,
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: Text(
                            'Save receipt',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyReceipt(payload),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(
                            'Copy text',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // No lender name on the payload: every scan would reject
                  // this code, so the share/save/copy paths never fire.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppTheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add your name first — a code without it cannot be imported.',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _buildHint(payload),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Receipt paper ──────────────────────────────────────────────────────────

  /// The white "printed" receipt: header, amount, itemised rows and the QR
  /// as the verification stamp, wrapped in a perforated paper edge.
  ///
  /// Ink colors are deliberately dark theme constants (not AppTheme.text*)
  /// because the app palette is for the dark background, not for paper.
  Widget _buildReceiptPaper(DebtSharePayload payload) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPerforation(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IOU',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '#${payload.uid.substring(0, 6).toUpperCase()}',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'DEBT RECEIPT',
            style: GoogleFonts.dmSans(
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          _buildDashedDivider(),
          Text(
            _peso(payload.amount),
            style: GoogleFonts.spaceGrotesk(
              color: Colors.black87,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            payload.isPaid ? 'SETTLED' : 'OUTSTANDING',
            style: GoogleFonts.dmSans(
              color: Colors.black45,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          _buildDashedDivider(),
          ..._receiptRows(payload).map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.$1,
                    style: GoogleFonts.dmSans(
                        color: Colors.black45, fontSize: 13),
                  ),
                  const Spacer(),
                  const SizedBox(width: 24),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: GoogleFonts.dmSans(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDashedDivider(),
          Center(
            child: QrImageView(
              data: payload.encode(),
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan to import',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildPerforation(),
        ],
      ),
    );
  }

  /// A punched-dot strip that reads as a torn receipt edge on paper. The
  /// dots are painted in the page background color, so they appear as
  /// cut-outs against the white sheet.
  Widget _buildPerforation() {
    return SizedBox(
      height: 16,
      child: Row(
        children: List.generate(14, (i) {
          return Expanded(
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: List.generate(22, (i) {
          return Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              color: Colors.black12,
            ),
          );
        }),
      ),
    );
  }

  /// Itemised receipt lines. Rows that carry nothing on this debt (interest,
  /// partial remaining balance, notes) are omitted so the sheet stays clean.
  List<(String, String)> _receiptRows(DebtSharePayload payload) {
    final dateFormat = DateFormat('MMM d, y');
    return [
      ('Lent by', payload.lenderDisplay),
      ('Owed by', payload.borrowerDisplay),
      ('Date', dateFormat.format(payload.transactionDate)),
      if (payload.remainingBalance > 0 &&
          payload.remainingBalance < payload.amount)
        ('Remaining', _peso(payload.remainingBalance)),
      if (payload.interestRate != null)
        ('Interest', _interestLabel(payload)),
      if (payload.notes != null && payload.notes!.isNotEmpty)
        ('Notes', payload.notes!),
    ];
  }

  String _interestLabel(DebtSharePayload payload) {
    final rate = payload.interestRate!;
    final rateText = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(1);
    final type = payload.interestType == InterestType.compound
        ? 'compound'
        : 'simple';
    final parts = <String>[type];
    if (payload.interestMode == InterestMode.automatic) {
      parts.add('automatic · ${_frequencyWord(payload.interestFrequencyDays)}');
    } else {
      parts.add('manual');
    }
    return '$rateText% ${parts.join(' · ')}';
  }

  String _frequencyWord(int? days) {
    return switch (days) {
      1 => 'daily',
      7 => 'weekly',
      14 => 'every 2 weeks',
      30 => 'monthly',
      null => 'scheduled',
      _ => 'every $days days',
    };
  }

  String _peso(double value) {
    return NumberFormat.currency(symbol: '\u20b1', decimalDigits: 2)
        .format(value);
  }

  // ── Receipt actions ────────────────────────────────────────────────────────

  Future<void> _shareReceipt() async {
    setState(() => _isPreparingReceipt = true);
    try {
      final file = await widget.receiptCapturer(_receiptKey);
      final result = await widget.sharePlus.share(
        ShareParams(
          files: [file],
          title: 'IOU debt receipt',
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        _toast('Could not share the receipt.', AppTheme.error);
        return;
      }
      if (result.status == ShareResultStatus.success) {
        _toast('Receipt shared', AppTheme.success);
      }
      // dismissed: the user backed out of the sheet — nothing to report.
    } catch (e, stack) {
      const Logger('DebtQrScreen')
          .warning('Receipt capture or share failed: $e ($stack)');
      if (mounted) _toast('Could not share the receipt.', AppTheme.error);
    } finally {
      if (mounted) setState(() => _isPreparingReceipt = false);
    }
  }

  Future<void> _copyReceipt(DebtSharePayload payload) async {
    // An unnamed lender code is rejected by every scan; refuse it here too
    // in case the button renders anyway.
    if (payload.lenderName.trim().isEmpty) {
      _toast('Add your name so the borrower can import this code.',
          AppTheme.error);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _receiptText(payload)));
    if (!mounted) return;
    _toast('Receipt copied', AppTheme.success);
  }

  /// The share-sheet fallback for environments where an image share is not
  /// possible and the plain readable version of the receipt, for clipboard.
  String _receiptText(DebtSharePayload payload) {
    final dateFormat = DateFormat('MMM d, y');
    final lines = <String>[
      'IOU DEBT RECEIPT #${payload.uid.substring(0, 6).toUpperCase()}',
      'Lent by: ${payload.lenderDisplay}',
      'Owed by: ${payload.borrowerDisplay}',
      'Date: ${dateFormat.format(payload.transactionDate)}',
      'Amount: ${_peso(payload.amount)}',
      if (payload.remainingBalance > 0 &&
          payload.remainingBalance < payload.amount)
        'Remaining: ${_peso(payload.remainingBalance)}',
      if (payload.interestRate != null)
        'Interest: ${_interestLabel(payload)}',
      'Status: ${payload.isPaid ? 'Settled' : 'Outstanding'}',
      if (payload.notes != null && payload.notes!.isNotEmpty)
        'Notes: ${payload.notes!}',
      'Scan the code to import this debt into I-O-U.',
    ];
    return lines.join('\n');
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildHint(DebtSharePayload payload) {
    final needsName = payload.lenderName.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsName
                ? 'Your name is not on the code yet.'
                : 'The borrower opens "Receive a debt" and scans this.',
            style: GoogleFonts.dmSans(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          if (needsName) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text('Add your name', style: GoogleFonts.dmSans()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks for the profile name that will appear on the code.
///
/// Owns its [TextEditingController] so the field is disposed with the route,
/// not while the dialog's exit animation still references it.
class _ProfileNameDialog extends StatefulWidget {
  const _ProfileNameDialog();

  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog> {
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
        'What should we call you?',
        style: GoogleFonts.spaceGrotesk(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Your name',
          hintStyle: TextStyle(color: AppTheme.textMuted),
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(
            'Skip for now',
            style: GoogleFonts.dmSans(color: AppTheme.textMuted),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text('Save', style: GoogleFonts.dmSans()),
        ),
      ],
    );
  }
}
