import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ApiService {
  final String baseUrl = 'http://192.168.43.63:8000/api'; 

  Future<List<dynamic>> fetchFishTypes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/fish-types'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']; 
      } else {
        throw Exception('Gagal mengambil data');
      }
    } catch (e) {
      print("Error: $e");
      return []; 
    }
  }

  Future<List<dynamic>> fetchPosts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/posts'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal mengambil data berita');
      }
    } catch (e) {
      print("Error fetchPosts: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchBeritaNasional() async {
    try {
      final String rssUrl = 'https://news.google.com/rss/search?q=perikanan+budidaya+ikan+tawar&hl=id&gl=ID&ceid=ID:id';
      final String url = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}';
      
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          return data['items'];
        }
      }
      return [];
    } catch (e) {
      print("Error fetchBeritaNasional: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchStocks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stocks'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']; 
      } else {
        throw Exception('Gagal memuat data stok');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<dynamic>> fetchForumPosts(String currentUserId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/forum?user_id=$currentUserId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else { throw Exception(); }
    } catch (e) { throw Exception(); }
  }
  
  Future<bool> postForum(String userId, String authorName, String content, File? image) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/forum'));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['user_id'] = userId;
      request.fields['author_name'] = authorName;
      request.fields['content'] = content;

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }

      var response = await request.send();
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error Upload Forum: $e");
      return false;
    }
  }

  // 3. EDIT POSTINGAN (PUT)
  Future<bool> updateForumPost(int id, String content, File? imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/forum/$id/update'));
      request.fields['content'] = content;
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }
      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<bool> toggleLikePost(int id, String userId) async {
    final response = await http.post(Uri.parse('$baseUrl/forum/$id/toggle-like'), body: {'user_id': userId});
    return response.statusCode == 200;
  }

  // 4. HAPUS POSTINGAN (DELETE)
  Future<bool> deleteForumPost(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/forum/$id'));
    return response.statusCode == 200;
  }
  
  Future<bool> storeComment(int postId, String author, String content) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentUserId = prefs.getString('user_id') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/forum/$postId/comment'), 
      body: {
        'user_id': currentUserId, 
        'author_name': author,
        'content': content
      }
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteComment(int commentId) async {
    final response = await http.delete(Uri.parse('$baseUrl/forum/comment/$commentId'));
    return response.statusCode == 200;
  }

  Future<List<dynamic>> fetchPasar() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/pasars'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Gagal memuat data pasar');
      }
    } catch (e) {
      throw Exception('Error fetching pasar: $e');
    }
  }

  Future<bool> createPasar({
    required String namaIkan,
    required String harga,
    required String deskripsi,
    required String nomorWa,
    required String lokasi,
    File? foto,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String currentUserId = prefs.getString('user_id') ?? '';
      String? token = prefs.getString('token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/pasars'));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['user_id'] = currentUserId; 
      request.fields['nama_ikan'] = namaIkan;
      request.fields['harga'] = harga;
      request.fields['deskripsi'] = deskripsi;
      request.fields['nomor_wa'] = nomorWa;
      request.fields['lokasi'] = lokasi;

      if (foto != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
      }

      var response = await request.send();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error Upload Pasar: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> loginUser(String loginId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        body: {
          'login_id': loginId,
          'password': password,
        },
      );

      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_name', data['data']['name']);
        await prefs.setString('user_id', data['data']['id'].toString());

        await prefs.setString('foto_profil', data['data']['foto_profil'] ?? "");
        
        return {'success': true, 'message': 'Login Berhasil'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login Gagal'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>> registerUser(String name, String email, String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Accept': 'application/json',
        },
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        var data = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_name', data['data']['name']);
        await prefs.setString('user_id', data['data']['id'].toString());

        await prefs.setString('foto_profil', data['data']['foto_profil'] ?? "");
        
        return {'success': true, 'message': 'Pendaftaran Berhasil'};
      } 
      else if (response.statusCode == 422) {
        return {'success': false, 'message': 'Email atau Nomor HP sudah terdaftar. Mohon gunakan yang berbeda.'};
      } 
      else {
        return {'success': false, 'message': 'Gagal mendaftar. Pastikan data sudah benar.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan, periksa koneksi Anda.'};
    }
  }

