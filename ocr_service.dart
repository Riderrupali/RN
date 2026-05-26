import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService instance = OcrService._internal();
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  OcrService._internal();

  Future<String> extractTextFromFile(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);
      return recognizedText.text.isNotEmpty
          ? recognizedText.text
          : 'No text found on screen.';
    } catch (e) {
      return 'Could not read screen text.';
    }
  }

  Future<String> extractTextFromPath(String path) async {
    final file = File(path);
    return extractTextFromFile(file);
  }

  void dispose() {
    _recognizer.close();
  }
}
