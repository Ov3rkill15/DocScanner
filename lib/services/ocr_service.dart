import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR Service — extracts text from scanned document images
class OcrService {
  TextRecognizer? _textRecognizer;

  /// Get or create the text recognizer instance
  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Recognize text from an image file
  ///
  /// Returns structured [RecognizedText] containing text blocks, lines, and elements
  Future<RecognizedText> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    return await _recognizer.processImage(inputImage);
  }

  /// Extract plain text string from an image
  Future<String> extractText(String imagePath) async {
    final result = await recognizeText(imagePath);
    return result.text;
  }

  /// Extract text as structured blocks (useful for layout-aware display)
  Future<List<TextBlock>> extractBlocks(String imagePath) async {
    final result = await recognizeText(imagePath);
    return result.blocks;
  }

  /// Dispose the recognizer when done
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
