import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPicker extends StatefulWidget {
  final Color activeColor;
  final Function(Color) onColorSelected;

  const ColorPicker({
    super.key,
    required this.activeColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Color> _recentColors = [];

  final List<Color> _tattooColors = [
    // Negros y grises
    Colors.black,
    const Color(0xFF111111),
    const Color(0xFF222222),
    const Color(0xFF333333),
    const Color(0xFF444444),
    const Color(0xFF555555),
    const Color(0xFF666666),
    const Color(0xFF777777),
    const Color(0xFF888888),
    const Color(0xFF999999),
    const Color(0xFFAAAAAA),
    const Color(0xFFBBBBBB),
    const Color(0xFFCCCCCC),
    const Color(0xFFDDDDDD),
    const Color(0xFFEEEEEE),
    Colors.white,
    // Rojos
    const Color(0xFF8B0000),
    const Color(0xFFC0392B),
    const Color(0xFFE74C3C),
    const Color(0xFFFF6B6B),
    // Azules
    const Color(0xFF1A237E),
    const Color(0xFF1565C0),
    const Color(0xFF1976D2),
    const Color(0xFF42A5F5),
    // Verdes
    const Color(0xFF1B5E20),
    const Color(0xFF2E7D32),
    const Color(0xFF388E3C),
    const Color(0xFF66BB6A),
    // Amarillos/Dorados
    const Color(0xFF7D6608),
    const Color(0xFFB7950B),
    const Color(0xFFD4AC0D),
    const Color(0xFFFFD700),
    // Morados
    const Color(0xFF4A148C),
    const Color(0xFF6A1B9A),
    const Color(0xFF7B1FA2),
    const Color(0xFFAB47BC),
    // Cafés
    const Color(0xFF3E2723),
    const Color(0xFF4E342E),
    const Color(0xFF6D4C41),
    const Color(0xFF8D6E63),
    // Naranjas
    const Color(0xFFBF360C),
    const Color(0xFFE64A19),
    const Color(0xFFFF5722),
    const Color(0xFFFF8A65),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _recentColors = [widget.activeColor];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectColor(Color color) {
    widget.onColorSelected(color);
    setState(() {
      _recentColors.remove(color);
      _recentColors.insert(0, color);
      if (_recentColors.length > 10) {
        _recentColors = _recentColors.take(10).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.deepBlack.withOpacity(0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con color activo
          _buildHeader(),
          // Tabs
          _buildTabs(),
          // Contenido
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildColorGrid(),
                _buildRecentColors(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Color activo grande
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.activeColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info del color
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COLOR ACTIVO',
                  style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    fontSize: 10,
                    color: AppTheme.textGrey,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${widget.activeColor.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 13,
                    color: AppTheme.textWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppTheme.accentRed,
      labelColor: AppTheme.textWhite,
      unselectedLabelColor: AppTheme.textGrey,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
        fontFamily: 'Raleway',
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      tabs: const [
        Tab(text: 'PALETA'),
        Tab(text: 'RECIENTES'),
      ],
    );
  }

  Widget _buildColorGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _tattooColors.length,
      itemBuilder: (context, index) {
        final color = _tattooColors[index];
        final isActive =
            color.value == widget.activeColor.value;
        return GestureDetector(
          onTap: () => _selectColor(color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.1),
                width: isActive ? 2.5 : 0.5,
              ),
            ),
            child: isActive
                ? Icon(
                    Icons.check,
                    size: 12,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildRecentColors() {
    if (_recentColors.isEmpty) {
      return const Center(
        child: Text(
          'Sin colores recientes',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontSize: 12,
            color: AppTheme.textGrey,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _recentColors.length,
      itemBuilder: (context, index) {
        final color = _recentColors[index];
        final isActive =
            color.value == widget.activeColor.value;
        return GestureDetector(
          onTap: () => _selectColor(color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.1),
                width: isActive ? 2.5 : 0.5,
              ),
            ),
            child: isActive
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }
}
