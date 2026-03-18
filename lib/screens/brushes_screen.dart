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

class _BrushesScreenState extends State<BrushesScreen> {
  List<BrushModel> _brushes = [];
  BrushModel? _activeBrush;
  BrushCategory _selectedCategory = BrushCategory.todos;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBrushes();
  }

  Future<void> _loadBrushes() async {
    final brushes = await BrushService.loadBrushes();
    setState(() {
      _brushes = brushes;
      _activeBrush = brushes.isNotEmpty ? brushes.first : null;
      _isLoading = false;
    });
  }

  List<BrushModel> get _filteredBrushes {
    if (_selectedCategory == BrushCategory.todos) return _brushes;
    return _brushes.where((b) => b.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildCategoryTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentRed,
                      ),
                    )
                  : _filteredBrushes.isEmpty
                      ? _buildEmptyState()
                      : Row(
                          children: [
                            _buildCategorySidebar(),
                            Expanded(child: _buildBrushList()),
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentRed,
        onPressed: _showCreateBrushDialog,
        child: const Icon(Icons.add, color: Colors.white),
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
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppTheme.textWhite, size: 20),
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
            icon: const Icon(Icons.sort,
                color: AppTheme.textWhite, size: 20),
            onPressed: _showSortOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 40,
      color: AppTheme.deepBlack,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: BrushCategory.values.map((cat) {
          final isActive = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentRed
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppTheme.accentRed
                      : AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    BrushModel.categoryEmoji(cat),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    BrushModel.categoryName(cat),
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: isActive
                          ? Colors.white
                          : AppTheme.textGrey,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySidebar() {
    return Container(
      width: 70,
      color: AppTheme.deepBlack,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: BrushCategory.values.map((cat) {
          final isActive = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentRed.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isActive
                    ? Border.all(
                        color: AppTheme.accentRed, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    BrushModel.categoryEmoji(cat),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    BrushModel.categoryName(cat),
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 8,
                      color: isActive
                          ? AppTheme.accentRed
                          : AppTheme.textGrey,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrushList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredBrushes.length,
      itemBuilder: (context, index) {
        final brush = _filteredBrushes[index];
        final isActive = _activeBrush?.id == brush.id;
        return BrushCard(
          brush: brush,
          isActive: isActive,
          onTap: () => setState(() => _activeBrush = brush),
          onLongPress: () => _showBrushOptions(brush),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🖌️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No hay pinceles en\n${BrushModel.categoryName(_selectedCategory)}',
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 16,
              color: AppTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showCreateBrushDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Crear Pincel',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showBrushOptions(BrushModel brush) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            brush.name,
            style: const TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 14,
              color: AppTheme.textWhite,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionItem(
            Icons.edit_outlined,
            'Modificar pincel',
            'Editar nombre, tamaño y opacidad',
            () {
              Navigator.pop(context);
              _showEditBrushDialog(brush);
            },
          ),
          _buildOptionItem(
            Icons.copy_outlined,
            'Duplicar pincel',
            'Crear una copia de este pincel',
            () {
              Navigator.pop(context);
              _duplicateBrush(brush);
            },
          ),
          _buildOptionItem(
            Icons.push_pin_outlined,
            'Fijar en favoritos',
            'Acceso rápido desde el canvas',
            () {
              Navigator.pop(context);
            },
          ),
          _buildOptionItem(
            Icons.delete_outline,
            'Eliminar pincel',
            'Eliminar permanentemente',
            () {
              Navigator.pop(context);
              _deleteBrush(brush);
            },
            isDestructive: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: AppTheme.borderColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDestructive
                    ? Colors.red
                    : AppTheme.textGrey,
                size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 14,
                      color: isDestructive
                          ? Colors.red
                          : AppTheme.textWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppTheme.textGrey, size: 18),
          ],
        ),
      ),
    );
  }

  void _showCreateBrushDialog() {
    final nameController = TextEditingController();
    StrokeType selectedType = StrokeType.liner;
    BrushCategory selectedCategory = BrushCategory.todos;
    double size = 5.0;
    double opacity = 1.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            '➕ Nuevo Pincel',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              color: AppTheme.textWhite,
              fontSize: 16,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(
                      color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'Nombre del pincel',
                    labelStyle: const TextStyle(
                        color: AppTheme.textGrey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: AppTheme.accentRed),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Categoría',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        color: AppTheme.textGrey,
                        fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButton<BrushCategory>(
                  value: selectedCategory,
                  dropdownColor: AppTheme.cardColor,
                  isExpanded: true,
                  style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontFamily: 'Raleway'),
                  items: BrushCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(
                          '${BrushModel.categoryEmoji(cat)} ${BrushModel.categoryName(cat)}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(
                          () => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Tipo',
                    style: TextStyle(
                        fontFamily: 'Raleway',
                        color: AppTheme.textGrey,
                        fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButton<StrokeType>(
                  value: selectedType,
                  dropdownColor: AppTheme.cardColor,
                  isExpanded: true,
                  style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontFamily: 'Raleway'),
                  items: StrokeType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(
                          () => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Tamaño: ${size.round()}',
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        color: AppTheme.textGrey,
                        fontSize: 12)),
                Slider(
                  value: size,
                  min: 1,
                  max: 100,
                  activeColor: AppTheme.accentRed,
                  onChanged: (v) =>
                      setDialogState(() => size = v),
                ),
                Text(
                    'Opacidad: ${(opacity * 100).round()}%',
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        color: AppTheme.textGrey,
                        fontSize: 12)),
                Slider(
                  value: opacity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: AppTheme.accentRed,
                  onChanged: (v) =>
                      setDialogState(() => opacity = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style:
                      TextStyle(color: AppTheme.textGrey)),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                final newBrush = BrushModel(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  name: nameController.text,
                  emoji: '🖌️',
                  type: selectedType,
                  category: selectedCategory,
                  size: size,
                  opacity: opacity,
                );
                await BrushService.saveBrush(newBrush);
                Navigator.pop(context);
                _loadBrushes();
              },
              child: const Text('Crear',
                  style: TextStyle(
                      color: AppTheme.accentRed)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBrushDialog(BrushModel brush) {
    final nameController =
        TextEditingController(text: brush.name);
    double size = brush.size;
    double opacity = brush.opacity;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            '✏️ Editar Pincel',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              color: AppTheme.textWhite,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(
                    color: AppTheme.textWhite),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(
                      color: AppTheme.textGrey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                        color: AppTheme.accentRed),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Tamaño: ${size.round()}',
                  style: const TextStyle(
                      fontFamily: 'Raleway',
                      color: AppTheme.textGrey)),
              Slider(
                value: size,
                min: 1,
                max: 100,
                activeColor: AppTheme.accentRed,
                onChanged: (v) =>
                    setDialogState(() => size = v),
              ),
              Text(
                  'Opacidad: ${(opacity * 100).round()}%',
                  style: const TextStyle(
                      fontFamily: 'Raleway',
                      color: AppTheme.textGrey)),
              Slider(
                value: opacity,
                min: 0.1,
                max: 1.0,
                activeColor: AppTheme.accentRed,
                onChanged: (v) =>
                    setDialogState(() => opacity = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style:
                      TextStyle(color: AppTheme.textGrey)),
            ),
            TextButton(
              onPressed: () async {
                final updated = brush.copyWith(
                  name: nameController.text,
                  size: size,
                  opacity: opacity,
                );
                await BrushService.updateBrush(updated);
                Navigator.pop(context);
                _loadBrushes();
              },
              child: const Text('Guardar',
                  style: TextStyle(
                      color: AppTheme.accentRed)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateBrush(BrushModel brush) async {
    final duplicate = brush.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${brush.name} copia',
    );
    await BrushService.saveBrush(duplicate);
    _loadBrushes();
  }

  Future<void> _deleteBrush(BrushModel brush) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Eliminar pincel',
            style: TextStyle(
                fontFamily: 'BlackOpsOne',
                color: AppTheme.textWhite)),
        content: Text(
          '¿Eliminar "${brush.name}"?',
          style: const TextStyle(
              fontFamily: 'Raleway',
              color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await BrushService.deleteBrush(brush.id);
      _loadBrushes();
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('ORDENAR PINCELES',
              style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 13,
                  color: AppTheme.textWhite,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildOptionItem(
              Icons.sort_by_alpha, 'Por nombre', 'A-Z', () {
            setState(() => _brushes.sort(
                (a, b) => a.name.compareTo(b.name)));
            Navigator.pop(context);
          }),
          _buildOptionItem(
              Icons.straighten, 'Por tamaño', 'Mayor a menor',
              () {
            setState(() => _brushes
                .sort((a, b) => b.size.compareTo(a.size)));
            Navigator.pop(context);
          }),
          _buildOptionItem(Icons.category_outlined,
              'Por categoría', 'Agrupados por tipo', () {
            setState(() => _brushes.sort((a, b) =>
                a.category.name.compareTo(b.category.name)));
            Navigator.pop(context);
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
