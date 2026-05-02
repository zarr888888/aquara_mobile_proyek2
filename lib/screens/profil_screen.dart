import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'edit_profil_screen.dart';
import 'pasar_screen.dart';
import 'pengaturan_screen.dart';

class ProfilScreen extends StatefulWidget {
  final String? publicUserId;
  final String? publicUserName;

  const ProfilScreen({super.key, this.publicUserId, this.publicUserName});

  @override
  _ProfilScreenState createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final ApiService _apiService = ApiService();
  
  String _currentUserId = '';
  String _currentUserName = '';
  bool _isMyProfile = true;
  
  String _fokusBudidaya = "Memuat data...";
  String _fotoProfilUrl = ""; 
  
  Future<List<dynamic>>? _stokIkanFuture;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (widget.publicUserId != null) {
      _isMyProfile = false;
      _currentUserId = widget.publicUserId!;
      _currentUserName = widget.publicUserName ?? 'Penambak AQUARA';
    } else {
      _isMyProfile = true;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id') ?? '';
      _currentUserName = prefs.getString('user_name') ?? 'Petani/Pengepul';
    }

    if (_currentUserId.isNotEmpty) {
      final userData = await _apiService.getUserProfile(_currentUserId);
      if (userData != null && mounted) {
        setState(() {
          _currentUserName = userData['name'] ?? _currentUserName;
          _fokusBudidaya = userData['fokus_budidaya'] ?? "Belum ada fokus budidaya";
          _fotoProfilUrl = userData['foto_profil'] ?? "";
        });
      }
    }

    _stokIkanFuture = _apiService.fetchPasar().then((semuaPasar) {
      return semuaPasar.where((item) => item['user_id'].toString() == _currentUserId).toList();
    });
    
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);
    final indramayuGreen = const Color(0xFF8CC63F);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_isMyProfile ? "Profil Saya" : "Informasi Penambak", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PengaturanScreen()));
              },
            ),
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Keluar Akun", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    content: Text("Apakah Anda yakin ingin keluar?", style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal")),
                      TextButton(onPressed: _handleLogout, child: Text("Keluar", style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _currentUserId.isEmpty && _isMyProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                    decoration: BoxDecoration(color: indramayuBlue, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_fotoProfilUrl.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent, 
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        InteractiveViewer(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Image.network(
                                              'https://aquara.app/storage/$_fotoProfilUrl',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -10,
                                          right: -10,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 50, backgroundColor: Colors.white,
                            child: _fotoProfilUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      'https://aquara.app/storage/$_fotoProfilUrl',
                                      width: 100, height: 100, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 60, color: indramayuBlue),
                                    )
                                  )
                                : Icon(Icons.person, size: 60, color: indramayuBlue),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(_currentUserName, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.set_meal, color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  Text("Fokus Budidaya:", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_fokusBudidaya, style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_isMyProfile)
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfilScreen(currentName: _currentUserName, currentFokus: _fokusBudidaya == "Belum ada fokus budidaya" ? "" : _fokusBudidaya)));
                                if (result == true) {
                                  _loadProfileData(); 
                                }
                              },
                              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                              label: Text("EDIT PROFIL LENGKAP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_isMyProfile ? "Stok Panen Saya" : "Stok Ikan Tersedia", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                  height: 300,
                  child: _stokIkanFuture == null 
                      ? const Center(child: CircularProgressIndicator()) 
                      : FutureBuilder<List<dynamic>>(
                          future: _stokIkanFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return const Center(child: Text("Gagal memuat stok."));
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey[300]), const SizedBox(height: 10), Text("Belum ada stok ikan.", style: GoogleFonts.poppins(color: Colors.grey))]));
                        
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            var item = snapshot.data![index];
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1, margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PasarScreen(targetItemId: item['id']),
                                    ),
                                  );
                                },
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: item['foto'] != null && item['foto'].toString().isNotEmpty
                                      ? Image.network('https://aquara.app/storage/' + item['foto'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 50, height: 50, color: indramayuBlue.withOpacity(0.1), child: const Icon(Icons.image_not_supported, color: Color(0xFF009FE3))))
                                      : Container(width: 50, height: 50, color: indramayuBlue.withOpacity(0.1), child: const Icon(Icons.water_drop, color: Color(0xFF009FE3))),
                                ),
                                title: Text(item['nama_ikan'] ?? '-', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text("${item['harga']}/Kg", style: GoogleFonts.poppins(color: indramayuGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}