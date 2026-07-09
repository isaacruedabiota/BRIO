import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_snack.dart';
import '../../data/label_ocr.dart';
import '../providers/nutrition_providers.dart';

/// Form to create a custom food (manually or by scanning the label).
/// On save, returns the created FoodItem to the caller via `context.pop(food)`.
class CreateFoodPage extends ConsumerStatefulWidget {
  const CreateFoodPage({super.key});

  @override
  ConsumerState<CreateFoodPage> createState() => _CreateFoodPageState();
}

class _CreateFoodPageState extends ConsumerState<CreateFoodPage> {
  final _name    = TextEditingController();
  final _brand   = TextEditingController();
  final _kcal    = TextEditingController();
  final _protein = TextEditingController();
  final _carbs   = TextEditingController();
  final _fat     = TextEditingController();
  final _fiber   = TextEditingController();

  bool _saving = false;
  bool _scanning = false;
  bool _fromScan = false;            // shows the "review the values" notice
  final Set<String> _scanned = {};   // fields filled by the OCR (highlighted)

  @override
  void dispose() {
    for (final c in [_name, _brand, _kcal, _protein, _carbs, _fat, _fiber]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _valid =>
      _name.text.trim().length >= 2 && (_parse(_kcal) ?? -1) >= 0 && _kcal.text.trim().isNotEmpty;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    LabelScanResult? res;
    try {
      res = await scanNutritionLabel();
    } catch (_) {
      res = null;
    }
    if (!mounted) return;
    setState(() => _scanning = false);

    if (res == null) return; // cancelled
    final f = res.facts;
    if (!f.hasAny) {
      BrioSnack.error(context, 'No se pudo leer la tabla. Prueba con más luz o rellénalo a mano.');
      return;
    }
    setState(() {
      _fromScan = true;
      _scanned.clear();
      void fill(double? v, TextEditingController c, String key) {
        if (v != null) {
          c.text = _fmt(v);
          _scanned.add(key);
        }
      }
      fill(f.kcal, _kcal, 'kcal');
      fill(f.protein, _protein, 'protein');
      fill(f.carbs, _carbs, 'carbs');
      fill(f.fat, _fat, 'fat');
      fill(f.fiber, _fiber, 'fiber');
    });
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    final food = await createFood(
      ref,
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      kcalPer100g:    _parse(_kcal) ?? 0,
      proteinPer100g: _parse(_protein) ?? 0,
      carbsPer100g:   _parse(_carbs) ?? 0,
      fatPer100g:     _parse(_fat) ?? 0,
      fiberPer100g:   _parse(_fiber) ?? 0,
    );
    if (!mounted) return;
    if (food != null) {
      context.pop(food);
      BrioSnack.success(context, 'Alimento creado y guardado en tus alimentos.');
    } else {
      setState(() => _saving = false);
      BrioSnack.error(context, 'No se pudo crear el alimento.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        title: const Text('Nuevo alimento'),
        actions: [
          TextButton(
            onPressed: (_valid && !_saving) ? _save : null,
            child: Text('Guardar', style: BrioTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: (_valid && !_saving) ? BrioColors.blue : BrioColors.textTertiary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          // Scan label.
          _ScanButton(loading: _scanning, onTap: _scanning ? null : _scan),
          const SizedBox(height: 16),

          if (_fromScan)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BrioColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: BrioColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Leído de la etiqueta. Revisa que todo sea correcto antes de guardar.',
                  style: BrioTextStyles.bodySmall.copyWith(color: const Color(0xFFA9690B)),
                )),
              ]),
            ),

          _label('Nombre'),
          _field(_name, hint: 'Ej. Yogur griego natural', onChanged: (_) => setState(() {})),
          _label('Marca (opcional)'),
          _field(_brand, hint: 'Ej. Hacendado'),

          _label('Energía · por 100 g'),
          _field(_kcal, hint: '0', unit: 'kcal', number: true,
              highlight: _scanned.contains('kcal'), onChanged: (_) => setState(() {})),

          _label('Macros · por 100 g'),
          Row(children: [
            Expanded(child: _macro('Proteínas', _protein, BrioColors.protein, 'protein')),
            const SizedBox(width: 10),
            Expanded(child: _macro('Carbohidratos', _carbs, BrioColors.carbs, 'carbs')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _macro('Grasas', _fat, BrioColors.fat, 'fat')),
            const SizedBox(width: 10),
            Expanded(child: _macro('Fibra (opc.)', _fiber, BrioColors.textTertiary, 'fiber')),
          ]),

          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(99)),
              child: ElevatedButton(
                onPressed: (_valid && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  disabledBackgroundColor: BrioColors.bgElevated, shape: const StadiumBorder()),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Guardar alimento', style: BrioTextStyles.button),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 7),
        child: Text(t.toUpperCase(), style: BrioTextStyles.label.copyWith(fontSize: 10)),
      );

  Widget _macro(String label, TextEditingController c, Color color, String key) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: BrioTextStyles.bodySmall.copyWith(fontSize: 11, color: BrioColors.textSecondary)),
        const SizedBox(height: 5),
        _field(c, hint: '0', unit: 'g', number: true, accent: color,
            highlight: _scanned.contains(key)),
      ]);

  Widget _field(
    TextEditingController c, {
    String? hint,
    String? unit,
    bool number = false,
    Color? accent,
    bool highlight = false,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? BrioColors.warning.withValues(alpha: 0.08) : BrioColors.bgCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: highlight ? BrioColors.warning : BrioColors.border),
      ),
      child: Row(children: [
        if (accent != null)
          Container(width: 3, height: 30, margin: const EdgeInsets.only(left: 1),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        Expanded(
          child: TextField(
            controller: c,
            onChanged: onChanged,
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            inputFormatters: number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                : null,
            style: BrioTextStyles.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            ),
          ),
        ),
        if (unit != null)
          Padding(
            padding: const EdgeInsets.only(right: 13),
            child: Text(unit, style: BrioTextStyles.label.copyWith(fontSize: 11, color: BrioColors.textTertiary)),
          ),
      ]),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _ScanButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: BrioColors.gradient, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            else
              const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(loading ? 'Leyendo etiqueta…' : 'Escanear etiqueta',
                style: BrioTextStyles.button),
          ],
        ),
      ),
    );
  }
}
