import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InfoDinasDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const InfoDinasDetailScreen({super.key, required this.post});

  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd MMMM yyyy').format(date);
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    String imageUrl = post['image'] != null 
        ? "https://aquara.app/storage/${post['image']}" 
        : "https://via.placeholder.com/600x400";

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. GAMBAR HEADER BESAR
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF009FE3),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(color: Colors.grey, child: const Icon(Icons.broken_image, size: 50, color: Colors.white)),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(50)),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 2. ISI BERITA
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori & Tanggal
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFF009FE3).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                          child: Text(post['category'], style: GoogleFonts.poppins(color: const Color(0xFF009FE3), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 5),
                        Text(formatDate(post['created_at']), style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Judul Besar
                    Text(
                      post['title'],
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                    const SizedBox(height: 10),

                    // Penulis
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(0xFF009FE3),
                          child: Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text("Diposting oleh: ${post['author']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                    const Divider(height: 40),

                    // ISI KONTEN (DESKRIPSI LENGKAP)
                    Text(
                      post['content'],
                      style: GoogleFonts.poppins(fontSize: 14, height: 1.8, color: Colors.grey[800]),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}