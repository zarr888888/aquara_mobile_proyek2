import '../widgets/reference_list_builder.dart';
import '../services/api_result.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class MarketPriceScreen extends StatelessWidget {
  const MarketPriceScreen({super.key, this.api});
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _MarketPriceScreenContent(api: api),
  );
}

class _MarketPriceScreenContent extends StatefulWidget {
  const _MarketPriceScreenContent({this.api});
  final ApiService? api;

  @override
  State<_MarketPriceScreenContent> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<_MarketPriceScreenContent>
    with SessionOwnedState<_MarketPriceScreenContent> {
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

  @override
  void initState() {
    super.initState();
    _fishList = _loadReference(_apiService.fetchFishTypes);
  }

  String formatRupiah(double number) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(number);
  }

  String formatDate(String? dateString) {
    try {
      DateTime date = DateTime.parse(dateString ?? '');
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Info Harga Pasar",
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
      ),
      body: Column(
        children: [
          // BANNER ATAS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF009FE3),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pantauan Harga Komoditas",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Harga rata-rata tingkat petani di Kab. Indramayu",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // LIST HARGA
          Expanded(
            child: ReferenceListBuilder(
              future: _fishList,
              retry: () => _loadReference(_apiService.fetchFishTypes),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text("Gagal memuat data: ${snapshot.error}"),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Belum ada data harga."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var fish = snapshot.data![index];
                    return _buildPriceCard(fish);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> fish) {
    String imageUrl = fish['image_url'] ?? '';

    // Harga
    double price = double.parse(fish['market_price_per_kg'].toString());

    // Tanggal Update (ambil dari updated_at)
    String lastUpdate = formatDate(fish['updated_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // FOTO KECIL (THUMBNAIL)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isEmpty
                ? const Icon(Icons.image_not_supported_outlined)
                : Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.set_meal, color: Colors.grey),
                    ),
                  ),
          ),
          const SizedBox(width: 15),

          // NAMA DAN TANGGAL
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fish['name'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 5),
                    Text(
                      "Update: $lastUpdate",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // HARGA (HIGHTLIGHT)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupiah(price),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF009FE3),
                ),
              ),
              Text(
                "/ Kg",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
