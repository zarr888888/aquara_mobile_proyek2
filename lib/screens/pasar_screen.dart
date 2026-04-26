import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'tambah_jualan_screen.dart';
import 'profil_screen.dart'; 
import 'edit_jualan_screen.dart';

class PasarScreen extends StatefulWidget {
  final int? targetItemId;
  const PasarScreen({super.key, this.targetItemId});

  @override
  _PasarScreenState createState() => _PasarScreenState();
}

class _PasarScreenState extends State<PasarScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _pasarFuture;
  
  final String storageUrl = 'http://192.168.43.63:8000/storage/'; 
  
  bool _isLoggedIn = false;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _pasarFuture = _apiService.fetchPasar();
    _checkLoginStatus(); 
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getString('token') != null; 
      currentUserId = prefs.getString('user_id');
    });
  }

  String formatRupiah(int price) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price);
  }

  void _hubungiPenjual(String nomor, String namaIkan, String harga) async {
    String nomorClean = nomor.replaceAll(RegExp(r'[^0-9]'), '');
    if (nomorClean.startsWith('0')) {
      nomorClean = '62${nomorClean.substring(1)}';
    }

    String pesan = "Halo Bapak/Ibu, saya tertarik dengan *$namaIkan* seharga *$harga* yang ada di aplikasi AQUARA. Apakah masih tersedia?";
    String url = "https://wa.me/$nomorClean?text=${Uri.encodeComponent(pesan)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka WhatsApp")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Pasar Ikan Indramayu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => setState(() { _pasarFuture = _apiService.fetchPasar(); })),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _pasarFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: indramayuBlue));
          } else if (snapshot.hasError) {
            return const Center(child: Text("Gagal memuat pasar."));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada ikan yang dijual."));
          }

          List<dynamic> pasarItems = List.from(snapshot.data!);

          if (widget.targetItemId != null) {
            int targetIndex = pasarItems.indexWhere((item) => item['id'] == widget.targetItemId);
            if (targetIndex != -1) {
              var targetItem = pasarItems.removeAt(targetIndex);
              pasarItems.insert(0, targetItem);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pasarItems.length, 
            itemBuilder: (context, index) {
              var item = pasarItems[index]; 
              return _buildPasarCard(item);
            },
          );
        },
      ),
      
      floatingActionButton: _isLoggedIn 
        ? FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TambahJualanScreen()),
              );
              if (result == true) setState(() { _pasarFuture = _apiService.fetchPasar(); });
            },
            label: Text("Jual Hasil Tambak", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add_shopping_cart),
            backgroundColor: const Color(0xFF8CC63F),
          )
        : null,
    );
  }

  Future<void> _confirmDeleteProduct(int id) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Hapus Jualan?"),
        content: const Text("Anda yakin ingin menghapus ikan ini dari pasar?"),
        actions: [
          TextButton(child: const Text("Batal", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(context);
              
              bool success = await _apiService.deletePasarItem(id); 
              if (success) {
                setState(() { _pasarFuture = _apiService.fetchPasar(); });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jualan berhasil dihapus.")));
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus jualan.")));
              }
            },
          ),
        ],
      );
    },
  );
}

  Widget _buildPasarCard(dynamic item) {
    String fotoUrl = item['foto'] != null ? storageUrl + item['foto'] : '';
    String namaIkan = item['nama_ikan'] ?? 'Ikan Tanpa Nama';
    String hargaFormatted = "${formatRupiah(int.tryParse(item['harga'].toString()) ?? 0)} / Kg"; 
    String penjual = item['user'] != null ? item['user']['name'] : 'Petani Anonim';
    String lokasi = item['lokasi'] ?? 'Indramayu';
    String deskripsi = item['deskripsi'] ?? 'Tidak ada keterangan spesifikasi/minimal order.';
    
    String pathFotoProfil = '';
    if (item['user'] != null && item['user']['foto_profil'] != null) {
      pathFotoProfil = item['user']['foto_profil'].toString();
    }
    String fotoProfilUserUrl = pathFotoProfil.isNotEmpty ? storageUrl + pathFotoProfil : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: fotoUrl.isNotEmpty 
              ? Image.network(fotoUrl, height: 180, width: double.infinity, fit: BoxFit.cover)
              : Container(height: 180, width: double.infinity, color: Colors.blue[50], child: const Icon(Icons.image, size: 50, color: Colors.blue)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(namaIkan, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(hargaFormatted, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF009FE3))),
                    
                    if (_isLoggedIn && currentUserId != null && item['user_id'].toString() == currentUserId)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditJualanScreen(jualan: item),
                                ),
                              );
                              
                              if (result == true) {
                                setState(() {
                                  _pasarFuture = _apiService.fetchPasar();
                                });
                              }
                            } else if (value == 'delete') {
                              _confirmDeleteProduct(item['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text("Edit Jualan")),
                            const PopupMenuItem(value: 'delete', child: Text("Hapus Jualan", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (item['user_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilScreen(
                                publicUserId: item['user_id'].toString(),
                                publicUserName: penjual,
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          fotoProfilUserUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  fotoProfilUserUrl, width: 20, height: 20, fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.person, size: 16, color: Colors.grey),
                                )
                              )
                            : const Icon(Icons.person, size: 16, color: Colors.grey),
                          
                          const SizedBox(width: 4),
                          Text(
                            penjual, 
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF009FE3),
                              fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline,
                            )
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(lokasi, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deskripsi,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _hubungiPenjual(item['nomor_wa'], namaIkan, hargaFormatted),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: Text("NEGO VIA WHATSAPP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}