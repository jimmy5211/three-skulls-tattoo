import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';
import '../services/brush_service.dart';
import '../widgets/brush_card.dart';

class BrushesScreen extends StatefulWidget {
  const BrushesScreen({super.key});

  @override
  State<BrushesScreen> createState() => _BrushesScreenState();
}

class _BrushesScreenState extends State<BrushesScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  List<BrushModel> _defaultBrushes = [];
  List<BrushModel> _customBrushes = [];
  List<String> _favorites = [];
  String? _activeBrushId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBrushes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBrushes() async {
    setState(() => _isLoading = true);
    final customBrushes = await BrushService.loadCustomBrushes();
    final favorites = await BrushService.loadFavorites();
    setState(() {
      _defaultBrushes = BrushModel.defaultBrushes();
      _customBrushes = customBrushes;
      _favorites = favorites;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentRed,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllBrushes(),
                        _buildCustomBrushes(),
                        _buildFavorites(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentRed,
        onPressed: _showCreateBrushDialog,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
            onPressed: () => context.go('/home'),
          ),
          const Expanded(
            child: Text(
              'MIS PINCELES',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.search,
              color: AppTheme.textGrey,
              size: 20,
            ),
            onPressed: _showSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.deepBlack,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.accentRed,
        labelColor: AppTheme.textWhite,
        unselectedLabelColor: AppTheme.textGrey,
        labelStyle: const TextStyle(
          fontFamily: 'Raleway',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        tabs: const [
          Tab(text: 'TODOS'),
          Tab(text: 'CREADOS'),
          Tab(text: '⭐ FAVORITOS'),
        ],
      ),
    );
  }

  Widget _buildAllBrushes() {
    final allBrushes = [..._defaultBrushes, ..._customBrushes];
    if (allBrushes.isEmpty) {
      return _buildEmptyState('No hay pinceles');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allBrushes.length,
      itemBuilder: (context, index) {
        final brush = allBrushes[index];
        final isCustom = index >= _defaultBrushes.length;
        return BrushCard(
          brush: brush,
          isActive: brush.id == _activeBrushId,
          isFavorite: _favorites.contains(brush.id),
          isCustom: isCustom,
          onTap: () => setState(() => _activeBrushId = brush.id),
          onFavoriteToggle: () => _toggleFavorite(brush.id),
          onDelete: () => _deleteBrush(brush.id),
        );
      },
    );
  }

  Widget _buildCustomBrushes() {
    if (_customBrushes.isEmpty) {
      return _buildEmptyState(
        'No hay pinceles creados\nToca + para crear uno',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _customBrushes.length,
      itemBuilder: (context, index) {
        final brush = _customBrushes[index];
        return BrushCard(
          brush: brush,
          isActive: brush.id == _activeBrushId,
          isFavorite: _favorites.contains(brush.id),
          isCustom: true,
          onTap: () => setState(() => _activeBrushId = brush.id),
          onFavoriteToggle: () => _toggleFavorite(brush.id),
          onDelete: () => _deleteBrush(brush.id),
        );
      },
    );
  }

  Widget _buildFavorites() {
    final favoriteBrushes = [
      ..._defaultBrushes,
      ..._customBrushes,
    ].where((b) => _favorites.contains(b.id)).toList();

    if (favoriteBrushes.isEmpty) {
      return _buildEmptyState(
        'No hay favoritos\nToca ⭐ para agregar',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favoriteBrushes.length,
      itemBuilder: (context, index) {
        final brush = favoriteBrushes[index];
        return BrushCard(
          brush: brush,
          isActive: brush.id == _activeBrushId,
          isFavorite: true,
          onTap: () => setState(() => _activeBrushId = brush.id),
          onFavoriteToggle: () => _toggleFavorite(brush.id),
          onDelete: () => _deleteBrush(brush.id),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🖌️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String brushId) async {
    await BrushService.toggleFavorite(brushId);
    await _loadBrushes();
  }

  Future<void> _deleteBrush(String brushId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '💀 Eliminar Pincel',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: const Text(
          '¿Eliminar este pincel?',
          style: TextStyle(
            color: AppTheme.textGrey,
            fontFamily: 'Raleway',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BrushService.deleteBrush(brushId);
              await _loadBrushes();
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateBrushDialog() {
    final nameController = TextEditingController();
    StrokeType selectedType = StrokeType.liner;
    double size = 5.0;
    double opacity = 1.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✏️ CREAR PINCEL',
                  style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    fontSize: 16,
                    color: AppTheme.textWhite,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                // Nombre
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'Nombre del pincel',
                    hintStyle: const TextStyle(
                      color: AppTheme.textGrey,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tipo
                const Text(
                  'TIPO:',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: StrokeType.values.map((type) {
                    final isSelected = type == selectedType;
                    return GestureDetector(
                      onTap: () => setModalState(
                        () => selectedType = type,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentRed
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentRed
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          type.name,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textGrey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Tamaño
                Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text(
                        'Tamaño',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: size,
                        min: 1,
                        max: 50,
                        activeColor: AppTheme.accentRed,
                        onChanged: (v) =>
                            setModalState(() => size = v),
                      ),
                    ),
                    Text(
                      '${size.round()}',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Opacidad
                Row(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Text(
                        'Opacidad',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: AppTheme.textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: opacity,
                        min: 0.1,
                        max: 1.0,
                        activeColor: AppTheme.accentRed,
                        onChanged: (v) =>
                            setModalState(() => opacity = v),
                      ),
                    ),
                    Text(
                      '${(opacity * 100).round()}%',
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                        ),
                        onPressed: () async {
                          if (nameController.text.isEmpty) return;
                          final newBrush = BrushModel(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameController.text,
                            emoji: '🖌️',
                            type: selectedType,
                            size: size,
                            opacity: opacity,
                          );
                          await BrushService.saveBrush(newBrush);
                          Navigator.pop(context);
                          await _loadBrushes();
                        },
                        child: const Text(
                          'Crear',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '🔍 Buscar Pincel',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: TextField(
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'Nombre del pincel...',
            hintStyle: const TextStyle(color: AppTheme.textGrey),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppTheme.borderColor,
              ),
            ),
          ),
          onChanged: (value) {
            // Implementar búsqueda
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
