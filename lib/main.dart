import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/screens/main_screen.dart';
import 'package:mosque_tracker/screens/map_screen.dart';
import 'package:mosque_tracker/services/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  //Mapbox Setup
  await setup();

  //Supabase Setup
  await Supabase.initialize(
    anonKey: dotenv.env["SUPABASE_ANON_KEY"]!,
    url: dotenv.env["SUPABASE_URL"]!,
  );

  runApp(const MyApp());
}

Future<void> setup() async {
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_GLOBAL_TOKEN"]!);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      // home: MainScreen(),
      home: AuthGate(),
    );
  }
}
