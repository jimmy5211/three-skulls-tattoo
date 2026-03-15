import 'package:flutter/material.dart';
‎import 'package:go_router/go_router.dart';
‎import 'screens/splash_screen.dart';
‎import 'screens/home_screen.dart';
‎
‎class AppRouter {
‎  static final router = GoRouter(
‎    initialLocation: '/',
‎    routes: [
‎      GoRoute(
‎        path: '/',
‎        builder: (context, state) => const SplashScreen(),
‎      ),
‎      GoRoute(
‎        path: '/home',
‎        builder: (context, state) => const HomeScreen(),
‎      ),
‎    ],
‎    errorBuilder: (context, state) => Scaffold(
‎      backgroundColor: const Color(0xFF000000),
‎      body: Center(
‎        child: Text(
‎          'Página no encontrada',
‎          style: TextStyle(
‎            color: Colors.white,
‎            fontSize: 18,
‎          ),
‎        ),
‎      ),
‎    ),
‎  );
‎}