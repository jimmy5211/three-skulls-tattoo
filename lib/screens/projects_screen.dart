import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/project_service.dart';
import '../widgets/project_card.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectModel> _projects = [];
  List<FolderModel> _folders = [];
  bool _isLoading = true;
  bool _isGridView = true;
  double _gridSize = 150;
  String _sortBy = 'date';
  String _searchQuery = '';
  String _selectedFolderId = 'all';
  List<String> _selectedProjects = [];
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _addSampleProjects();
  }

  Future<void> _addSampleProjects() async {
    final projects = await ProjectService.loadProjects();
    if (projects.isEmpty) {
      final samples = [
        ProjectModel(
          id: 'sample_1',
          name: 'Calavera Tribal',
          style: 'Blackwork',
          sizeBytes: 2400000,
          updatedAt: DateTime.now().subtract(
            const Duration(hours: 2),
          ),
        ),
        ProjectModel(
          id: 'sample_2',
          name: 'Rosa Realista',
          style: 'Realismo',
          sizeBytes: 4100000,
          updatedAt: DateTime.now().subtract(
            const Duration(days: 1),
          ),
        ),
        ProjectModel(
          id: 'sample_3',
          name: 'Lobo Geométrico',
          style: 'Geométrico',
          sizeBytes: 1800000,
          updatedAt: DateTime.now().subtract(
            const Duration(days: 3),
          ),
        ),
        ProjectModel(
          id: 'sample_4',
          name: 'Dragón Japonés',
          style: 'Japonés',
          sizeBytes: 5200000,
          updatedAt: DateTime.now().subtract(
            const Duration(days: 7),
          ),
        ),
      ];
      for (final project in samples) {
        await ProjectService.saveProject(project);
      }
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final projects = await ProjectService.loadProjects();
    final folders = await ProjectService.loadFolders();
    setState(() {
      _projects = projects;
      _folders = folders;
      _isLoading = false;
    });
  }

  List<ProjectModel> get _filteredProjects {
    var filtered = _projects.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery) ||
          p.style.toLowerCase().contains(_searchQuery);
      final matchesFolder = _selectedFolderId == 'all' ||
          p.folderId == _selectedFolderId;
      return matchesSearch && matchesFolder;
    }).toList();

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'size':
        filtered.sort(
          (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
        );
        break;
      default:
        filtered.sort(
          (a, b) => b.updatedAt.compareTo(a.updatedAt),
        );
    }
    return filtered;
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
            _buildFolderSelector(),
            _buildViewOptions(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentRed,
                      ),
                    )
                  : _filteredProjects.isEmpty
                      ? _buildEmptyState()
                      : _isGridView
                          ? _buildGridView()
                          : _buildListView(),
            ),
            if (_isSelectionMode) _buildSelectionBar(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentRed,
        onPressed: () => context.go('/canvas'),
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
              'MIS PROYECTOS',
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
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: AppTheme.textGrey,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(
              Icons.create_new_folder_outlined,
              color: AppTheme.textGrey,
              size: 20,
            ),
            onPressed: _showCreateFolderDialog,
          ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontFamily: 'Raleway',
              ),
              decoration: InputDecoration(
                hintText: '🔍 Buscar proyecto...',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (value) => setState(
                () => _searchQuery = value.toLowerCase(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Ordenar
          GestureDetector(
            onTap: _showSortDialog,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.borderColor,
                ),
              ),
              child: const Icon(
                Icons.sort,
                color: AppTheme.textGrey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      height: 40,
      color: AppTheme.deepBlack,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        children: [
          _buildFolderChip('all', 'Todos'),
          ..._folders.map(
            (f) => _buildFolderChip(f.id, f.name),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderChip(String id, String name) {
    final isSelected = _selectedFolderId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFolderId = id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentRed
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentRed
                : AppTheme.borderColor,
          ),
        ),
        child: Text(
          name,
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
  }

  Widget _buildViewOptions() {
    if (!_isGridView) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          const Text(
            'Tamaño:',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 11,
              color: AppTheme.textGrey,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                activeTrackColor: AppTheme.accentRed,
                thumbColor: AppTheme.accentRed,
                inactiveTrackColor: AppTheme.borderColor,
              ),
              child: Slider(
                value: _gridSize,
                min: 100,
                max: 200,
                onChanged: (v) =>
                    setState(() => _gridSize = v),
              ),
            ),
          ),
          Text(
            '${_filteredProjects.length} proyectos',
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 11,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            (MediaQuery.of(context).size.width / _gridSize)
                .floor()
                .clamp(2, 4),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredProjects.length,
      itemBuilder: (context, index) {
        final project = _filteredProjects[index];
        return ProjectCard(
          project: project,
          isGridView: true,
          isSelected: _selectedProjects.contains(project.id),
          onTap: () => _isSelectionMode
              ? _toggleSelection(project.id)
              : _openProject(project),
          onLongPress: () => _enableSelection(project.id),
          onDelete: () => _deleteProject(project.id),
          onExport: () => _exportProject(project),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredProjects.length,
      itemBuilder: (context, index) {
        final project = _filteredProjects[index];
        return ProjectCard(
          project: project,
          isGridView: false,
          isSelected: _selectedProjects.contains(project.id),
          onTap: () => _isSelectionMode
              ? _toggleSelection(project.id)
              : _openProject(project),
          onLongPress: () => _enableSelection(project.id),
          onDelete: () => _deleteProject(project.id),
          onExport: () => _exportProject(project),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📁', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text(
            'No hay proyectos',
            style: TextStyle(
              fontFamily: 'BlackOpsOne',
              fontSize: 20,
              color: AppTheme.textWhite,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca + para crear un nuevo diseño',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/canvas'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✏️ NUEVO DISEÑO',
                style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedProjects.length} seleccionados',
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 13,
              color: AppTheme.textWhite,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _exportSelected,
            icon: const Icon(
              Icons.share_outlined,
              color: AppTheme.accentRed,
              size: 18,
            ),
            label: const Text(
              'Exportar',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
          TextButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.textGrey,
              size: 18,
            ),
            label: const Text(
              'Eliminar',
              style: TextStyle(color: AppTheme.textGrey),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: AppTheme.textGrey,
              size: 20,
            ),
            onPressed: () => setState(() {
              _isSelectionMode = false;
              _selectedProjects.clear();
            }),
          ),
        ],
      ),
    );
  }

  void _openProject(ProjectModel project) {
    context.go('/canvas');
  }

  void _enableSelection(String projectId) {
    setState(() {
      _isSelectionMode = true;
      _selectedProjects.add(projectId);
    });
  }

  void _toggleSelection(String projectId) {
    setState(() {
      if (_selectedProjects.contains(projectId)) {
        _selectedProjects.remove(projectId);
        if (_selectedProjects.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedProjects.add(projectId);
      }
    });
  }

  Future<void> _deleteProject(String projectId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '💀 Eliminar Proyecto',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: const Text(
          '¿Eliminar este proyecto?',
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
              await ProjectService.deleteProject(projectId);
              await _loadData();
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

  void _exportProject(ProjectModel project) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            const Text('💾', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              '${project.name} exportado',
              style: const TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportSelected() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            const Text('💾', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              '${_selectedProjects.length} proyectos exportados',
              style: const TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      _isSelectionMode = false;
      _selectedProjects.clear();
    });
  }

  Future<void> _deleteSelected() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '💀 Eliminar Proyectos',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: Text(
          '¿Eliminar ${_selectedProjects.length} proyectos?',
          style: const TextStyle(
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
              for (final id in _selectedProjects) {
                await ProjectService.deleteProject(id);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedProjects.clear();
              });
              await _loadData();
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

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'Ordenar por',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('date', '📅 Fecha'),
            _buildSortOption('name', '🔤 Nombre'),
            _buildSortOption('size', '📦 Tamaño'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label) {
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: _sortBy == value
              ? AppTheme.accentRed.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 14,
                color: _sortBy == value
                    ? AppTheme.accentRed
                    : AppTheme.textWhite,
              ),
            ),
            const Spacer(),
            if (_sortBy == value)
              const Icon(
                Icons.check,
                color: AppTheme.accentRed,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          '📁 Nueva Carpeta',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'Nombre de la carpeta',
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
              if (nameController.text.isEmpty) return;
              final folder = FolderModel(
                id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
                name: nameController.text,
              );
              await ProjectService.saveFolder(folder);
              Navigator.pop(context);
              await _loadData();
            },
            child: const Text(
              'Crear',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
