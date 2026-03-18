import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AQUARA',
          themeMode: currentMode, 
          
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF009FE3), 
              secondary: const Color(0xFF8CC63F), 
              brightness: Brightness.light, 
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(), 
          ),

          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF009FE3), 
              secondary: const Color(0xFF8CC63F),
              brightness: Brightness.dark, 
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
          ),
          
          home: const SplashScreen(),
        );
      },
    );
  }
}