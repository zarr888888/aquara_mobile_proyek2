import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'analysis_screen.dart';

class SemuaKomoditasScreen extends StatefulWidget {
  const SemuaKomoditasScreen({super.key});

  @override
  State<SemuaKomoditasScreen> createState() => _SemuaKomoditasScreenState();
}

class _SemuaKomoditasScreenState extends State<SemuaKomoditasScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _fishList;

  @override
  void initState() {
    super.initState();
    _fishList = _apiService.fetchFishTypes();
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

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Semua Komoditas", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fishList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: indramayuBlue));
          } else if (snapshot.hasError) {
            return const Center(child: Text("Gagal memuat data."));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada data ikan."));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 20),
            itemCount: snapshot.data!.length,
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
                child: _buildCommodityCard(nama, "FCR $fcr • Panen $panen Hari", formatRupiah(harga), indramayuBlue, imageUrl),
              );
            },
          );
        },
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
        boxShadow: [BoxShadow(color: const Color(0xFF009FE3).withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            height: 54, width: 54,
            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Icon(Icons.water_drop, color: accentColor))
                  : Icon(Icons.water_drop, color: accentColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(specs, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Harga Pasar", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey)),
              Text(price, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor)),
            ],
          ),
        ],
      ),
    );
  }
}