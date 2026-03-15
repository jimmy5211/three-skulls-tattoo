import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animController;
  late List<Animation<double>> _itemAnimations;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Icons.add_circle_outline,
      'emoji': '✏️',
      'title': 'NUEVO DISEÑO',
      'subtitle': 'Crear desde cero',
      'color': AppTheme.accentRed,
      'route': '/canvas',
    },
    {
      'icon': Icons.camera_alt_outlined,
      'emoji': '📸',
      'title': 'CREAR ESTENCIL',
      'subtitle': 'Convertir foto con IA',
      'color': AppTheme.accentRedBright,
      'route': '/stencil',
    },
    {
      'icon': Icons.brush_outlined,
      'emoji': '🖌️',
      'title': 'MIS PINCELES',
      'subtitle': 'Gestionar pinceles',
      'color': AppTheme.accentRed,
      'route': '/brushes',
    },
    {
      'icon': Icons.text_fields_outlined,
      'emoji': '🔤',
      'title': 'MIS FUENTES',
      'subtitle': 'Gestionar tipografías',
      'color': AppTheme.accentRedDark,
      'route': '/fonts',
    },
    {
      'icon': Icons.folder_outlined,
      'emoji': '📁',
      'title': 'MIS PROYECTOS',
      'subtitle': 'Ver todos los diseños',
      'color': AppTheme.accentRed,
      'route': '/projects',
    },
    {
      'icon': Icons.auto_awesome_outlined,
      'emoji': '🤖',
      'title': 'IA STUDIO',
      'subtitle': 'Inteligencia artificial',
      'color': AppTheme.accentRedBright,
      'route': '/ai-studio',
    },
    {
      'icon': Icons.build_outlined,
      'emoji': '🔧',
      'title': 'HERRAMIENTAS',
      'subtitle': 'Todas las herramientas',
      'color': AppTheme.accentRed,
      'route': '/tools',
    },
    {
      'icon': Icons.settings_outlined,
      'emoji': '⚙️',
      'title': 'CONFIGURACIÓN',
      'subtitle': 'Ajustes de la app',
      'color': AppTheme.textGrey,
      'route': '/settings',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _itemAnimations = List.generate(
      _menuItems.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            index * 0.1,
            0.6 + index * 0.1,
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSyncIndicator(),
            Expanded(
              child: _buildMenuList(),
            ),
            _buildRecentProjects(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THREE SKULLS',
                style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 22,
                  color: AppTheme.textWhite,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'TATTOO',
                style: TextStyle(
                  fontFamily: 'BlackOpsOne',
                  fontSize: 14,
                  color: AppTheme.accentRed,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Calaveras pequeñas
              Text(
                '💀💀💀',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            'Sincronizado con Google Drive',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 12,
              color: AppTheme.textGrey,
            ),
          ),
          const Spacer(),
          Text(
            'Hace 5 min',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 11,
              color: AppTheme.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _itemAnimations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                50 * (1 - _itemAnimations[index].value),
                0,
              ),
              child: Opacity(
                opacity: _itemAnimations[index].value,
                child: MenuItem(
                  emoji: _menuItems[index]['emoji'],
                  title: _menuItems[index]['title'],
                  subtitle: _menuItems[index]['subtitle'],
                  accentColor: _menuItems[index]['color'],
                  onTap: () {
                    // Navegación próximamente
                    _showComingSoon(context, _menuItems[index]['title']);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentProjects() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÚLTIMOS PROYECTOS',
            style: TextStyle(
              fontFamily: 'Raleway',
              fontSize: 11,
              color: AppTheme.textGrey,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRecentItem('Calavera'),
              const SizedBox(width: 12),
              _buildRecentItem('Tribal'),
              const SizedBox(width: 12),
              _buildRecentItem('Rosa'),
              const SizedBox(width: 12),
              _buildRecentItem('Lobo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(String name) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🖼️',
              style: TextStyle(fontSize: 20),
            ),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Raleway',
                fontSize: 10,
                color: AppTheme.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accentRed),
        ),
        content: Row(
          children: [
            Text('💀', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              '$feature - Próximamente',
              style: TextStyle(
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
}
