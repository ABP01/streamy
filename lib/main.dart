import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import 'views/homePage.dart';
import 'providers/auth_provider.dart';
import 'providers/live_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await Supabase.initialize(
    url: Env.supabaseUrl!,
    anonKey: Env.supabaseKey!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LiveProvider()),
      ],
      child: MaterialApp(
        title: 'Streamy',
        theme: ThemeData.dark(),
        home: const HomePage(),
      ),
    );
  }
}
