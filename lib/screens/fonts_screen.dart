import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/font_service.dart';
import '../widgets/font_card.dart';

class FontsScreen extends StatefulWidget {
  const FontsScreen({super.key});

  @override
  State<FontsScreen> createState() => _FontsScreenState();
}

class _FontsScreenState extends State<FontsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  List<FontModel> _defaultFonts = [];
  List<FontModel> _customFonts = [];
  List<String> _favorites = [];
  String? _selectedFontId;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFonts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFonts() async {
    setState(() => _isLoading = true);
    final customFonts = await FontService.loadCustomFonts();
    final favorites = await FontService.loadFavorites();
    setState(() {
      _defaultFonts = FontModel.defaultFonts();
      _customFonts = customFonts;
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
            _buildSearchBar(),
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
                        _buildAllFonts(),
                        _buildCustomFonts(),
                        _buildFavorites(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentRed,
        onPressed: _showImportFontDialog,
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
              'MIS FUENTES',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      color: AppTheme.surfaceColor,
      child: TextField(
        style: const TextStyle(
          color: AppTheme.textWhite,
          fontFamily: 'Raleway',
        ),
        decoration: InputDecoration(
          hintText: '🔍 Buscar fuente...',
          hintStyle: const TextStyle(
            color: AppTheme.textGrey,
            fontFamily: 'Raleway',
          ),
          filled: true,
          fillColor: AppTheme.cardColor,
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppTheme.accentRed,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
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
          Tab(text: 'TODAS'),
          Tab(text: 'IMPORTADAS'),
          Tab(text: '⭐ FAVORITAS'),
        ],
      ),
    );
  }

  Widget _buildAllFonts() {
    final allFonts = [..._defaultFonts, ..._customFonts]
        .where((f) => _searchQuery.isEmpty ||
            f.name.toLowerCase().contains(_searchQuery) ||
            f.category.toLowerCase().contains(_searchQuery))
        .toList();

    if (allFonts.isEmpty) {
      return _buildEmptyState('No se encontraron fuentes');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allFonts.length,
      itemBuilder: (context, index) {
        final font = allFonts[index];
        return FontCard(
          font: font,
          isFavorite: _favorites.contains(font.id),
          isSelected: font.id == _selectedFontId,
          onTap: () => setState(() => _selectedFontId = font.id),
          onFavoriteToggle: () => _toggleFavorite(font.id),
          onDelete: () => _deleteFont(font.id),
        );
      },
    );
  }

  Widget _buildCustomFonts() {
    final customFonts = _customFonts
        .where((f) => _searchQuery.isEmpty ||
            f.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (customFonts.isEmpty) {
      return _buildEmptyState(
        'No hay fuentes importadas\nToca + para importar',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: customFonts.length,
      itemBuilder: (context, index) {
        final font = customFonts[index];
        return FontCard(
          font: font,
          isFavorite: _favorites.contains(font.id),
          isSelected: font.id == _selectedFontId,
          onTap: () => setState(() => _selectedFontId = font.id),
          onFavoriteToggle: () => _toggleFavorite(font.id),
          onDelete: () => _deleteFont(font.id),
        );
      },
    );
  }

  Widget _buildFavorites() {
    final favoriteFonts = [..._defaultFonts, ..._customFonts]
        .where((f) => _favorites.contains(f.id))
        .where((f) => _searchQuery.isEmpty ||
            f.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (favoriteFonts.isEmpty) {
      return _buildEmptyState(
        'No hay favoritas\nToca ⭐ para agregar',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favoriteFonts.length,
      itemBuilder: (context, index) {
        final font = favoriteFonts[index];
        return FontCard(
          font: font,
          isFavorite: true,
          isSelected: font.id == _selectedFontId,
          onTap: () => setState(() => _selectedFontId = font.id),
          onFavoriteToggle: () => _toggleFavorite(font.id),
          onDelete: () => _deleteFont(font.id),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔤', style: TextStyle(fontSize: 48)),
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

  Future<void> _toggleFavorite(String fontId) async {
    await FontService.toggleFavorite(fontId);
    await _loadFonts();
  }

  Future<void> _deleteFont(String fontId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '🔤 Eliminar Fuente',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: const Text(
          '¿Eliminar esta fuente?',
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
              await FontService.deleteFont(fontId);
              await _loadFonts();
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

  void _showImportFontDialog() {
    final nameController = TextEditingController();
    final familyController = TextEditingController();
    String selectedCategory = 'Gothic';

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
                  '🔤 AGREGAR FUENTE',
                  style: TextStyle(
                    fontFamily: 'BlackOpsOne',
                    fontSize: 16,
                    color: AppTheme.textWhite,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nombre de la fuente',
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
                TextField(
                  controller: familyController,
                  style: const TextStyle(
                    color: AppTheme.textWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Familia (ej: OldEnglish)',
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
                const Text(
                  'CATEGORÍA:',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Gothic',
                    'Script',
                    'Traditional',
                    'Modern',
                    'Blackletter',
                  ].map((cat) {
                    final isSelected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => setModalState(
                        () => selectedCategory = cat,
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
                          cat,
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
                const SizedBox(height: 16),
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
                          final newFont = FontModel(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameController.text,
                            family: familyController.text.isEmpty
                                ? nameController.text
                                : familyController.text,
                            category: selectedCategory,
                          );
                          await FontService.saveFont(newFont);
                          Navigator.pop(context);
                          await _loadFonts();
                        },
                        child: const Text(
                          'Agregar',
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
}
