import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _onLastPage = false;

  Future<void> _finishOnboarding(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
    
    if (!context.mounted) return;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009FE3),
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _onLastPage = (index == 3); 
              });
            },
            children: [
              _buildPageContent(
                image: "assets/analisa usaha.png", 
                title: "Analisa Usaha",
                desc: "Hitung FCR, estimasi pakan, dan potensi keuntungan panen Anda dengan cerdas dan akurat.",
              ),
              _buildPageContent(
                image: "assets/konsultasi.png", 
                title: "Konsultasi AI",
                desc: "Dapatkan solusi instan untuk masalah budidaya ikan Anda langsung dari asisten pintar AI AQUARA.",
              ),
              _buildPageContent(
                image: "assets/forum.png", 
                title: "Forum Diskusi",
                desc: "Berbagi pengalaman, bertanya, dan terhubung dengan komunitas pembudidaya ikan se-Indramayu dan indonesia.",
              ),
              _buildPageContent(
                image: "assets/harga pasar.png", 
                title: "Pasar Ikan Digital",
                desc: "Perluas jangkauan pasar Anda. Jual hasil panen atau temukan bibit unggul langsung dari aplikasi.",
              ),
            ],
          ),

          Container(
            alignment: const Alignment(0, 0.85),
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _onLastPage
                    ? const SizedBox(width: 60)
                    : TextButton(
                        onPressed: () {
                          _controller.jumpToPage(3);
                        },
                        child: Text(
                          "Lewati",
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                        ),
                      ),

                SmoothPageIndicator(
                  controller: _controller,
                  count: 4, 
                  effect: const WormEffect(
                    activeDotColor: Colors.white,
                    dotColor: Colors.white30,
                    dotHeight: 10,
                    dotWidth: 10,
                  ),
                ),

                _onLastPage
                    ? ElevatedButton(
                        onPressed: () => _finishOnboarding(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF009FE3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(
                          "Mulai",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeIn,
                          );
                        },
                        child: Text(
                          "Lanjut",
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent({required String image, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 250,
            child: Image.asset(image, fit: BoxFit.contain),
          ),
          const SizedBox(height: 50),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}