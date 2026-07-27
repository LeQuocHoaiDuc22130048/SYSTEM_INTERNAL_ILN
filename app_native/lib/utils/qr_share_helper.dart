import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Helper utility hỗ trợ tạo hình ảnh / file PDF tem mã QR và chia sẻ sang ứng dụng OpenLabel
class QrShareHelper {
  /// 1. Chia sẻ tem mã QR dạng File PDF (.pdf)
  /// OpenLabel mở trực tiếp giao diện "In PDF (PDF Print Preview)" tốt nhất khi nhận định dạng .pdf
  static Future<bool> shareQrPdfToOpenLabel({
    required BuildContext context,
    required String qrData,
    String? title,
    String? subtitle,
    double widthMm = 50,
    double heightMm = 40,
  }) async {
    if (qrData.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã QR trống, không thể tạo tem in PDF!')),
        );
      }
      return false;
    }

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            widthMm * PdfPageFormat.mm,
            heightMm * PdfPageFormat.mm,
            marginAll: 1.5 * PdfPageFormat.mm,
          ),
          build: (pw.Context pwContext) {
            return pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 75,
                    height: 75,
                  ),
                  pw.SizedBox(height: 3),
                  if (title != null && title.trim().isNotEmpty) ...[
                    pw.Text(
                      title.trim(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                    ),
                    pw.SizedBox(height: 1),
                  ],
                  pw.Text(
                    'QR: $qrData',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final sanitizedFilename = qrData.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${tempDir.path}/label_$sanitizedFilename.pdf');
      await file.writeAsBytes(await pdf.save());

      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: 'label_$sanitizedFilename.pdf')],
        text: 'In tem nhãn PDF',
        subject: 'Chia sẻ PDF sang OpenLabel',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Lỗi khi tạo PDF tem in: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo PDF tem in: $e')),
        );
      }
      return false;
    }
  }

  /// 2. Chia sẻ tem dưới dạng File PNG (.png)
  static Future<bool> shareQrCodeToOpenLabel({
    required BuildContext context,
    required String qrData,
    String? title,
    String? subtitle,
  }) async {
    if (qrData.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã QR trống, không thể tạo tem in!')),
        );
      }
      return false;
    }

    try {
      final qrValidationResult = QrValidator.validate(
        data: qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (!qrValidationResult.isValid || qrValidationResult.qrCode == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dữ liệu mã QR không hợp lệ!')),
          );
        }
        return false;
      }

      const double canvasWidth = 800.0;
      const double canvasHeight = 960.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), bgPaint);

      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 20, canvasWidth - 40, canvasHeight - 40),
          const Radius.circular(16),
        ),
        borderPaint,
      );

      const double qrSize = 520.0;
      final qrPainter = QrPainter.withQr(
        qr: qrValidationResult.qrCode!,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        gapless: true,
      );

      canvas.save();
      canvas.translate((canvasWidth - qrSize) / 2, 60.0);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      final linePaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 2.0;
      canvas.drawLine(
        const Offset(50, 600),
        const Offset(canvasWidth - 50, 600),
        linePaint,
      );

      double currentY = 620.0;

      if (title != null && title.trim().isNotEmpty) {
        final titlePainter = TextPainter(
          text: TextSpan(
            text: title.trim(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 2,
          ellipsis: '...',
        );
        titlePainter.layout(maxWidth: canvasWidth - 100);
        titlePainter.paint(
          canvas,
          Offset((canvasWidth - titlePainter.width) / 2, currentY),
        );
        currentY += titlePainter.height + 12;
      }

      final codePainter = TextPainter(
        text: TextSpan(
          text: 'MÃ QR: $qrData',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      codePainter.layout(maxWidth: canvasWidth - 100);
      codePainter.paint(
        canvas,
        Offset((canvasWidth - codePainter.width) / 2, currentY),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Không thể chuyển đổi Canvas thành file PNG');
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedFilename = qrData.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${tempDir.path}/qr_label_$sanitizedFilename.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: title != null ? 'Tem mã QR: $title' : 'Tem mã QR: $qrData',
        subject: 'Chia sẻ in tem mã QR sang OpenLabel',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Lỗi khi chia sẻ QR Code sang OpenLabel: $e');
      return false;
    }
  }

  /// 3. Sao chép Mã QR vào Clipboard & Mở App OpenLabel
  static Future<void> copyAndLaunchOpenLabel({
    required BuildContext context,
    required String qrData,
  }) async {
    await Clipboard.setData(ClipboardData(text: qrData));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép mã "$qrData" vào Clipboard! Nạp vào OpenLabel để tạo QR.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
