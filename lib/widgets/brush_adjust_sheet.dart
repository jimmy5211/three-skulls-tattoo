import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/brush_model.dart';
import '../theme/app_theme.dart';

// ─── Colores internos ─────────────────────────────────────────────────────────
const _bg    = Color(0xFF1A1A1A);
const _card  = Color(0xFF242424);
const _bord  = Color(0xFF333333);
const _txt1  = Colors.white;
const Color _txt2  = Color(0xFFAAAAAA);
const _accent= AppTheme.accentRed;

// ─── Entry point ─────────────────────────────────────────────────────────────
/// Abre el panel de ajuste del pincel.
/// [onChanged] se llama en tiempo real con el pincel modificado.
Future<void> showBrushAdjustSheet(
  BuildContext context,
  BrushModel brush, {
  required void Function(BrushModel) onChanged,
  String? strokePreviewTitle,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BrushAdjustSheet(
      brush: brush,
      onChanged: onChanged,
      previewTitle: strokePreviewTitle,
    ),
  );
}

// ─── Sheet principal ─────────────────────────────────────────────────────────
class _BrushAdjustSheet extends StatefulWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final String? previewTitle;
  const _BrushAdjustSheet({
    required this.brush,
    required this.onChanged,
    this.previewTitle,
  });

  @override
  State<_BrushAdjustSheet> createState() => _BrushAdjustSheetState();
}

class _BrushAdjustSheetState extends State<_BrushAdjustSheet>
    with SingleTickerProviderStateMixin {
  late BrushModel _brush;
  late TabController _tabs;
  BrushModel? _original; // para botón reset

  static const _tabLabels = ['General', 'Forma', 'Textura', 'Cepillo\ndoble', 'Lápiz'];
  static const _tabIcons  = [
    Icons.tune,
    Icons.flutter_dash,
    Icons.grain,
    Icons.content_copy_outlined,
    Icons.edit_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _brush    = widget.brush;
    _original = widget.brush.copyWith();
    _tabs     = TabController(length: 5, vsync: this);
  }

  void _update(BrushModel b) {
    setState(() => _brush = b);
    widget.onChanged(b);
  }

  void _reset() => _update(_original!.copyWith());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _bord,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 6),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              // Preview del trazo
              Expanded(
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bord),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.previewTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(widget.previewTitle!,
                                style: const TextStyle(
                                    color: _txt2, fontSize: 11,
                                    fontFamily: 'Raleway')),
                          ),
                        CustomPaint(
                          size: const Size(double.infinity, 36),
                          painter: _StrokePreviewPainter(_brush),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botones header
              Column(children: [
                _iconBtn(Icons.close,    () => Navigator.pop(context)),
                const SizedBox(height: 6),
                _iconBtn(Icons.refresh,  _reset),
                const SizedBox(height: 6),
                _iconBtn(Icons.arrow_back_ios_new,
                    () => Navigator.pop(context)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),

          // Tabs
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _bord))),
            child: TabBar(
              controller: _tabs,
              isScrollable: false,
              indicatorColor: _accent,
              indicatorWeight: 2,
              labelColor: _accent,
              unselectedLabelColor: _txt2,
              labelStyle: const TextStyle(fontFamily: 'Raleway', fontSize: 10,
                  fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Raleway', fontSize: 10),
              tabs: List.generate(5, (i) => Tab(
                iconMargin: const EdgeInsets.only(bottom: 2),
                icon: Icon(_tabIcons[i], size: 16),
                text: _tabLabels[i],
              )),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _GeneralTab(brush: _brush, onChanged: _update, sc: sc),
                _FormaTab(brush: _brush, onChanged: _update, sc: sc),
                _TexturaTab(brush: _brush, onChanged: _update, sc: sc),
                _CepilloDobleTab(brush: _brush, onChanged: _update, sc: sc),
                _LapizTab(brush: _brush, onChanged: _update, sc: sc),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bord)),
      child: Icon(icon, color: _txt2, size: 16),
    ),
  );
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

Widget _section(String title) => Padding(
  padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
  child: Text(title,
      style: const TextStyle(color: _txt1, fontFamily: 'Raleway',
          fontSize: 14, fontWeight: FontWeight.bold)),
);

Widget _divider() => const Divider(color: _bord, height: 1);

