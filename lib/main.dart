import 'package:flutter/material.dart';
import 'app.dart';
import 'env/env.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(envLabel: Env.label));
}
