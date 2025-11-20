import 'package:flutter/material.dart';
import 'features/home/home_page.dart';

class MyApp extends StatelessWidget {
  final String envLabel;
  const MyApp({super.key, this.envLabel = 'DEV'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kechen Software ($envLabel)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
