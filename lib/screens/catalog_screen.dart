import '../widgets/reference_list_builder.dart';
import '../services/api_result.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.api});
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _CatalogScreenContent(api: api),
  );
}

class _CatalogScreenContent extends StatefulWidget {
  const _CatalogScreenContent({this.api});
  final ApiService? api;

  @override
  State<_CatalogScreenContent> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<_CatalogScreenContent>
    with
        SingleTickerProviderStateMixin,
        SessionOwnedState<_CatalogScreenContent> {
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  Future<ApiResult<List<dynamic>>> _loadReference(
    Future<ApiResult<List<dynamic>>> Function({
      required SessionSnapshot expectedSession,
    })
    fetch,
  ) async {
    try {
      final owner = await _apiService.session.snapshot();
      if (!sessionActive || owner.revision != _apiService.session.revision) {
        return ApiResult.failure(
          ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
        );
      }
      return fetch(expectedSession: owner);
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.session,
          message: 'Data tidak dapat dimuat. Silakan coba kembali.',
        ),
      );
    }
  }

  late Future<ApiResult<List<dynamic>>> _fishList;
  late Future<ApiResult<List<dynamic>>> _stockList;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fishList = _loadReference(_apiService.fetchFishTypes);
    _stockList = _loadReference(_apiService.fetchStocks);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String formatRupiah(double number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  // --- FUNGSI POPUP DETAIL (KEMBALI LAGI!) ---
  void _showFishDetail(Map<String, dynamic> fish) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                fish['name'],
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF009FE3),
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),

              _buildDetailRow(
                Icons.calendar_today,
                "Masa Panen",
                "${fish['harvest_duration_days']} Hari",
              ),
              _buildDetailRow(
                Icons.restaurant,
                "FCR (Rasio Pakan)",
                "${fish['fcr_ratio']}",
              ),
              _buildDetailRow(
                Icons.favorite,
                "Survival Rate (SR)",
                "${fish['survival_rate']}%",
              ),
              _buildDetailRow(
                Icons.waves,
                "Kepadatan Max",
                "${fish['standard_density_per_m2']} ekor/m²",
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.orange),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Harga Jual Pasar",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          formatRupiah(
                            double.parse(
                              fish['market_price_per_kg'].toString(),
                            ),
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(color: Colors.grey[800]),
            ),
          ),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Katalog Ikan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF009FE3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: "Ensiklopedia"),
            Tab(text: "Bursa Stok"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildEnsiklopediaTab(), _buildStockTab()],
      ),
    );
  }

  // --- TAB 1: ENSIKLOPEDIA ---
  Widget _buildEnsiklopediaTab() {
    return ReferenceListBuilder(
      future: _fishList,
      retry: () => _loadReference(_apiService.fetchFishTypes),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Belum ada data jenis ikan."));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(15),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.75,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var fish = snapshot.data![index];
            // GANTI IP DI SINI (Sesuaikan Laptop Mas)
            String imageUrl = fish['image_url'] ?? '';

            // TAMBAHAN: GestureDetector biar bisa diklik lagi!
            return GestureDetector(
              onTap: () => _showFishDetail(fish),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: imageUrl.isEmpty
                            ? const Icon(Icons.image_not_supported_outlined)
                            : Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              fish['name'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockTab() {
    return ReferenceListBuilder(
      future: _stockList,
      retry: () => _loadReference(_apiService.fetchStocks),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.store_mall_directory_outlined,
                  size: 50,
                  color: Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  "Belum ada stok tersedia saat ini.",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF009FE3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF009FE3).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.support_agent,
                    color: Color(0xFF009FE3),
                    size: 35,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Ingin stok Anda tampil di sini?",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Hubungi Admin AQUARA untuk mendaftar.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      String adminPhone = "6285321820026";
                      var url =
                          "https://wa.me/$adminPhone?text=Halo Admin AQUARA, saya ingin mendaftarkan stok ikan tambak saya agar tampil di halaman Bursa Stok aplikasi.";

                      // LANGSUNG DOBRAK BUKA URL TANPA canLaunchUrl
                      if (!await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      )) {
                        if (!context.mounted || !sessionActive) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Gagal membuka WhatsApp"),
                          ),
                        );
                      }
                    },
                    child: Text(
                      "WA Admin",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var stock = snapshot.data![index];
                  var fish = stock['fish_type'] ?? {'name': '-'};

                  String imageUrl = fish['image_url'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.image_not_supported_outlined)
                              : Image.network(
                                  imageUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    width: 70,
                                    height: 70,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.set_meal),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fish != null ? fish['name'] : 'Ikan',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Pengepul: ${stock['pengepul_name']}",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 5,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      Text(
                                        " ${stock['location']}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.inventory_2,
                                        size: 12,
                                        color: Colors.orange,
                                      ),
                                      Text(
                                        " ${stock['amount_kg']} Kg",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            String phoneNumber = stock['phone_number'];
                            var url =
                                "https://wa.me/$phoneNumber?text=Halo ${stock['pengepul_name']}, saya tertarik dengan stok ${fish['name']} Anda.";

                            // LANGSUNG DOBRAK BUKA URL TANPA canLaunchUrl
                            if (!await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            )) {
                              if (!context.mounted || !sessionActive) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Gagal membuka WhatsApp"),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Icon(
                              Icons.phone,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
