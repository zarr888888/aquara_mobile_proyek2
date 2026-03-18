import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aquara_mobile/screens/onboarding_screen.dart';
import 'home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      _checkDestination();
    }
  }

  Future<void> _checkDestination() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    bool showOnboarding = prefs.getBool('showOnboarding') ?? true;

    if (showOnboarding) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF009FE3), 
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
              padding: const EdgeInsets.only(top: 20, bottom: 20), 
              child: Image.asset(
                "assets/logo2.png", 
                height: 120, 
                fit: BoxFit.contain, 
              ),
            ),
              const SizedBox(height: 30),
              Text(
                "AQUARA",
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontSize: 40, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 4, 
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Solusi Digital Budidaya Ikan Air Tawar",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9), 
                  fontSize: 14, 
                  fontWeight: FontWeight.w500, // Medium
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}