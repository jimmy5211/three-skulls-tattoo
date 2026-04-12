import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

enum CanvasUnit { px, cm, mm, inch }
enum CanvasDpi { dpi72, dpi150, dpi300 }
enum CanvasOrientation { vertical, horizontal }
enum CanvasBackground { transparente, blanco, negro }

class NewDesignScreen extends StatefulWidget {
  const NewDesignScreen({super.key});

  @override
  State<NewDesignScreen> createState() => _NewDesignScreenState();
}

class _NewDesignScreenState extends State<NewDesignScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Sin título');
  final TextEditingController _widthController =
      TextEditingController(text: '10');
  final TextEditingController _heightController =
      TextEditingController(text: '15');

  CanvasUnit _unit = CanvasUnit.cm;
  CanvasDpi _dpi = CanvasDpi.dpi150;
  CanvasOrientation _orientation = CanvasOrientation.vertical;
  CanvasBackground _background = CanvasBackground.transparente;

  // Preset seleccionado actualmente
  int? _selectedPreset;

  static const Color _bgColor = Color(0xFF000000);
  static const Color _panelColor = Color(0xFF1C1C1E);
  static const Color _cardColor = Color(0xFF2C2C2E);
  static const Color _borderColor = Color(0xFF48484A);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFF8E8E93);

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Muñeca',    'w': '5',  'h': '7',  'unit': CanvasUnit.cm},
    {'name': 'Antebrazo', 'w': '10', 'h': '15', 'unit': CanvasUnit.cm},
    {'name': 'Espalda',   'w': '25', 'h': '35', 'unit': CanvasUnit.cm},
    {'name': 'Pecho',     'w': '20', 'h': '20', 'unit': CanvasUnit.cm},
    {'name': 'Tobillo',   'w': '6',  'h': '8',  'unit': CanvasUnit.cm},
    {'name': 'Cuello',    'w': '4',  'h': '5',  'unit': CanvasUnit.cm},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  int get _dpiValue {
    switch (_dpi) {
      case CanvasDpi.dpi72:  return 72;
      case CanvasDpi.dpi150: return 150;
      case CanvasDpi.dpi300: return 300;
    }
  }

  String get _dpiLabel {
    switch (_dpi) {
      case CanvasDpi.dpi72:  return '72 DPI — Pantalla';
      case CanvasDpi.dpi150: return '150 DPI — Estándar';
      case CanvasDpi.dpi300: return '300 DPI — Impresión';
    }
  }

  String get _unitLabel {
    switch (_unit) {
      case CanvasUnit.px:   return 'px';
      case CanvasUnit.cm:   return 'cm';
      case CanvasUnit.mm:   return 'mm';
      case CanvasUnit.inch: return 'in';
    }
  }

  int _toPixels(double value) {
    switch (_unit) {
      case CanvasUnit.px:   return value.round();
      case CanvasUnit.cm:   return (value * _dpiValue / 2.54).round();
      case CanvasUnit.mm:   return (value * _dpiValue / 25.4).round();
      case CanvasUnit.inch: return (value * _dpiValue).round();
    }
  }

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _selectedPreset = index;
      _widthController.text  = preset['w'] as String;
      _heightController.text = preset['h'] as String;
      _unit = preset['unit'] as CanvasUnit;
    });
  }

  void _swapDimensions() {
    setState(() {
      final tmp = _widthController.text;
      _widthController.text  = _heightController.text;
      _heightController.text = tmp;
      _orientation = _orientation == CanvasOrientation.vertical
          ? CanvasOrientation.horizontal
          : CanvasOrientation.vertical;
    });
  }

  void _createDesign() {
    final name = _nameController.text.trim().isEmpty
        ? 'Sin título'
        : _nameController.text.trim();

    final wVal = double.tryParse(_widthController.text) ?? 10;
    final hVal = double.tryParse(_heightController.text) ?? 15;
    final wPx  = _toPixels(wVal);
    final hPx  = _toPixels(hVal);

    context.go('/canvas', extra: {
      'name':        name,
      'widthPx':     wPx,
      'heightPx':    hPx,
      'dpi':         _dpiValue,
      'background':  _background.name,
      'orientation': _orientation.name,
      'unit':        _unitLabel,
      'widthVal':    wVal,
      'heightVal':   hVal,
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIX: PopScope evita que el botón atrás cierre la app
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameSection(),
                      const SizedBox(height: 20),
                      _buildPresetsSection(),
                      const SizedBox(height: 20),
                      _buildSizeSection(),
                      const SizedBox(height: 20),
                      _buildDpiSection(),
                      const SizedBox(height: 20),
                      _buildOrientationSection(),
                      const SizedBox(height: 20),
                      _buildBackgroundSection(),
                      const SizedBox(height: 20),
                      _buildPreview(),
                      const SizedBox(height: 24),
                      _buildCreateButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(
          bottom: BorderSide(color: _borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              'NUEVO DISEÑO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─── NOMBRE ───────────────────────────────────────────────
  Widget _buildNameSection() {
    return _buildSection(
      '💀 NOMBRE DEL PROYECTO',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: TextField(
          controller: _nameController,
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Nombre del diseño...',
            hintStyle: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: _textSecondary,
            ),
            suffixIcon: Icon(Icons.edit_outlined,
                color: _textSecondary, size: 16),
          ),
        ),
      ),
    );
  }

  // ─── PRESETS ──────────────────────────────────────────────
  Widget _buildPresetsSection() {
    return _buildSection(
      '⚡ PRESETS POPULARES',
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _presets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // FIX: preset seleccionado se muestra en rojo
            final isSelected = _selectedPreset == index;
            return GestureDetector(
              onTap: () => _applyPreset(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentRed.withOpacity(0.15)
                      : _cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentRed
                        : _borderColor,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  _presets[index]['name'] as String,
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 12,
                    color: isSelected
                        ? AppTheme.accentRed
                        : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── TAMAÑO ───────────────────────────────────────────────
  Widget _buildSizeSection() {
    return _buildSection(
      '📐 TAMAÑO DEL LIENZO',
      child: Column(
        children: [
          Row(
            children: CanvasUnit.values.map((unit) {
              final isActive = _unit == unit;
              final label =
                  unit.name == 'inch' ? 'IN' : unit.name.toUpperCase();
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _unit = unit),
                  child: Container(
                    height: 36,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accentRed
                          : _cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.accentRed
                            : _borderColor,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 12,
                          color: isActive
                              ? Colors.white
                              : _textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDimensionField(
                    'Ancho', _widthController),
              ),
              GestureDetector(
                onTap: _swapDimensions,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _borderColor, width: 0.5),
                  ),
                  child: Icon(Icons.swap_horiz,
                      color: _textSecondary, size: 20),
                ),
              ),
              Expanded(
                child: _buildDimensionField(
                    'Alto', _heightController),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionField(
      String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 9,
              color: _textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(
                _unitLabel,
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── DPI ──────────────────────────────────────────────────
  Widget _buildDpiSection() {
    return _buildSection(
      '🖨️ CALIDAD (DPI)',
      child: Row(
        children: CanvasDpi.values.map((dpi) {
          final isActive = _dpi == dpi;
          String label;
          String sub;
          switch (dpi) {
            case CanvasDpi.dpi72:
              label = '72';
              sub = 'Pantalla';
              break;
            case CanvasDpi.dpi150:
              label = '150';
              sub = 'Estándar';
              break;
            case CanvasDpi.dpi300:
              label = '300';
              sub = 'Impresión';
              break;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _dpi = dpi),
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accentRed.withOpacity(0.15)
                      : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.accentRed
                        : _borderColor,
                    width: isActive ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'BlackOpsOne',
                        fontSize: 18,
                        color: isActive
                            ? AppTheme.accentRed
                            : Colors.white,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 10,
                        color: isActive
                            ? AppTheme.accentRed
                            : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── ORIENTACIÓN ──────────────────────────────────────────
  Widget _buildOrientationSection() {
    return _buildSection(
      '📱 ORIENTACIÓN',
      child: Row(
        children: [
          _buildOrientationOption(
            CanvasOrientation.vertical,
            Icons.stay_current_portrait,
            'Vertical',
          ),
          const SizedBox(width: 12),
          _buildOrientationOption(
            CanvasOrientation.horizontal,
            Icons.stay_current_landscape,
            'Horizontal',
          ),
        ],
      ),
    );
  }

  Widget _buildOrientationOption(
      CanvasOrientation orientation,
      IconData icon,
      String label) {
    final isActive = _orientation == orientation;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_orientation != orientation) _swapDimensions();
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.accentRed.withOpacity(0.15)
                : _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppTheme.accentRed
                  : _borderColor,
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isActive
                      ? AppTheme.accentRed
                      : _textSecondary,
                  size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 14,
                  color: isActive
                      ? AppTheme.accentRed
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FONDO ────────────────────────────────────────────────
  Widget _buildBackgroundSection() {
    return _buildSection(
      '🎨 FONDO',
      child: Row(
        children: [
          // FIX: cada opción usa GestureDetector independiente
          // para permitir re-seleccionar transparente
          _buildBgOption(
            CanvasBackground.transparente,
            'Transparente',
            CustomPaint(painter: _CheckerPainter()),
          ),
          const SizedBox(width: 10),
          _buildBgOption(
            CanvasBackground.blanco,
            'Blanco',
            Container(color: Colors.white),
          ),
          const SizedBox(width: 10),
          _buildBgOption(
            CanvasBackground.negro,
            'Negro',
            Container(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildBgOption(
      CanvasBackground bg, String label, Widget preview) {
    final isActive = _background == bg;
    return Expanded(
      child: GestureDetector(
        // FIX: siempre permite seleccionar cualquier opción
        onTap: () => setState(() => _background = bg),
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? AppTheme.accentRed
                      : _borderColor,
                  width: isActive ? 2 : 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: preview,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 10,
                color: isActive
                    ? AppTheme.accentRed
                    : _textSecondary,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── PREVIEW ──────────────────────────────────────────────
  Widget _buildPreview() {
    final wVal = double.tryParse(_widthController.text) ?? 10;
    final hVal = double.tryParse(_heightController.text) ?? 15;
    final wPx  = _toPixels(wVal);
    final hPx  = _toPixels(hVal);

    final ratio   = wVal / (hVal == 0 ? 1 : hVal);
    final previewW = ratio >= 1 ? 120.0 : 120.0 * ratio;
    final previewH = ratio >= 1 ? 120.0 / ratio : 120.0;

    Color? bgColor;
    bool isTransparent = false;
    switch (_background) {
      case CanvasBackground.blanco:
        bgColor = Colors.white;
        break;
      case CanvasBackground.negro:
        bgColor = Colors.black;
        break;
      case CanvasBackground.transparente:
        isTransparent = true;
        break;
    }

    return _buildSection(
      '👁️ VISTA PREVIA',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: previewW,
                height: previewH,
                decoration: BoxDecoration(
                  color: isTransparent ? null : bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.accentRed, width: 1.5),
                ),
                child: isTransparent
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: CustomPaint(
                            painter: _CheckerPainter()),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${wPx}px × ${hPx}px  •  $_dpiLabel',
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$wVal × $hVal $_unitLabel',
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTÓN CREAR ──────────────────────────────────────────
  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _createDesign,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppTheme.accentRed,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentRed.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('💀', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Text(
              'CREAR DISEÑO',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 16,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPER SECCIÓN ───────────────────────────────────────
  Widget _buildSection(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'BlackOpsOne',
            fontSize: 11,
            color: AppTheme.accentRed,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ─── CHECKER PAINTER ──────────────────────────────────────
class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 8.0;
    final paint1 = Paint()..color = const Color(0xFF3A3A3C);
    final paint2 = Paint()..color = const Color(0xFF2C2C2E);

    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isEven =
            ((x / tileSize).round() + (y / tileSize).round()) %
                    2 ==
                0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
