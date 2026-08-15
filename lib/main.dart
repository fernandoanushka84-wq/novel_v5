import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/screens/root_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InkittCloneApp());
}

class InkittCloneApp extends StatelessWidget {
  const InkittCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Novel Mobile App',
      theme: AppTheme.lightTheme,
      home: const RootShell(),
    );
  }
}
