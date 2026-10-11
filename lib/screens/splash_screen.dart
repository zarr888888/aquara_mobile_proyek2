import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aquara_mobile/screens/onboarding_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
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
    try {
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
        final owner = await SessionService.instance.snapshot();
        final token = owner.token;
        if (!mounted) return;
        if (token == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }
        final result = await ApiService().currentUser();
        if (!mounted) return;
        if (owner.revision != SessionService.instance.revision) {
          SessionNavigation.leave(context);
          return;
        }
        if (!result.isSuccess) {
          if (result.statusCode == 401) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          } else {
            setState(() => _error = result.failure!.message);
          }
          return;
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Sesi aman tidak dapat dibuka. Coba kembali setelah perangkat terbuka.',
        );
      }
    }
  }

  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF009FE3),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _checkDestination();
                  },
                  child: const Text('Coba kembali'),
                ),
              ],
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
