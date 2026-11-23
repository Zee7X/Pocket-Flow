// lib/features/smart/data/receipt_ocr.dart
//
// OCR struk di perangkat (Google ML Kit, gratis, offline) untuk Android/iOS.
// Di web tidak tersedia; foto dikirim langsung ke AI.
export 'receipt_ocr_stub.dart' if (dart.library.io) 'receipt_ocr_mlkit.dart';
