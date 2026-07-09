import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../domain/entities/daily_log.dart';

/// "Friendly" food icon (Fitia-style):
///  - An emoji for the food type (chicken, rice, pasta…) over a background
///    tinted with its dominant macro color (protein/carbs/fat).
///  - For generic products with no recognizable type, the BRIO (arc) logo.
class FoodIcon extends StatelessWidget {
  final FoodItem food;
  final double size;
  const FoodIcon({super.key, required this.food, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final emoji = foodEmoji(food.name);
    final radius = size * 0.3;

    if (emoji == null) {
      // Generic → BRIO arc.
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: BrioColors.blue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: SizedBox(
            width: size * 0.5, height: size * 0.5,
            child: CustomPaint(painter: _BrioMarkPainter()),
          ),
        ),
      );
    }

    final color = dominantMacroColor(food);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

/// Color of the macro that contributes the most calories to the food.
Color dominantMacroColor(FoodItem f) {
  final p = f.proteinPer100g * 4;
  final c = f.carbsPer100g * 4;
  final ft = f.fatPer100g * 9;
  if (p >= c && p >= ft) return BrioColors.protein;
  if (c >= ft) return BrioColors.carbs;
  return BrioColors.fat;
}

/// Emoji for the food type, or null if not recognized (→ BRIO logo).
String? foodEmoji(String name) {
  final n = _normalize(name);
  for (final entry in _map) {
    for (final k in entry.$1) {
      if (n.contains(k)) return entry.$2;
    }
  }
  return null;
}

/// Standard serving/unit of a food: (label, grams).
/// For natural foods it returns their own unit (1 banana ≈ 120 g, 1 egg ≈ 60
/// g…). Defaults to a 'ración' (serving) of 100 g.
(String, double) servingFor(String name) {
  final n = _normalize(name);
  for (final e in _servings) {
    for (final k in e.$1) {
      if (n.contains(k)) return (e.$2, e.$3);
    }
  }
  return ('ración', 100);
}

const _servings = <(List<String>, String, double)>[
  (['platano', 'banana'], 'plátano', 120),
  (['manzana'], 'manzana', 180),
  (['naranja', 'mandarina'], 'pieza', 130),
  (['pera'], 'pera', 170),
  (['kiwi'], 'kiwi', 75),
  (['melocoton', 'durazno'], 'pieza', 150),
  (['fresa', 'uva', 'arandano'], 'puñado', 100),
  (['huevo'], 'huevo', 60),
  (['pan', 'tostada', 'rebanada', 'molde', 'pita'], 'rebanada', 35),
  (['yogur'], 'yogur', 125),
  (['leche', 'batido', 'zumo', 'jugo'], 'vaso', 200),
  (['queso'], 'loncha', 30),
  (['aceite'], 'cucharada', 10),
  (['almendra', 'nuez', 'nueces', 'anacardo', 'cacahuet', 'pistacho', 'avellana', 'frutos secos'], 'puñado', 30),
  (['arroz'], 'ración', 70),
  (['pasta', 'espagueti', 'macarron', 'fideo', 'noodle'], 'ración', 80),
  (['pollo', 'pechuga', 'ternera', 'cerdo', 'lomo', 'atun', 'salmon', 'pescado', 'merluza', 'filete'], 'filete', 150),
  (['lenteja', 'garbanz', 'alubia', 'judia', 'legumbre'], 'ración', 80),
  (['pizza'], 'porción', 125),
  (['platano'], 'unidad', 120),
];

String _normalize(String s) {
  s = s.toLowerCase();
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to   = 'aaaaeeeeiiiioooouuuunc';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

// Order: most specific first (dishes), then ingredients.
const _map = <(List<String>, String)>[
  // Prepared dishes.
  (['pizza'], '🍕'),
  (['hamburgues', 'burger'], '🍔'),
  (['sandwich', 'bocadillo', 'sandvich'], '🥪'),
  (['salchicha', 'frankfurt', 'perrito caliente'], '🌭'),
  (['kebab', 'shawarma', 'doner', 'fajita', 'burrito', 'taco'], '🌯'),
  (['sushi', 'maki', 'nigiri'], '🍣'),
  (['gyoza', 'dumpling', 'empanad', 'flauta'], '🥟'),
  (['nugget', 'delicias', 'tiras de', 'fingers'], '🍗'),
  // Proteins.
  (['pollo', 'pavo', 'pechuga', 'muslit', 'muslo', 'roti', 'brasead'], '🍗'),
  (['ternera', 'vacuno', 'buey', 'solomillo', 'entrecot', 'filete', 'albondig'], '🥩'),
  (['cerdo', 'jamon', 'bacon', 'lomo', 'chuleta', 'panceta', 'fiambre', 'pavo'], '🥓'),
  (['atun', 'salmon', 'pescado', 'merluza', 'bacalao', 'sardina', 'caballa', 'lubina'], '🐟'),
  (['gamba', 'langostino', 'marisco', 'mejillon', 'pulpo', 'calamar'], '🦐'),
  (['huevo', 'tortilla', 'revuelto'], '🥚'),
  (['carne'], '🥩'),
  // Carbohydrates.
  (['arroz', 'risotto'], '🍚'),
  (['pasta', 'espagueti', 'spaghetti', 'macarron', 'fideo', 'noodle', 'yakisoba',
    'gnocchi', 'lasan', 'ravioli', 'tallarin', 'penne'], '🍝'),
  (['avena', 'cereal', 'muesli', 'granola', 'copos'], '🥣'),
  (['pan', 'tostada', 'baguette', 'molde', 'pita'], '🍞'),
  (['patata', 'papa'], '🥔'),
  (['croissant', 'bolleria', 'donut', 'muffin', 'bizcocho', 'magdalena'], '🥐'),
  (['galleta', 'cookie'], '🍪'),
  // Legumes.
  (['lenteja', 'garbanz', 'alubia', 'judia', 'frijol', 'haba', 'legumbre'], '🫘'),
  // Dairy.
  (['queso'], '🧀'),
  (['yogur', 'yogurt'], '🥛'),
  (['leche', 'batido'], '🥛'),
  (['mantequilla', 'nata'], '🧈'),
  // Fats.
  (['aceite', 'oliva'], '🫒'),
  (['almendra', 'nuez', 'nueces', 'anacardo', 'cacahuet', 'pistacho', 'avellana', 'frutos secos'], '🥜'),
  (['aguacate'], '🥑'),
  (['chocolate', 'cacao'], '🍫'),
  // Fruit.
  (['manzana'], '🍎'),
  (['platano', 'banana'], '🍌'),
  (['naranja', 'mandarina'], '🍊'),
  (['fresa'], '🍓'),
  (['uva'], '🍇'),
  (['sandia'], '🍉'),
  (['pera'], '🍐'),
  (['melocoton', 'durazno'], '🍑'),
  (['kiwi'], '🥝'),
  (['piña', 'pina'], '🍍'),
  (['limon'], '🍋'),
  (['tomate'], '🍅'),
  // Vegetables.
  (['brocoli'], '🥦'),
  (['zanahoria'], '🥕'),
  (['ensalada', 'lechuga', 'verdura', 'espinaca', 'rucula'], '🥗'),
  (['maiz'], '🌽'),
  (['pepino'], '🥒'),
  (['pimiento'], '🫑'),
  (['champin', 'seta', 'hongo'], '🍄'),
  // Dishes / soups.
  (['sopa', 'caldo', 'crema'], '🍲'),
  (['curry'], '🍛'),
  (['salteado', 'wok'], '🍜'),
  // Drinks.
  (['cafe'], '☕'),
  (['cerveza'], '🍺'),
  (['zumo', 'jugo'], '🧃'),
];

class _BrioMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width * 0.18;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(sw / 2 + 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft, end: Alignment.topRight,
        colors: [Color(0xFF1B6FD0), Color(0xFF329FFC), Color(0xFF7FC4FF)],
      ).createShader(rect);
    // Same arc as the logo: 270° open, starting at 135°.
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_BrioMarkPainter old) => false;
}
