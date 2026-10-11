import '../widgets/reference_list_builder.dart';
import '../services/api_result.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'info_dinas_detail_screen.dart';

class InfoDinasScreen extends StatelessWidget {
  const InfoDinasScreen({super.key, this.api});
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: false,
    builder: (_) => _InfoDinasScreenContent(api: api),
  );
}

class _InfoDinasScreenContent extends StatefulWidget {
  const _InfoDinasScreenContent({this.api});
  final ApiService? api;

  @override
  State<_InfoDinasScreenContent> createState() => _InfoDinasScreenState();
}

class _InfoDinasScreenState extends State<_InfoDinasScreenContent>
    with SessionOwnedState<_InfoDinasScreenContent> {
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

  late Future<ApiResult<List<dynamic>>> _posts;

  @override
  void initState() {
    super.initState();
    _posts = _loadReference(_apiService.fetchPosts);
  }

  String formatDate(String? dateString) {
    try {
      DateTime date = DateTime.parse(dateString ?? '');
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "-";
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted && sessionActive) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal membuka link")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Info Dinas",
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Akses Cepat Website",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildLinkButton(
                        "Dinas Perikanan",
                        Icons.language,
                        const Color(0xFF009FE3),
                        "https://perikanan.indramayukab.go.id", // Ganti link asli
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildLinkButton(
                        "Pemprov Jabar",
                        Icons.apartment,
                        Colors.orange,
                        "https://jabarprov.go.id", // Ganti link asli
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BAGIAN 2: BERITA TERBARU (DARI DATABASE)
          Expanded(
            child: ReferenceListBuilder(
              future: _posts,
              retry: () => _loadReference(_apiService.fetchPosts),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Gagal memuat berita",
                      style: GoogleFonts.poppins(),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "Belum ada berita terbaru",
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final post = snapshot.data![index];
                    String imageUrl = post['image_url'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InfoDinasDetailScreen(
                              post: post,
                              api: _apiService,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15),
                              ),
                              child: imageUrl.isEmpty
                                  ? const Icon(
                                      Icons.image_not_supported_outlined,
                                    )
                                  : Image.network(
                                      imageUrl,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 150,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                ),
                                              ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        post['category'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: const Color(0xFF009FE3),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        formatDate(post['created_at']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    post['title'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  // TOMBOL BACA SELENGKAPNYA (VISUAL SAJA)
                                  Row(
                                    children: [
                                      Text(
                                        "Baca Selengkapnya",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: const Color(0xFF009FE3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: Color(0xFF009FE3),
                                      ),
                                    ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(
    String title,
    IconData icon,
    Color color,
    String url,
  ) {
    return InkWell(
      onTap: () => _launchURL(url),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
