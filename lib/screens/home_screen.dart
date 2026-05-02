import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'analysis_screen.dart';
import 'catalog_screen.dart';
import 'market_price_screen.dart';
import 'info_dinas_screen.dart';
import 'forum_screen.dart';
import 'consultation_screen.dart';
import 'berita_screen.dart'; 
import 'pasar_screen.dart';
import 'login_screen.dart'; 
import 'profil_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'semua_komoditas_screen.dart';
import 'notifikasi_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _fishList;

  int _selectedIndex = 0;
  bool _isLoggedIn = false; 
  String _userName = "";
  String _fotoProfil = "";

  final PageController _bannerController = PageController(viewportFraction: 0.92);
  
  final List<String> _bannerImages = [
    'assets/banner_analisausaha.png', 
    'assets/banner_hargapasar.png', 
    'assets/banner_forum.png', 
    'assets/banner konsultasi ai.png',
  ];

  int _currentBannerIndex = 0;

  Timer? _bannerTimer;

  void _startAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerController.hasClients) {
        int nextPage = _currentBannerIndex + 1;
        
        if (nextPage >= _bannerImages.length) {
          nextPage = 0;
        }
        
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500), 
          curve: Curves.easeInOut,
        );
      }
    });
  }

  final List<String> _bannerTitles = [
    "Analisa Panen Cerdas",
    "Cek Harga & Stok Pasar Hari Ini",
    "Diskusi Bersama Komunitas",
    "Foto Ikan dan AI Menjawabnya",
  ];

  @override
  void initState() {
    super.initState();
    _fishList = _apiService.fetchFishTypes();
    _checkLoginStatus();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose(); 
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getString('token') != null;
      _userName = prefs.getString('user_name') ?? "Pembudidaya"; 
      _fotoProfil = prefs.getString('foto_profil') ?? "";
    });
  }

  String formatRupiah(dynamic price) {
    try {
      double priceDouble = double.parse(price.toString());
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return formatter.format(priceDouble);
    } catch (e) {
      return "Rp -";
    }
  }

  Widget _buildBeranda(Color indramayuBlue, Color indramayuGreen) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0079C3),
                    indramayuBlue, 
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_isLoggedIn) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = 3;
                            });
                          },
                          child: Container(
                            height: 46,
                            width: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                              color: Colors.white.withOpacity(0.2), 
                              image: _fotoProfil.isNotEmpty 
                                  ? DecorationImage(
                                      image: NetworkImage("https://aquara.app/storage/$_fotoProfil"), 
                                      fit: BoxFit.cover,
                                    )
                                  : null, 
                            ),
                            child: _fotoProfil.isEmpty 
                                ? const Icon(Icons.person, color: Colors.white, size: 28) 
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoggedIn ? "Hallo, $_userName " : "Diskanla Indramayu",
                            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "AQUARA",
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_isLoggedIn) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const NotifikasiScreen()));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_isLoggedIn ? Icons.notifications_outlined : Icons.login, color: Colors.white, size: 20),
                          if (!_isLoggedIn) ...[
                            const SizedBox(width: 6),
                            Text("Login", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                          ]
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "Mendukung Pembudidaya", 
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      height: 160,
                      child: PageView.builder(
                        controller: _bannerController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        },
                        itemCount: _bannerImages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              if (index == 0) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalysisScreen()));
                              } else if (index == 1) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PasarScreen()));
                              } else if (index == 2) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ForumScreen()));
                              } else if (index == 3) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsultationScreen()));
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12), 
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                                ],
                                image: DecorationImage(
                                  image: AssetImage(_bannerImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                  ),
                                ),
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                      _bannerTitles[index],
                                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4), 
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _bannerImages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300), 
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: _currentBannerIndex == index ? 20 : 6, 
                              decoration: BoxDecoration(
                                color: _currentBannerIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Layanan Utama",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.80, 
                    children: [
                      _buildMenuIcon(context, "Analisa Usaha", 'assets/analisa usaha.png', indramayuGreen, indramayuGreen.withOpacity(0.1)),
                      _buildMenuIcon(context, "Harga Pasar", 'assets/harga pasar.png', Colors.orange, Colors.orange.withOpacity(0.1)),
                      _buildMenuIcon(context, "Katalog Ikan", 'assets/katalog ikan.png', Colors.blueAccent, Colors.blueAccent.withOpacity(0.1)),
                      _buildMenuIcon(context, "Forum", 'assets/forum.png', Colors.purple, Colors.purple.withOpacity(0.1)),
                      _buildMenuIcon(context, "Konsultasi", 'assets/konsultasi.png', Colors.teal, Colors.teal.withOpacity(0.1)),
                      _buildMenuIcon(context, "Info Dinas", 'assets/dinas.png', indramayuBlue, indramayuBlue.withOpacity(0.1)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Analisa Komoditas",
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SemuaKomoditasScreen()));
                    },
                    child: Text(
                      "Lihat Semua",
                      style: GoogleFonts.poppins(fontSize: 12, color: indramayuBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _fishList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: indramayuBlue),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 30),
                        const SizedBox(height: 10),
                        Text(
                          "Gagal terhubung ke Server.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("Belum ada data ikan.", style: GoogleFonts.poppins()));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length > 2 ? 2 : snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var ikan = snapshot.data![index];
                    String nama = ikan['name'] ?? 'Tanpa Nama';
                    String fcr = ikan['fcr_ratio']?.toString() ?? '-';
                    String panen = ikan['harvest_duration_days']?.toString() ?? '-';
                    var harga = ikan['market_price_per_kg'];
                    String? imageUrl = ikan['image_url'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalysisScreen(
                              autoFishName: nama,            
                              autoPrice: harga.toString(),  
                              autoFcr: fcr,                
                              autoPeriod: panen,         
                            ),
                          ),
                        );
                      },
                      child: _buildCommodityCard(
                        nama,
                        "FCR $fcr • Panen $panen Hari",
                        formatRupiah(harga),
                        indramayuBlue,
                        imageUrl,
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const BeritaScreen()));
                },
                child: Container(
                  height: 130,
                  width: double.infinity, 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [const Color(0xFF0079C3), indramayuBlue],
                    ),
                    boxShadow: [
                      BoxShadow(color: indramayuBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1)),
                      ),
                      Positioned(
                        right: 40,
                        bottom: -30,
                        child: CircleAvatar(radius: 40, backgroundColor: Colors.white.withOpacity(0.1)),
                      ),
                    
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                              child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Info Diskanla & Umum Terkini",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Info penyuluhan & berita perikanan",
                                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);
    final indramayuGreen = const Color(0xFF8CC63F);

    final List<Widget> pages = [
      _buildBeranda(indramayuBlue, indramayuGreen),      
      const BeritaScreen(),                               
      const PasarScreen(),
      _isLoggedIn ? const ProfilScreen() : const LoginScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _checkLoginStatus();
        },
        selectedItemColor: indramayuBlue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: "Berita"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: "Pasar"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profil"),
        ],
      ),
    );
  }

  Widget _buildMenuIcon(BuildContext context, String title, String imagePath, Color shadowColor, Color bgColor) {
    return InkWell(
      onTap: () {
        if (title == "Analisa Usaha") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalysisScreen()));
        } else if (title == "Katalog Ikan") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CatalogScreen()));
        } else if (title == "Harga Pasar") { 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketPriceScreen()));
        } else if (title == "Info Dinas") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const InfoDinasScreen()));
        } else if (title == "Forum") {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ForumScreen()));
        } else if (title == "Konsultasi") { 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsultationScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Fitur $title sedang dikembangkan!")),
          );
        }
      },
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgColor, bgColor.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2), 
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600, 
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityCard(String name, String specs, String price, Color accentColor, String? imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 24, right: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009FE3).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.water_drop, color: accentColor);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    )
                  : Icon(Icons.water_drop, color: accentColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  specs,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Harga Pasar",
                style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey),
              ),
              Text(
                price,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}