Widget _slider({
  required String label,
  required double value,
  required double min,
  required double max,
  required String display,
  required ValueChanged<double> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(
            color: _txt2, fontSize: 12, fontFamily: 'Raleway')),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(6)),
          child: Text(display, style: const TextStyle(
              color: _txt1, fontSize: 11, fontFamily: 'Raleway')),
        ),
      ]),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: _accent,
          inactiveTrackColor: _bord,
          thumbColor: Colors.white,
          overlayColor: _accent.withOpacity(0.2),
        ),
        child: Slider(
            value: value.clamp(min, max), min: min, max: max,
            onChanged: onChanged),
      ),
    ]),
  );
}

Widget _toggle({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(
          color: _txt1, fontSize: 13, fontFamily: 'Raleway'))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: _accent,
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: _bord,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ]),
  );
}

Widget _dropdown<T>({
  required String label,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(
          color: _txt1, fontSize: 13, fontFamily: 'Raleway'))),
      DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        dropdownColor: _card,
        style: const TextStyle(color: _txt1, fontFamily: 'Raleway', fontSize: 12),
        underline: Container(height: 1, color: _bord),
        icon: const Icon(Icons.keyboard_arrow_down, color: _txt2, size: 16),
      ),
    ]),
  );
}

Widget _tabBody({required Widget child, required ScrollController sc}) =>
    SingleChildScrollView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: child,
    );

Widget _iconBtn2(IconData icon, VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bord)),
    child: Icon(icon, color: _txt2, size: 18),
  ),
);

