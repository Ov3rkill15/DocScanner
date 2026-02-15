import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Image processing service for document enhancement filters
class ImageProcessingService {
  static const platform = MethodChannel('com.example.coba_aplikasi_flutter/image_processing');
  


  /// Apply B&W (threshold) filter via Native Kotlin
  Future<String> applyBlackAndWhite(String imagePath) async {
    try {
      debugPrint("Flutter: Mengirim permintaan B&W ke Kotlin...");
      final String? resultPath = await platform.invokeMethod('applyFilter', {
        'path': imagePath,
        'type': 'bw',
      });
      debugPrint("Flutter: Menerima hasil dari Kotlin!");
      return resultPath ?? imagePath;
    } catch (e) {
      debugPrint("Native Error: $e");
      return imagePath;
    }
  }

  /// Apply Magic Color filter via Native Kotlin
  Future<String> applyMagicColor(String imagePath) async {
    try {
      final String? resultPath = await platform.invokeMethod('applyFilter', {
        'path': imagePath,
        'type': 'magic',
      });
      return resultPath ?? imagePath;
    } catch (e) {
      debugPrint("Native Error: $e");
      return imagePath;
    }
  }

  /// Apply Grayscale filter via Native Kotlin
  Future<String> applyGrayscale(String imagePath) async {
    try {
      final String? resultPath = await platform.invokeMethod('applyFilter', {
        'path': imagePath,
        'type': 'gray',
      });
      return resultPath ?? imagePath;
    } catch (e) {
      debugPrint("Native Error: $e");
      return imagePath;
    }
  }

  /// Check if an image was shared to the app via Intent
  Future<String?> getSharedImage() async {
    try {
      final String? path = await platform.invokeMethod('getSharedImage');
      return path;
    } catch (e) {
      debugPrint("Native Error: $e");
      return null;
    }
  }

  /// Trigger Native ML Kit Document Scanner
  /// Returns list of scanned image paths
  Future<List<String>> scanDocument() async {
    try {
      debugPrint("Flutter: Memulai Native Scanner...");
      final List<dynamic>? results =
          await platform.invokeMethod('scanDocument');
      
      if (results != null) {

        return results.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint("Native Scanner Error: $e");
      return [];
    }
  }


  
  /// Rotate image by 90 degrees clockwise
  Future<String> rotateClockwise(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    image = img.copyRotate(image, angle: 90);

    return await _saveProcessed(imagePath, image, 'rotated');
  }

  /// Rotate image by 90 degrees counter-clockwise
  Future<String> rotateCounterClockwise(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    image = img.copyRotate(image, angle: -90);

    return await _saveProcessed(imagePath, image, 'rotated');
  }



  /// Crop image to given rectangle
  Future<String> cropImage(
    String imagePath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    image = img.copyCrop(image, x: x, y: y, width: width, height: height);

    return await _saveProcessed(imagePath, image, 'cropped');
  }



  /// Generate a small thumbnail for document cards
  Future<String> generateThumbnail(String imagePath, {int maxSize = 300}) async {
    final bytes = await File(imagePath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    image = img.copyResize(image,
        width: image.width > image.height ? maxSize : null,
        height: image.height >= image.width ? maxSize : null);

    return await _saveProcessed(imagePath, image, 'thumb');
  }



  /// Composite two images vertically (front on top, back on bottom)
  Future<String> compositeVertical(String topPath, String bottomPath) async {
    final topBytes = await File(topPath).readAsBytes();
    final bottomBytes = await File(bottomPath).readAsBytes();

    var topImg = img.decodeImage(topBytes);
    var bottomImg = img.decodeImage(bottomBytes);
    if (topImg == null || bottomImg == null) {
      throw Exception('Failed to decode images');
    }

    // Resize to same width
    final targetWidth = topImg.width > bottomImg.width ? topImg.width : bottomImg.width;
    topImg = img.copyResize(topImg, width: targetWidth);
    bottomImg = img.copyResize(bottomImg, width: targetWidth);

    // Create composite canvas
    final composite = img.Image(
      width: targetWidth,
      height: topImg.height + bottomImg.height + 20, // 20px gap
    );

    // Fill with white background
    img.fill(composite, color: img.ColorRgb8(255, 255, 255));

    // Draw top
    img.compositeImage(composite, topImg, dstX: 0, dstY: 0);

    // Draw bottom
    img.compositeImage(composite, bottomImg, dstX: 0, dstY: topImg.height + 20);

    return await _saveProcessed(topPath, composite, 'id_composite');
  }



  /// Save a processed image alongside the original
  Future<String> _saveProcessed(
      String originalPath, img.Image image, String suffix) async {
    final dir = File(originalPath).parent.path;
    final baseName =
        originalPath.split(Platform.pathSeparator).last.split('.').first;
    final outputPath = '$dir${Platform.pathSeparator}${baseName}_$suffix.jpg';

    final Uint8List encoded = img.encodeJpg(image, quality: 90);
    await File(outputPath).writeAsBytes(encoded);

    return outputPath;
  }
}
