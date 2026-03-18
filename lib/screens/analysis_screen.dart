import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String? autoFishName;
  final String? autoPrice;
  final String? autoFcr;
  final String? autoPeriod;

  const AnalysisScreen({
    super.key, 
    this.autoFishName, 
    this.autoPrice, 
    this.autoFcr, 
    this.autoPeriod
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _fishList;

  Map<String, dynamic>? _selectedFish;
  final TextEditingController _luasKolamController = TextEditingController();
  final TextEditingController _jumlahBibitController = TextEditingController();
  final TextEditingController _hargaBibitController = TextEditingController(text: "200");
  final TextEditingController _biayaLainController = TextEditingController(text: "0");

  double _estimasiPanenKg = 0;
  double _kebutuhanPakanKg = 0;
  double _biayaPakan = 0;
  double _biayaBibit = 0;
  double _biayaLain = 0;
  double _totalModal = 0;
  double _omzet = 0;
  double _keuntungan = 0;
  
  String _statusKepadatan = "";
  Color _warnaStatusKepadatan = Colors.grey;
  bool _showResult = false;

  void _refreshFishList() {
    setState(() {
      _fishList = _apiService.fetchFishTypes();
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshFishList(); 

    _fishList.then((dataSemuaIkan) {
      if (widget.autoFishName != null) {
        
        var ikanKetemu = dataSemuaIkan.firstWhere(
          (ikan) => ikan['name'].toString().toLowerCase().contains(widget.autoFishName!.toLowerCase()),
          orElse: () => null
        );

        if (ikanKetemu != null) {
          setState(() {
            _selectedFish = ikanKetemu; 
          });
        }
      }
    });

    if (widget.autoFishName != null) {
      String namaIkan = widget.autoFishName!.toLowerCase();
      String hargaBibitOtomatis = "0";

      if (namaIkan.contains("lele")) {
        hargaBibitOtomatis = "200";
      } else if (namaIkan.contains("nila")) {
        hargaBibitOtomatis = "500";
      } else if (namaIkan.contains("mas")) {
        hargaBibitOtomatis = "1000";
      } else if (namaIkan.contains("gurame")) {
        hargaBibitOtomatis = "2500";
      } else if (namaIkan.contains("patin")) {
        hargaBibitOtomatis = "800";
      } else if (namaIkan.contains("mujair")) {
        hargaBibitOtomatis = "400";
      } else if (namaIkan.contains("bawal")) {
        hargaBibitOtomatis = "300";
      } else if (namaIkan.contains("sidat")) {
        hargaBibitOtomatis = "10000";
      } else {
        hargaBibitOtomatis = "500";
      }
      
      _hargaBibitController.text = hargaBibitOtomatis;
    }
  }

  String formatRupiah(double number) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(number);
  }

  void _hitungAnalisa() {
    if (_selectedFish == null || _jumlahBibitController.text.isEmpty || _luasKolamController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap lengkapi semua data input!")),
      );
      return;
    }

    try {
      double luasKolam = double.parse(_luasKolamController.text.replaceAll('.', ''));
      double jumlahBibit = double.parse(_jumlahBibitController.text.replaceAll('.', ''));
      double hargaBibitPerEkor = double.parse(_hargaBibitController.text.replaceAll('.', ''));
      double biayaLainInput = double.parse(_biayaLainController.text.replaceAll('.', ''));
      
      double fcr = double.parse(_selectedFish!['fcr_ratio'].toString());
      double sr = double.parse(_selectedFish!['survival_rate'].toString()); 
      double hargaPakan = double.parse(_selectedFish!['feed_price_per_kg'].toString());
      double hargaJual = double.parse(_selectedFish!['market_price_per_kg'].toString());
      double maxPadat = double.parse(_selectedFish!['standard_density_per_m2'].toString());

      double kepadatanAktual = jumlahBibit / luasKolam;
      String status;
      Color warna;

      if (kepadatanAktual > maxPadat) {
        status = "BERISIKO TINGGI (Kepadatan ${kepadatanAktual.toStringAsFixed(0)} ekor/m²)";
        warna = Colors.red;
      } else if (kepadatanAktual > (maxPadat * 0.8)) {
        status = "CUKUP PADAT (Kepadatan ${kepadatanAktual.toStringAsFixed(0)} ekor/m²)";
        warna = Colors.orange;
      } else {
        status = "IDEAL (Kepadatan ${kepadatanAktual.toStringAsFixed(0)} ekor/m²)";
        warna = Colors.green;
      }

      double ikanHidup = jumlahBibit * (sr / 100);
      double beratPerEkor = 0.1;
      double totalPanenKg = ikanHidup * beratPerEkor;
      double totalPakanKg = totalPanenKg * fcr;

      double totalBiayaBibit = jumlahBibit * hargaBibitPerEkor;
      double totalBiayaPakan = totalPakanKg * hargaPakan;
      double modalTotal = totalBiayaBibit + totalBiayaPakan + biayaLainInput;

      double totalOmzet = totalPanenKg * hargaJual;
      double totalUntung = totalOmzet - modalTotal;

      setState(() {
        _estimasiPanenKg = totalPanenKg;
        _kebutuhanPakanKg = totalPakanKg;
        _biayaPakan = totalBiayaPakan;
        _biayaBibit = totalBiayaBibit;
        _biayaLain = biayaLainInput;
        _totalModal = modalTotal;
        _omzet = totalOmzet;
        _keuntungan = totalUntung;
        _statusKepadatan = status;
        _warnaStatusKepadatan = warna;
        _showResult = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pastikan input angka valid!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Analisa Usaha", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF009FE3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Parameter Input", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    
                    FutureBuilder<List<dynamic>>(
                      future: _fishList,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        
                        return DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: InputDecoration(
                            labelText: "Pilih Komoditas",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                          ),
                          value: _selectedFish,
                          items: snapshot.data!.map((fish) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: fish,
                              child: Text(fish['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFish = value;
                              _showResult = false; 
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _luasKolamController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Luas Kolam",
                              hintText: "m²",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              suffixText: "m²",
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextField(
                            controller: _jumlahBibitController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Jumlah Bibit",
                              hintText: "Ekor",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              suffixText: "Ekor",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _hargaBibitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Harga Bibit per Ekor",
                        prefixText: "Rp ",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _biayaLainController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Biaya Operasional (Listrik/Obat)",
                        prefixText: "Rp ",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _hitungAnalisa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009FE3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text("HITUNG ANALISA", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_showResult) ...[
              Text("Hasil Analisa", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: _warnaStatusKepadatan.withOpacity(0.1),
                  border: Border.all(color: _warnaStatusKepadatan),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _warnaStatusKepadatan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusKepadatan,
                        style: GoogleFonts.poppins(color: _warnaStatusKepadatan, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8CC63F), Color(0xFF6A9E25)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Estimasi Keuntungan Bersih", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                        const SizedBox(height: 5),
                        Text(formatRupiah(_keuntungan), style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.monetization_on, color: Colors.white, size: 36),
                  ],
                ),
              ),
              
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(child: _buildInfoCard("Total Modal", formatRupiah(_totalModal), Icons.account_balance_wallet, Colors.orange)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard("Est. Omzet", formatRupiah(_omzet), Icons.store, Colors.blue)),
                ],
              ),
              const SizedBox(height: 10),
               Row(
                children: [
                  Expanded(child: _buildInfoCard("Biaya Pakan", formatRupiah(_biayaPakan), Icons.restaurant, Colors.redAccent)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard("Biaya Bibit", formatRupiah(_biayaBibit), Icons.spa, Colors.teal)),
                ],
              ),

              const SizedBox(height: 20),
              
              Text("Rincian Teknis", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    _buildTechnicalRow("Biaya Operasional", formatRupiah(_biayaLain)),
                    const Divider(),
                    _buildTechnicalRow("Total Pakan", "${_kebutuhanPakanKg.toStringAsFixed(1)} Kg"),
                    const Divider(),
                    _buildTechnicalRow("Est. Panen", "${_estimasiPanenKg.toStringAsFixed(1)} Kg"),
                    const Divider(),
                    _buildTechnicalRow("FCR", "${_selectedFish!['fcr_ratio']}"),
                    const Divider(),
                    _buildTechnicalRow("SR", "${_selectedFish!['survival_rate']}%"),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTechnicalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13)),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}