// ─── TAB 1: GENERAL ──────────────────────────────────────────────────────────
class _GeneralTab extends StatelessWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final ScrollController sc;
  const _GeneralTab({required this.brush, required this.onChanged, required this.sc});

  @override
  Widget build(BuildContext context) {
    return _tabBody(sc: sc, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Propiedades del trazo'),
        _slider(label: 'Tamaño de vista previa',
            value: brush.size, min: 1, max: 300,
            display: '${brush.size.round()}px',
            onChanged: (v) => onChanged(brush.copyWith(size: v))),
        _slider(label: 'Flujo',
            value: brush.flow, min: 0, max: 1,
            display: '${(brush.flow * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(flow: v))),
        _slider(label: 'Espaciado',
            value: brush.spacing, min: 0.05, max: 10,
            display: '${(brush.spacing * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(spacing: v))),
        _slider(label: 'Tamaño máximo',
            value: brush.size, min: 1, max: 300,
            display: '${brush.size.round()}px',
            onChanged: (v) => onChanged(brush.copyWith(size: v))),
        _slider(label: 'Tamaño mínimo',
            value: brush.sizeMin, min: 0, max: 1,
            display: '${(brush.sizeMin * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(sizeMin: v))),
        _slider(label: 'Flujo máximo',
            value: brush.flowMax, min: 0, max: 1,
            display: '${(brush.flowMax * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(flowMax: v))),
        _slider(label: 'Flujo mínimo',
            value: brush.flowMin, min: 0, max: 1,
            display: '${(brush.flowMin * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(flowMin: v))),
        _toggle(label: 'Acumulativo',
            value: brush.accumulative,
            onChanged: (v) => onChanged(brush.copyWith(accumulative: v))),
        _toggle(label: 'Presión de velocidad',
            value: brush.velocityPressure,
            onChanged: (v) => onChanged(brush.copyWith(velocityPressure: v))),
        _divider(),
        _section('Liso'),
        _toggle(label: 'Modo de línea profesional',
            value: brush.professionalLine,
            onChanged: (v) => onChanged(brush.copyWith(professionalLine: v))),
        _slider(label: 'Suavidad',
            value: brush.smoothing, min: 0, max: 1,
            display: '${(brush.smoothing * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(smoothing: v))),
        _divider(),
        _section('Detección inteligente'),
        _toggle(label: 'Detectar límites de capa de referencia',
            value: brush.detectRefLimits,
            onChanged: (v) => onChanged(brush.copyWith(detectRefLimits: v))),
        _divider(),
        _section('Cono de presión'),
        _toggle(label: 'Sincronización de cabeza y cola',
            value: brush.pressureConeSync,
            onChanged: (v) => onChanged(brush.copyWith(pressureConeSync: v))),
        _ConePressureWidget(brush: brush, onChanged: onChanged),
        _slider(label: 'Tamaño de la cabeza',
            value: brush.pressureConeHead, min: 0, max: 1,
            display: '${(brush.pressureConeHead * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(pressureConeHead: v))),
        _slider(label: 'Tamaño de la cola',
            value: brush.pressureConeTail, min: 0, max: 1,
            display: '${(brush.pressureConeTail * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(pressureConeTail: v))),
      ],
    ));
  }
}

// ─── Cono de presión visual ───────────────────────────────────────────────────
class _ConePressureWidget extends StatelessWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  const _ConePressureWidget({required this.brush, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bord)),
      child: CustomPaint(
        painter: _ConePreviewPainter(
            head: brush.pressureConeHead, tail: brush.pressureConeTail),
      ),
    );
  }
}

class _ConePreviewPainter extends CustomPainter {
  final double head, tail;
  const _ConePreviewPainter({required this.head, required this.tail});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height; final mid = h / 2;
    final path = Path();
    final hH = h * 0.4 * (1 - head);
    final tH = h * 0.4 * (1 - tail);
    path.moveTo(0, mid - hH);
    path.cubicTo(w * 0.3, mid - h * 0.4, w * 0.7, mid - h * 0.4, w, mid - tH);
    path.lineTo(w, mid + tH);
    path.cubicTo(w * 0.7, mid + h * 0.4, w * 0.3, mid + h * 0.4, 0, mid + hH);
    path.close();
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        colors: [Colors.white24, Colors.white54, Colors.white24],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
  }
  @override bool shouldRepaint(_ConePreviewPainter o) => o.head != head || o.tail != tail;
}

// ─── TAB 2: FORMA ────────────────────────────────────────────────────────────
class _FormaTab extends StatelessWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final ScrollController sc;
  const _FormaTab({required this.brush, required this.onChanged, required this.sc});

  @override
  Widget build(BuildContext context) {
    return _tabBody(sc: sc, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Imagen de la forma'),
        // Flip X / Y / Alpha
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bord)),
          child: Row(children: [
            // Preview círculo
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8)),
              child: CustomPaint(
                painter: _ShapePreviewPainter(brush),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              _toggle(label: 'Voltear X', value: brush.flipX,
                  onChanged: (v) => onChanged(brush.copyWith(flipX: v))),
              _toggle(label: 'Voltear Y', value: brush.flipY,
                  onChanged: (v) => onChanged(brush.copyWith(flipY: v))),
              _toggle(label: 'Convertir a transparencia',
                  value: brush.convertToAlpha,
                  onChanged: (v) => onChanged(brush.copyWith(convertToAlpha: v))),
            ])),
          ]),
        ),
        _section('Ajuste de la forma'),
        _section('Efecto de forma'),
        _slider(label: 'Suavizado',
            value: brush.shapeSmoothing, min: 0, max: 1,
            display: '${(brush.shapeSmoothing * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(shapeSmoothing: v))),
        _slider(label: 'Redondez',
            value: brush.shapeRoundness, min: 0, max: 1,
            display: '${(brush.shapeRoundness * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(shapeRoundness: v))),
        _slider(label: 'Ángulo',
            value: brush.shapeAngle, min: 0, max: 360,
            display: '${brush.shapeAngle.round()}°',
            onChanged: (v) => onChanged(brush.copyWith(shapeAngle: v))),
        _slider(label: 'Contador',
            value: brush.shapeCount.toDouble(), min: 1, max: 8,
            display: '${brush.shapeCount}',
            onChanged: (v) => onChanged(brush.copyWith(shapeCount: v.round()))),
        _slider(label: 'Contador de fluctuaciones',
            value: brush.shapeCountJitter, min: 0, max: 1,
            display: '${(brush.shapeCountJitter * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(shapeCountJitter: v))),
        _slider(label: 'Dispersión',
            value: brush.scatter, min: 0, max: 1,
            display: '${(brush.scatter * 100).round()}%',
            onChanged: (v) => onChanged(brush.copyWith(scatter: v))),
        _toggle(label: 'Dispersión bidimensional',
            value: brush.scatter2D,
            onChanged: (v) => onChanged(brush.copyWith(scatter2D: v))),
        _dropdown<BlendModeType>(
          label: 'Modo mixto',
          value: brush.blendMode,
          items: const [
            DropdownMenuItem(value: BlendModeType.estandar,    child: Text('Estándar')),
            DropdownMenuItem(value: BlendModeType.multiplicar,  child: Text('Multiplicar')),
            DropdownMenuItem(value: BlendModeType.pantalla,     child: Text('Pantalla')),
            DropdownMenuItem(value: BlendModeType.superposicion,child: Text('Superposición')),
            DropdownMenuItem(value: BlendModeType.luz,          child: Text('Luz')),
          ],
          onChanged: (v) { if (v != null) onChanged(brush.copyWith(blendMode: v)); },
        ),
        _dropdown<RotationDynamic>(
          label: 'Dinámica de rotación',
          value: brush.rotationDynamic,
          items: const [
            DropdownMenuItem(value: RotationDynamic.fijo,        child: Text('Fijo')),
            DropdownMenuItem(value: RotationDynamic.libre,       child: Text('Libre 360°')),
            DropdownMenuItem(value: RotationDynamic.seguirTrazo, child: Text('Seguir trazo')),
            DropdownMenuItem(value: RotationDynamic.aleteo,      child: Text('Aleteo')),
          ],
          onChanged: (v) { if (v != null) onChanged(brush.copyWith(rotationDynamic: v)); },
        ),
      ],
    ));
  }
}

