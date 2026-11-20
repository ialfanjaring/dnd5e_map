import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/auth_wrapper.dart';
import 'settings/app_settings.dart';
import 'utils/orientation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En móviles la app va en vertical; la partida y el editor de mapas giran
  // solos a horizontal (ver lib/utils/orientation.dart).
  await AppOrientation.portrait();

  // Inicializar Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar Google Sign-In únicamente en plataformas compatibles.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await AuthService().initializeGoogleSignIn();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Mismo morado que el tema por defecto de Material 3.
  static const Color _seed = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    // Se reconstruye al cambiar el idioma o el tema en Opciones.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'D&D 5e',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seed,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: AppSettings.instance.themeMode,
        home: const AuthWrapper(),
      ),
    );
  }
}