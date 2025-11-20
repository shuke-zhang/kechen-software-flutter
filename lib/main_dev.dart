import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const envLabel = 'DEV';
  runApp(const MyApp(envLabel: envLabel));
}