// ─── Shape preview painter ───────────────────────────────────────────────────
class _ShapePreviewPainter extends CustomPainter {
  final BrushModel brush;
  const _ShapePreviewPainter(this.brush);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final rx = cx * brush.shapeRoundness;
    final ry = cy * brush.shapeRoundness;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(brush.shapeAngle * pi / 180);
    if (brush.flipX) canvas.scale(-1, 1);
    if (brush.flipY) canvas.scale(1, -1);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()..color = Colors.white70
               ..maskFilter = MaskFilter.blur(BlurStyle.normal, (1 - brush.shapeSmoothing) * 4 + 0.1));
    canvas.restore();
  }
  @override bool shouldRepaint(_ShapePreviewPainter o) => o.brush != brush;
}

// ─── TAB 3: TEXTURA ──────────────────────────────────────────────────────────
class _TexturaTab extends StatelessWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final ScrollController sc;
  const _TexturaTab({required this.brush, required this.onChanged, required this.sc});

  @override
  Widget build(BuildContext context) {
    return _tabBody(sc: sc, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Textura de grano'),
        if (brush.grainAsset == null)
          GestureDetector(
            onTap: () {/* TODO: abrir selector de PNG */},
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bord)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: _txt2),
                  SizedBox(width: 8),
                  Text('Agregar textura', style: TextStyle(
                      color: _txt2, fontFamily: 'Raleway', fontSize: 13)),
                ],
              ),
            ),
          )
        else ...[
          Container(
            height: 60,
            decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent)),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.image_outlined, color: _accent),
                const SizedBox(width: 8),
                Expanded(child: Text(brush.grainAsset!,
                    style: const TextStyle(color: _txt1,
                        fontFamily: 'Raleway', fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.close, color: _txt2, size: 18),
                  onPressed: () => onChanged(brush.copyWith(grainAsset: null)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _slider(label: 'Profundidad del grano',
              value: brush.grainDepth, min: 0, max: 1,
              display: '${(brush.grainDepth * 100).round()}%',
              onChanged: (v) => onChanged(brush.copyWith(grainDepth: v))),
        ],
        const SizedBox(height: 20),
        Center(child: Text('Las texturas .png se pueden importar\ndesde /ThreeSkulls/importar/',
            textAlign: TextAlign.center,
            style: TextStyle(color: _txt2.withOpacity(0.6),
                fontSize: 11, fontFamily: 'Raleway'))),
      ],
    ));
  }
}

// ─── TAB 4: CEPILLO DOBLE ────────────────────────────────────────────────────
class _CepilloDobleTab extends StatelessWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final ScrollController sc;
  const _CepilloDobleTab({required this.brush, required this.onChanged, required this.sc});

  @override
  Widget build(BuildContext context) {
    return _tabBody(sc: sc, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Cepillo doble'),
        _toggle(label: 'Activar cepillo doble',
            value: brush.doubleBrushOn,
            onChanged: (v) => onChanged(brush.copyWith(doubleBrushOn: v))),
        if (!brush.doubleBrushOn)
          GestureDetector(
            onTap: () => onChanged(brush.copyWith(doubleBrushOn: true)),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bord)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: _txt2),
                  SizedBox(width: 8),
                  Text('Agregar cepillo doble', style: TextStyle(
                      color: _txt2, fontFamily: 'Raleway', fontSize: 13)),
                ],
              ),
            ),
          ),
        if (brush.doubleBrushOn) ...[
          const SizedBox(height: 8),
          Text('Selecciona un pincel secundario que se combinará con éste.',
              style: TextStyle(color: _txt2, fontSize: 12, fontFamily: 'Raleway')),
          // TODO: selector de brushId secundario
        ],
      ],
    ));
  }
}

