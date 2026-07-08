import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mosque_tracker/config_screens/force_update_screen.dart';
import 'package:mosque_tracker/config_screens/maintenance_screen.dart';
import 'package:mosque_tracker/screens/splash_screen.dart';
import 'package:mosque_tracker/services/auth_gate.dart';
import 'package:mosque_tracker/services/foreground_service_manager.dart';
import 'package:mosque_tracker/services/mosque.service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setup();

  await Supabase.initialize(
    anonKey: dotenv.env["SUPABASE_ANON_KEY"]!,
    url: dotenv.env["SUPABASE_URL"]!,
  );

  MosqueService().loadVisitedMosques();

  // Check version before launching app
  final versionStatus = await _checkAppVersion();

  runApp(ProviderScope(child: MyApp(versionStatus: versionStatus)));
}

Future<void> setup() async {
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_GLOBAL_TOKEN"]!);
}

Future<Map<String, dynamic>> _checkAppVersion() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    debugPrint(currentVersion);

    final config = await Supabase.instance.client
        .from('app_config')
        .select()
        .eq('id', 1)
        .single();

    final minVersion = config['min_version'] as String? ?? '1.0.0';
    final forceUpdate = config['force_update'] as bool? ?? false;
    final maintenanceMode = config['maintenance_mode'] as bool? ?? false;
    final maintenanceMessage = config['maintenance_message'] as String? ?? '';

    if (maintenanceMode) {
      return {'status': 'maintenance', 'message': maintenanceMessage};
    }

    if (forceUpdate && _isVersionBelow(currentVersion, minVersion)) {
      return {'status': 'force_update'};
    }

    return {'status': 'ok'};
  } catch (e) {
    debugPrint("Version check error: $e");
    return {'status': 'ok'};
  }
}

bool _isVersionBelow(String current, String minimum) {
  final c = current.split('.').map(int.parse).toList();
  final m = minimum.split('.').map(int.parse).toList();

  for (int i = 0; i < 3; i++) {
    final cv = i < c.length ? c[i] : 0;
    final mv = i < m.length ? m[i] : 0;
    if (cv < mv) return true;
    if (cv > mv) return false;
  }
  return false;
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic> versionStatus;
  const MyApp({super.key, required this.versionStatus});

  @override
  Widget build(BuildContext context) {
    Widget home;

    switch (versionStatus['status']) {
      case 'maintenance':
        home = MaintenanceScreen(message: versionStatus['message'] ?? '');
        break;
      case 'force_update':
        home = const ForceUpdateScreen();
        break;
      default:
        home = const SplashScreen();
    }

    return MaterialApp(
      title: 'Masjid Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0F1A14),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: home,
    );
  }
}
