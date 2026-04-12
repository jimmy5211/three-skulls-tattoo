import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/canvas_screen.dart';
import 'screens/new_design_screen.dart';
import 'screens/stencil_screen.dart';
import 'screens/brushes_screen.dart';
import 'screens/fonts_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/ai_studio_screen.dart';
import 'screens/settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/new-design',
        builder: (BuildContext context, GoRouterState state) {
          return const NewDesignScreen();
        },
        // FIX: botón atrás del celular navega al home en lugar de cerrar la app
       onExit: (BuildContext context) async {
       context.go('/home');
          return false;
        },
      ),
      GoRoute(
        path: '/canvas',
        builder: (BuildContext context, GoRouterState state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CanvasScreen(designParams: extra);
        },
      ),
      GoRoute(
        path: '/stencil',
        builder: (BuildContext context, GoRouterState state) {
          return const StencilScreen();
        },
      ),
      GoRoute(
        path: '/brushes',
        builder: (BuildContext context, GoRouterState state) {
          return const BrushesScreen();
        },
      ),
      GoRoute(
        path: '/fonts',
        builder: (BuildContext context, GoRouterState state) {
          return const FontsScreen();
        },
      ),
      GoRoute(
        path: '/projects',
        builder: (BuildContext context, GoRouterState state) {
          return const ProjectsScreen();
        },
      ),
      GoRoute(
        path: '/ai-studio',
        builder: (BuildContext context, GoRouterState state) {
          return const AiStudioScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: Text(
            'Página no encontrada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ),
      );
    },
  );
}
