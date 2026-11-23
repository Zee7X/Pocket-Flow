// lib/features/smart/data/receipt_ocr_stub.dart
/// OCR tidak tersedia di platform ini (web).
Future<String?> recognizeReceiptText(String imagePath) async => null;

bool get isOnDeviceOcrAvailable => false;
