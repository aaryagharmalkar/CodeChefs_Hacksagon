import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

class NeuraCareApp extends StatelessWidget {
  const NeuraCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "NeuraCare",
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}