import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // 🚀 FITUR BARU BUKA BROWSER
import '../services/api_service.dart';
import 'berita_detail_screen.dart';

class BeritaScreen extends StatefulWidget {
  const BeritaScreen({Key? key}) : super(key: key);

  @override
  _BeritaScreenState createState() => _BeritaScreenState();
}

class _BeritaScreenState extends State<BeritaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  late Future<List<dynamic>> _postsFuture;
  late Future<List<dynamic>> _beritaNasionalFuture;

  final String storageUrl = 'http://192.168.43.63:8000/storage/';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _postsFuture = _apiService.fetchPosts();
    _beritaNasionalFuture = _apiService.fetchBeritaNasional();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String formatTanggal(String dateString) {
    try {
      DateTime dt = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(dt); 
    } catch (e) {
      return dateString.substring(0, 10);
    }
  }

  String bersihkanHtml(String text) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return text.replaceAll(exp, '').replaceAll('&nbsp;', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Berita & Informasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF009FE3),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Info Diskanla'),
            Tab(text: 'Kementerian & Umum'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBeritaList(_postsFuture, true),
          _buildBeritaList(_beritaNasionalFuture, false),
        ],
      ),
    );
  }

  Widget _buildBeritaList(Future<List<dynamic>> sumberData, bool isDariLaravel) {
    return FutureBuilder<List<dynamic>>(
      future: sumberData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF009FE3)));
        } else if (snapshot.hasError) {
          return Center(child: Text("Gagal memuat berita.", style: GoogleFonts.poppins()));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("Belum ada berita hari ini.", style: GoogleFonts.poppins()));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var berita = snapshot.data![index];
            
            String judul = berita['title'] ?? 'Tanpa Judul';
            String tanggal = '-';
            String isi = '';
            String imageUrl = '';
            String linkAsli = ''; 

            if (isDariLaravel) {
              isi = berita['content'] ?? '';
              tanggal = berita['created_at'] != null ? formatTanggal(berita['created_at']) : '-';
              imageUrl = berita['image'] != null ? storageUrl + berita['image'] : '';
            } else {
              isi = bersihkanHtml(berita['description'] ?? '');
              tanggal = berita['pubDate'] != null ? formatTanggal(berita['pubDate']) : '-';
              linkAsli = berita['link'] ?? ''; 
              
              imageUrl = 'https://dummyimage.com/800x400/009FE3/ffffff.png&text=Kementerian+%26+Umum';
            }

            return _buildBeritaCard(context, judul, isi, tanggal, imageUrl, isDariLaravel, linkAsli);
          },
        );
      },
    );
  }

  Widget _buildBeritaCard(BuildContext context, String title, String content, String date, String imageUrl, bool isDariLaravel, String linkAsli) {
    return InkWell(
      onTap: () async {
        if (isDariLaravel) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BeritaDetailScreen(
                title: title, content: content, date: date, imageUrl: imageUrl,
              ),
            ),
          );
        } else {
          if (linkAsli.isNotEmpty) {
            final Uri url = Uri.parse(linkAsli);
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka browser')));
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(date, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDariLaravel ? content : "Baca berita selengkapnya di website resmi...",
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isDariLaravel ? "Baca Selengkapnya >>" : "Buka Sumber >>",
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF009FE3)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180, width: double.infinity, color: Colors.blue[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 50, color: Colors.blue[200]),
          Text("Memuat foto...", style: GoogleFonts.poppins(color: Colors.blue[300], fontSize: 12))
        ],
      ),
    );
  }
}