// FUNGSI LOGIN GOOGLE (UPDATE VERSI 7.2+)
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      
      await googleSignIn.initialize(
        serverClientId: '525481370217-qpvpucpi0qbttmrf5knk34a86nqs9ips.apps.googleusercontent.com',
      );

      await googleSignIn.signOut();

      final googleUser = await googleSignIn.authenticate();

      final response = await http.post(
        Uri.parse('$baseUrl/google-login'),
        body: {
          'email': googleUser.email,
          'name': googleUser.displayName ?? 'Pengguna AQUARA',
          'google_id': googleUser.id,
        },
      );

      var data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_name', data['data']['name']); 
        
        await prefs.setString('user_id', data['data']['id'].toString());
        await prefs.setString('foto_profil', data['data']['foto_profil'] ?? "");
        
        return {'success': true, 'message': data['message'] ?? 'Login Berhasil'};
      } else {
        return {'success': false, 'message': 'Gagal sinkronisasi dengan server'};
      }
    } catch (e) {
      print("Error Google Sign In: $e");
      return {'success': false, 'message': 'Terjadi kesalahan sistem.'};
    }
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        return {'success': false, 'message': 'Anda belum login'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/ubah-password'), 
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json', 
        },
        body: {
          'old_password': oldPassword,
          'password': newPassword,
          'password_confirmation': newPassword, 
        },
      );

      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Kata sandi berhasil diubah!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal mengubah kata sandi. Pastikan sandi lama benar.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>> ubahKontak(String email, String phone) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return {'success': false, 'message': 'Anda belum login'};

      final response = await http.post(
        Uri.parse('$baseUrl/ubah-kontak'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: {
          'email': email,
          'phone': phone,
        },
      );

      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Kontak berhasil diperbarui!'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal memperbarui, Email/No HP mungkin sudah dipakai.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  Future<bool> hapusAkun() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/hapus-akun'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> updateProfile(String name, String fokusBudidaya, File? fotoProfil) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/profil/update'));
      
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = name;
      request.fields['fokus_budidaya'] = fokusBudidaya;

      if (fotoProfil != null) {
        request.files.add(await http.MultipartFile.fromPath('foto_profil', fotoProfil.path));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var data = json.decode(responseData);

      if (response.statusCode == 200) {
        await prefs.setString('user_name', name);
        
        if (data['data'] != null && data['data']['foto_profil'] != null) {
          await prefs.setString('foto_profil', data['data']['foto_profil']);
        }
        
        return {'success': true, 'message': 'Profil berhasil diperbarui'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal memperbarui profil'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print("Error fetch user profile: $e");
      return null;
    }
  }

  Future<bool> deletePasarItem(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/pasars/$id'), 
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print('Gagal menghapus jualan: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deletePasarItem: $e');
      return false;
    }
  }

  Future<bool> updatePasarItem({
    required int id,
    required String namaIkan,
    required String harga,
    required String deskripsi,
    required String nomorWa,
    required String lokasi,
    File? imageFile,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) return false;

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/pasars/$id/update'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields['nama_ikan'] = namaIkan;
      request.fields['harga'] = harga;
      request.fields['deskripsi'] = deskripsi;
      request.fields['nomor_wa'] = nomorWa;
      request.fields['lokasi'] = lokasi;

      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', imageFile.path));
      }

      var response = await request.send();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error updatePasarItem: $e");
      return false;
    }
  }

  // FUNGSI LOGIN WHATSAPP (OTP FONNTE)
  Future<Map<String, dynamic>> sendOtpWa(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp-wa'),
        body: {'phone': phone},
      );
      
      var data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal mengirim OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyOtpWa(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp-wa'),
        body: {
          'phone': phone,
          'otp': otp,
        },
      );
      
      var data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user_name', data['data']['name']);
        await prefs.setString('user_id', data['data']['id'].toString());
        await prefs.setString('foto_profil', data['data']['foto_profil'] ?? "");

        return {'success': true, 'message': 'Login WhatsApp Berhasil'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Kode OTP salah atau kadaluarsa'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }
}