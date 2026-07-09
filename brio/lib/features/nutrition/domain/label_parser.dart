/// Pure, testable parsing of the OCR-read nutrition table.
///
/// Reads Spanish labels: "Valor energético", "Grasas", "Hidratos de carbono",
/// "Proteínas", "Fibra". Assumes the "per 100 g" column (usually the first one).
/// It isn't perfect: the user reviews the values before saving.
library;

class NutritionFacts {
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;

  const NutritionFacts({this.kcal, this.protein, this.carbs, this.fat, this.fiber});

  bool get hasAny =>
      kcal != null || protein != null || carbs != null || fat != null || fiber != null;
}

/// Turns raw OCR text into per-100g values (whatever it can detect).
NutritionFacts parseNutritionText(String raw) {
  if (raw.trim().isEmpty) return const NutritionFacts();

  // Normalize: lowercase and decimal comma → dot (1,5 → 1.5).
  final text = raw.toLowerCase().replaceAllMapped(
        RegExp(r'(\d),(\d)'),
        (m) => '${m[1]}.${m[2]}',
      );
  final lines = text.split(RegExp(r'[\n\r]+'));

  return NutritionFacts(
    kcal:    _kcal(text),
    fat:     _lineValue(lines, include: ['grasa'], exclude: ['satura']),
    carbs:   _lineValue(lines, include: ['hidrato', 'carbohidrat'], exclude: ['azúcar', 'azucar']),
    protein: _lineValue(lines, include: ['proteí', 'protei']),
    fiber:   _lineValue(lines, include: ['fibra']),
  );
}

final _num = RegExp(r'(\d+(?:\.\d+)?)');

/// kcal: the number right before "kcal". If only kJ is present, converts it.
double? _kcal(String text) {
  final kcalMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kcal').firstMatch(text);
  if (kcalMatch != null) return double.tryParse(kcalMatch.group(1)!);
  final kjMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kj').firstMatch(text);
  if (kjMatch != null) {
    final kj = double.tryParse(kjMatch.group(1)!);
    if (kj != null) return (kj / 4.184).roundToDouble();
  }
  return null;
}

/// First number on the first line that contains any of `include` and none of
/// `exclude`.
double? _lineValue(
  List<String> lines, {
  required List<String> include,
  List<String> exclude = const [],
}) {
  for (final line in lines) {
    final hit = include.any(line.contains);
    if (!hit) continue;
    if (exclude.any(line.contains)) continue;
    final m = _num.firstMatch(line);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null) return v;
    }
  }
  return null;
}
