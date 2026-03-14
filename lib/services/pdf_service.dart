import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// PDF generation service — combines multiple scanned pages into a single PDF
class PdfService {
  /// Generate a PDF from multiple image paths
  ///
  /// Returns the path to the generated PDF file
  Future<String> generatePdf({
    required List<String> imagePaths,
    required String documentName,
    String? outputDir,
  }) async {
    final pdf = pw.Document(
      author: 'DocScanner',
      title: documentName,
      creator: 'DocScanner App',
    );

    for (final imagePath in imagePaths) {
      final imageBytes = await File(imagePath).readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
                width: PdfPageFormat.a4.width,
                height: PdfPageFormat.a4.height,
              ),
            );
          },
        ),
      );
    }

    // Save the PDF — prefer external Downloads so user can find it easily
    String dir;
    if (outputDir != null) {
      dir = outputDir;
    } else {
      // Try saving to Download/DocScanner/PDF on external storage
      final dlDir = Directory('/storage/emulated/0/Download/DocScanner/PDF');
      if (await dlDir.exists() || await dlDir.create(recursive: true).then((_) => true).catchError((_) => false)) {
        dir = dlDir.path;
      } else {
        dir = (await getApplicationDocumentsDirectory()).path;
      }
    }
    final sanitizedName = documentName.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final filePath = p.join(dir, '$sanitizedName.pdf');

    final Uint8List pdfBytes = await pdf.save();
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    return filePath;
  }

  /// Generate a PDF from a single image (quick save)
  Future<String> generateSinglePagePdf({
    required String imagePath,
    required String documentName,
  }) async {
    return generatePdf(
      imagePaths: [imagePath],
      documentName: documentName,
    );
  }

  /// Add a signature image overlay to an existing PDF page image
  /// Returns a new image path with the signature overlaid
  Future<String> overlaySignatureOnImage({
    required String documentImagePath,
    required String signatureImagePath,
    required double xPercent, // 0.0 - 1.0 position
    required double yPercent,
    required double widthPercent,
  }) async {
    // This uses the image_processing_service for actual compositing
    // The signature is placed at the specified percentage position
    // For simplicity, we generate the PDF with the signature already baked in
    return documentImagePath; // Placeholder — actual compositing in image service
  }
}
