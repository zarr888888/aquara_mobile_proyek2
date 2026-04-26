import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'pasar_screen.dart';
import 'forum_screen.dart';
import 'consultation_screen.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});
  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  late Future<List<dynamic>> _notifFuture;

  @override
  void initState() {
    super.initState();
    _notifFuture = ApiService().fetchNotifications();
  }

  IconData _getIcon(String type) {
    if (type == 'pasar') return Icons.storefront_outlined;
    if (type == 'forum') return Icons.forum_outlined;
    if (type == 'ai') return Icons.smart_toy_outlined;
    return Icons.notifications_none;
  }

  Color _getColor(String type) {
    if (type == 'pasar') return Colors.orange;
    if (type == 'forum') return Colors.purple;
    if (type == 'ai') return Colors.teal;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Notifikasi", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF009FE3),
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _notifFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("Belum ada notifikasi.", style: GoogleFonts.poppins()));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
            var n = snapshot.data![index];
            
            return GestureDetector(
              onTap: () {
                if (n['type'] == 'pasar') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PasarScreen()));
                } else if (n['type'] == 'forum') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ForumScreen()));
                } else if (n['type'] == 'ai') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsultationScreen()));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: n['is_read'] == 1 ? Colors.white : Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: _getColor(n['type']).withOpacity(0.1),
                      child: Icon(_getIcon(n['type']), color: _getColor(n['type'])),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['title'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(n['message'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(n['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
              },
          );
        },
      ),
    );
  }
}