// lib/features/smart/data/receipt_ocr_mlkit.dart
import 'dart:io' show Platform;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

bool get isOnDeviceOcrAvailable => Platform.isAndroid || Platform.isIOS;

/// Baca teks dari foto struk. Mengembalikan null bila gagal.
Future<String?> recognizeReceiptText(String imagePath) async {
  if (!isOnDeviceOcrAvailable) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  } finally {
    await recognizer.close();
  }
}
