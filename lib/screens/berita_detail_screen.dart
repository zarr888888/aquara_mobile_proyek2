import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BeritaDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final String imageUrl;

  const BeritaDetailScreen({
    Key? key,
    required this.title,
    required this.content,
    required this.date,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Berita',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF009FE3),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        date,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const Divider(height: 30, thickness: 1),

                  Text(
                    content,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6, 
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 250,
      color: Colors.blue[50],
      child: Icon(Icons.image_outlined, size: 80, color: Colors.blue[200]),
    );
  }
}