// ─── TAB 5: LÁPIZ ────────────────────────────────────────────────────────────
class _LapizTab extends StatefulWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  final ScrollController sc;
  const _LapizTab({required this.brush, required this.onChanged, required this.sc});
  @override
  State<_LapizTab> createState() => _LapizTabState();
}

class _LapizTabState extends State<_LapizTab> {
  bool _showPressure = true; // true=Presión, false=Inclinación

  @override
  Widget build(BuildContext context) {
    final b = widget.brush;
    return _tabBody(sc: widget.sc, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector Presión / Inclinación
        Container(
          height: 38,
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bord)),
          child: Row(children: [
            Expanded(child: _tabToggle('Presión',   _showPressure,  () => setState(() => _showPressure = true))),
            Expanded(child: _tabToggle('Inclinación',!_showPressure,() => setState(() => _showPressure = false))),
          ]),
        ),
        const SizedBox(height: 12),

        if (_showPressure) ...[
          _slider(label: 'Tamaño',
              value: b.pressureSizeOn ? 1.0 : 0.0, min: 0, max: 1,
              display: b.pressureSizeOn ? '100%' : '0%',
              onChanged: (v) => widget.onChanged(b.copyWith(pressureSizeOn: v > 0.5))),
          _slider(label: 'Flujo',
              value: b.pressureFlowOn ? 1.0 : 0.0, min: 0, max: 1,
              display: b.pressureFlowOn ? '100%' : '0%',
              onChanged: (v) => widget.onChanged(b.copyWith(pressureFlowOn: v > 0.5))),
          _section('Curva de sensibilidad a la presión'),
          _PressureCurveEditor(brush: b, onChanged: widget.onChanged),
        ] else ...[
          _slider(label: 'Ángulo de inclinación',
              value: 0, min: 0, max: 1,
              display: '0%',
              onChanged: (_) {}),
          _slider(label: 'Tamaño',
              value: b.tiltSizeOn ? 1.0 : 0.0, min: 0, max: 1,
              display: b.tiltSizeOn ? '100%' : '0%',
              onChanged: (v) => widget.onChanged(b.copyWith(tiltSizeOn: v > 0.5))),
          _slider(label: 'Flujo',
              value: b.tiltFlowOn ? 1.0 : 0.0, min: 0, max: 1,
              display: b.tiltFlowOn ? '100%' : '0%',
              onChanged: (v) => widget.onChanged(b.copyWith(tiltFlowOn: v > 0.5))),
          _slider(label: 'Degradado',
              value: 0, min: 0, max: 1,
              display: '0%',
              onChanged: (_) {}),
        ],
      ],
    ));
  }

  Widget _tabToggle(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
              color: active ? Colors.white : _txt2,
              fontFamily: 'Raleway', fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      );
}

// ─── Editor de curva de presión ───────────────────────────────────────────────
class _PressureCurveEditor extends StatefulWidget {
  final BrushModel brush;
  final void Function(BrushModel) onChanged;
  const _PressureCurveEditor({required this.brush, required this.onChanged});
  @override
  State<_PressureCurveEditor> createState() => _PressureCurveEditorState();
}

class _PressureCurveEditorState extends State<_PressureCurveEditor> {
  late Offset _p1, _p2;

  @override
  void initState() {
    super.initState();
    _p1 = Offset(widget.brush.pressureCurveP1x, widget.brush.pressureCurveP1y);
    _p2 = Offset(widget.brush.pressureCurveP2x, widget.brush.pressureCurveP2y);
  }

