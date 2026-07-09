// On-device nutrition-label OCR with Google ML Kit (offline).
//
// Takes a photo with the camera, recognizes the text on-device (no external
// service calls) and parses it into per-100g values.
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/label_parser.dart';

class LabelScanResult {
  final NutritionFacts facts;
  final String rawText;
  const LabelScanResult({required this.facts, required this.rawText});
}

/// Opens the camera, reads the table and returns the detected values.
/// Returns null if the user cancels the photo.
Future<LabelScanResult?> scanNutritionLabel({ImageSource source = ImageSource.camera}) async {
  final picker = ImagePicker();
  final shot = await picker.pickImage(source: source, imageQuality: 90);
  if (shot == null) return null;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(InputImage.fromFilePath(shot.path));
    return LabelScanResult(
      facts: parseNutritionText(recognized.text),
      rawText: recognized.text,
    );
  } finally {
    await recognizer.close();
  }
}
