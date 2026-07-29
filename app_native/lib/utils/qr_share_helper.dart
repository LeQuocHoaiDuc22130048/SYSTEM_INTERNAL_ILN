import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper utility hỗ trợ tạo hình ảnh / file PDF tem mã QR và chia sẻ sang ứng dụng Eleph-label
class QrShareHelper {
  /// Chuyển tiếng Việt có dấu thành không dấu khi in tem nhãn
  static String _removeVietnameseAccents(String str) {
    if (str.isEmpty) return str;

    final Map<RegExp, String> maps = {
      RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'): 'a',
      RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'): 'A',
      RegExp(r'[èéẹẻẽêềếệểễ]'): 'e',
      RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'): 'E',
      RegExp(r'[ìíịỉĩ]'): 'i',
      RegExp(r'[ÌÍỊỈĨ]'): 'I',
      RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'): 'o',
      RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'): 'O',
      RegExp(r'[ùúụủũụưừứựửữ]'): 'u',
      RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'): 'U',
      RegExp(r'[ỳýỵỷỹ]'): 'y',
      RegExp(r'[ỲÝỴỶỸ]'): 'Y',
      RegExp(r'[đ]'): 'd',
      RegExp(r'[Đ]'): 'D',
    };

    String result = str;
    maps.forEach((regex, replacement) {
      result = result.replaceAll(regex, replacement);
    });
    return result;
  }

  /// Thử mở ứng dụng Eleph-label trực tiếp qua Custom URL Scheme
  static Future<bool> launchElephLabelApp() async {
    final schemes = [
      'elephlabel://',
      'openlabel://',
      'labelprint://',
      'phomemo://',
    ];

    for (final s in schemes) {
      final uri = Uri.parse(s);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        debugPrint('Không thể mở URL scheme $s: $e');
      }
    }
    return false;
  }

  /// Lấy vị trí khung hiển thị để hỗ trợ mở popup Share trên iPad/Tablet mà không bị đơ
  static Rect _getSharePositionOrigin(BuildContext context) {
    try {
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          return box.localToGlobal(Offset.zero) & box.size;
        }
        final size = MediaQuery.of(context).size;
        return Rect.fromLTWH(0, 0, size.width, size.height / 2);
      }
    } catch (_) {}
    return const Rect.fromLTWH(0, 0, 300, 300);
  }

  /// 1. Chia sẻ tem mã QR dạng File PDF (.pdf)
  /// Eleph-label mở trực tiếp giao diện "In PDF (PDF Print Preview)" tốt nhất khi nhận định dạng .pdf
  static Future<bool> shareQrPdfToElephLabel({
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
      final displayTitle = (title != null && title.trim().isNotEmpty)
          ? _removeVietnameseAccents(title.trim())
          : null;

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
                  if (displayTitle != null) ...[
                    pw.Text(
                      displayTitle,
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

      // Sao chép mã QR vào Clipboard để tiện dùng nếu app yêu cầu dán
      await Clipboard.setData(ClipboardData(text: qrData));

      if (!context.mounted) return false;
      final origin = _getSharePositionOrigin(context);

      // Ưu tiên dùng OpenFilex để Android/iOS gọi hộp thoại "Mở bằng Eleph-label / ứng dụng in" trực tiếp
      final openResult = await OpenFilex.open(file.path, type: 'application/pdf');

      if (openResult.type != ResultType.done) {
        // Fallback mở Share Sheet nếu OpenFilex không khởi chạy
        // ignore: deprecated_member_use
        Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf', name: 'label_$sanitizedFilename.pdf')],
          text: 'In tem nhãn PDF',
          subject: 'Chia sẻ PDF sang Eleph-label',
          sharePositionOrigin: origin,
        );
      }

      return true;
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

  /// Alias tương thích ngược
  static Future<bool> shareQrPdfToOpenLabel({
    required BuildContext context,
    required String qrData,
    String? title,
    String? subtitle,
    double widthMm = 50,
    double heightMm = 40,
  }) => shareQrPdfToElephLabel(
    context: context,
    qrData: qrData,
    title: title,
    subtitle: subtitle,
    widthMm: widthMm,
    heightMm: heightMm,
  );

  /// 2. Chia sẻ tem dưới dạng File PNG (.png)
  static Future<bool> shareQrCodeToElephLabel({
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
            text: _removeVietnameseAccents(title.trim()),
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

      // Sao chép mã QR vào Clipboard
      await Clipboard.setData(ClipboardData(text: qrData));

      if (!context.mounted) return false;
      final origin = _getSharePositionOrigin(context);

      // Thử mở file ảnh qua OpenFilex trực tiếp
      final openResult = await OpenFilex.open(file.path, type: 'image/png');

      if (openResult.type != ResultType.done) {
        // Fallback mở Share Sheet
        // ignore: deprecated_member_use
        Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text: title != null ? 'Tem mã QR: $title' : 'Tem mã QR: $qrData',
          subject: 'Chia sẻ in tem mã QR sang Eleph-label',
          sharePositionOrigin: origin,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Lỗi khi chia sẻ QR Code sang Eleph-label: $e');
      return false;
    }
  }

  /// Alias tương thích ngược
  static Future<bool> shareQrCodeToOpenLabel({
    required BuildContext context,
    required String qrData,
    String? title,
    String? subtitle,
  }) => shareQrCodeToElephLabel(
    context: context,
    qrData: qrData,
    title: title,
    subtitle: subtitle,
  );

  /// 3. Sao chép Mã QR vào Clipboard & Mở App Eleph-label
  static Future<void> copyAndLaunchElephLabel({
    required BuildContext context,
    required String qrData,
  }) async {
    await Clipboard.setData(ClipboardData(text: qrData));

    final launched = await launchElephLabelApp();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Đã sao chép "$qrData" và mở ứng dụng Eleph-label!'
                : 'Đã sao chép mã "$qrData" vào Clipboard! Hãy dán vào Eleph-label để in.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Alias tương thích ngược
  static Future<void> copyAndLaunchOpenLabel({
    required BuildContext context,
    required String qrData,
  }) => copyAndLaunchElephLabel(
    context: context,
    qrData: qrData,
  );
}