  void _notify() => widget.onChanged(widget.brush.copyWith(
    pressureCurveP1x: _p1.dx, pressureCurveP1y: _p1.dy,
    pressureCurveP2x: _p2.dx, pressureCurveP2y: _p2.dy,
  ));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (det) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(det.globalPosition);
        final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
        final ny = 1.0 - (local.dy / box.size.height).clamp(0.0, 1.0);
        // Asignar al punto más cercano
        final d1 = (_p1 - Offset(nx, ny)).distance;
        final d2 = (_p2 - Offset(nx, ny)).distance;
        setState(() {
          if (d1 < d2) _p1 = Offset(nx, ny);
          else         _p2 = Offset(nx, ny);
        });
        _notify();
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bord)),
        child: CustomPaint(
          painter: _PressureCurvePainter(_p1, _p2),
        ),
      ),
    );
  }
}

class _PressureCurvePainter extends CustomPainter {
  final Offset p1, p2;
  const _PressureCurvePainter(this.p1, this.p2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;

    // Grid
    final gridPaint = Paint()..color = Colors.white10..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(w * i / 4, 0), Offset(w * i / 4, h), gridPaint);
      canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }

    // Convertir coords normalizadas a píxeles
    Offset toPixel(Offset n) => Offset(n.dx * w, (1 - n.dy) * h);

    final start = Offset(0, h);
    final end   = Offset(w, 0);
    final cp1   = toPixel(p1);
    final cp2   = toPixel(p2);

    // Curva
    final path = Path()..moveTo(start.dx, start.dy);
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(path, Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke);

    // Puntos de control
    final dotPaint = Paint()..color = _accent..style = PaintingStyle.fill;
    canvas.drawCircle(cp1, 8, dotPaint);
    canvas.drawCircle(cp2, 8, dotPaint);
    canvas.drawLine(start, cp1, Paint()..color = Colors.white30..strokeWidth = 1);
    canvas.drawLine(end,   cp2, Paint()..color = Colors.white30..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_PressureCurvePainter o) => o.p1 != p1 || o.p2 != p2;
}

// ─── Stroke preview painter ───────────────────────────────────────────────────
class _StrokePreviewPainter extends CustomPainter {
  final BrushModel brush;
  const _StrokePreviewPainter(this.brush);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const segs = 50;
    final head = brush.pressureConeHead.clamp(0.0, 1.0);
    final tail = brush.pressureConeTail.clamp(0.0, 1.0);
    final id = brush.id;
    final maxSw = h * 0.32;

    for (int i = 0; i < segs - 1; i++) {
      final t0 = i / (segs - 1.0);
      final t1 = (i + 1) / (segs - 1.0);
      final x0 = w * (0.03 + t0 * 0.94);
      final x1 = w * (0.03 + t1 * 0.94);
      final y0 = h * 0.5 + h * 0.3 * sin(t0 * pi * 1.5);
      final y1 = h * 0.5 + h * 0.3 * sin(t1 * pi * 1.5);

      // Presión con cono de cabeza y cola
      final headLen = 0.12 + head * 0.28;
      final tailLen = 0.12 + tail * 0.28;
      double p = 1.0;
      if (t0 < headLen && head > 0.01)
        p = (t0 / headLen).clamp(0.05, 1.0);
      if (t0 > 1.0 - tailLen && tail > 0.01)
        p = ((1.0 - t0) / tailLen).clamp(0.05, 1.0);
      p = p * (1.0 - (head > 0.01 || tail > 0.01 ? 0.0 : 0.0)); // sin min si hay cono

      final sw = (maxSw * p).clamp(0.8, maxSw);
      final opacity = brush.opacity.clamp(0.1, 1.0);

      // Glow extra para aerógrafo y luminancia
      if (id.startsWith('aero') || id.startsWith('lum')) {
        canvas.drawLine(Offset(x0,y0), Offset(x1,y1), Paint()
          ..color = Colors.white.withOpacity(0.06)
          ..strokeWidth = sw * 3.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
          ..style = PaintingStyle.stroke);
      }

      canvas.drawLine(Offset(x0,y0), Offset(x1,y1), Paint()
        ..color = Colors.white.withOpacity(opacity * (id.startsWith('aero') ? 0.6 : 0.88))
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_StrokePreviewPainter o) =>
      o.brush.id != brush.id ||
      o.brush.opacity != brush.opacity ||
      o.brush.pressureConeHead != brush.pressureConeHead ||
      o.brush.pressureConeTail != brush.pressureConeTail;
}
