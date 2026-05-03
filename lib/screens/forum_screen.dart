import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'profil_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _forumList;
  final ImagePicker _picker = ImagePicker();
  
  final String storageUrl = 'https://aquara.app/storage/';
  
  bool isGuest = true; 
  String currentUserId = ""; 
  String currentUserName = ""; 
  String currentUserFoto = "";

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); 
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      String? token = prefs.getString('token');
      isGuest = token == null; 
      if (!isGuest) {
        currentUserId = prefs.getString('user_id') ?? "";
        currentUserName = prefs.getString('user_name') ?? "Petani";
      }
    });
    _refreshForum(); 
    
    if (!isGuest && currentUserId.isNotEmpty) {
      final userData = await _apiService.getUserProfile(currentUserId);
      if (userData != null && mounted) {
        setState(() { currentUserFoto = userData['foto_profil'] ?? ""; });
      }
    }
  }

  void _refreshForum() {
    setState(() {
      _forumList = _apiService.fetchForumPosts(currentUserId);
    });
  }

  String timeAgo(String? dateString) {
    if (dateString == null) return "-";
    DateTime date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return "Baru saja";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}mnt";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}jam";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}hr";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  Future<void> _confirmDelete(int postId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Postingan?"),
          content: const Text("Anda yakin ingin menghapus postingan ini? Tindakan ini tidak dapat dibatalkan."),
          actions: [
            TextButton(child: const Text("Batal", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(context).pop(); 
                bool success = await _apiService.deleteForumPost(postId);
                if (success) {
                  _refreshForum();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Postingan dihapus.")));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> post) {
    TextEditingController contentController = TextEditingController(text: post['content']);
    File? newImageFile;
    String? oldImageUrl = post['image'] != null ? "https://aquara.app/storage/${post['image']}" : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Edit Postingan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Edit deskripsi...", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  
                  if (newImageFile != null)
                    _buildImagePreview(FileImage(newImageFile!), () => setModalState(() => newImageFile = null))
                  else if (oldImageUrl != null)
                    _buildImagePreview(NetworkImage(oldImageUrl), null), 

                  TextButton.icon(
                    onPressed: () async {
                      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) setModalState(() => newImageFile = File(picked.path));
                    },
                    icon: const Icon(Icons.image, color: Color(0xFF009FE3)),
                    label: Text(oldImageUrl == null && newImageFile == null ? "Tambahkan Foto" : "Ganti Foto"),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009FE3)),
                      onPressed: () {
                        Navigator.pop(context); 
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Simpan Perubahan?"),
                            content: const Text("Anda yakin ingin menyimpan perubahan pada postingan ini?"),
                            actions: [
                              TextButton(child: const Text("Batal"), onPressed: () => Navigator.pop(ctx)),
                              TextButton(
                                child: const Text("Ya, Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  bool success = await _apiService.updateForumPost(post['id'], contentController.text, newImageFile);
                                  if (success) _refreshForum();
                                },
                              ),
                            ],
                          )
                        );
                      },
                      child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }
  
  Widget _buildImagePreview(ImageProvider imageProvider, VoidCallback? onRemove) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: Image(image: imageProvider, height: 100, width: double.infinity, fit: BoxFit.cover)),
        if (onRemove != null) Positioned(right: 5, top: 5, child: GestureDetector(onTap: onRemove, child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 15, color: Colors.white)))),
      ],
    );
  }

  void _showCommentSheet(Map<String, dynamic> post) {
    TextEditingController commentController = TextEditingController();
    FocusNode commentFocusNode = FocusNode(); 
    String? replyToUser; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75, 
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text("Komentar", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: post['comments'].isEmpty
                        ? Center(child: Text("Belum ada komentar.", style: GoogleFonts.poppins(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(15),
                            itemCount: post['comments'].length,
                              itemBuilder: (context, index) {
                              final comment = post['comments'][index];
                              bool isMyComment = comment['author_name'] == currentUserName; 
                              
                              String fotoProfilKomen = '';
                              if (comment['user'] != null && comment['user']['foto_profil'] != null) {
                                fotoProfilKomen = storageUrl + comment['user']['foto_profil'].toString();
                              }

                              return InkWell(
                                onLongPress: (isMyComment && !isGuest) ? () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Komentar?"),
                                      actions: [
                                        TextButton(child: const Text("Batal"), onPressed: () => Navigator.pop(ctx)),
                                        TextButton(
                                          child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                          onPressed: () async {
                                            Navigator.pop(ctx);

                                            await _apiService.deleteComment(comment['id']);

                                            setSheetState(() {
                                              post['comments'].removeWhere((item) => item['id'] == comment['id']);
                                              
                                              if (post['comments_count'] != null && post['comments_count'] > 0) {
                                                post['comments_count'] = post['comments_count'] - 1;
                                              }
                                            });

                                            _refreshForum(); 

                                          },
                                        )
                                      ],
                                    ),
                                  );
                                } : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18, backgroundColor: Colors.grey[200], 
                                        child: fotoProfilKomen.isNotEmpty
                                          ? ClipOval(child: Image.network(fotoProfilKomen, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 20, color: Colors.grey)))
                                          : const Icon(Icons.person, size: 20, color: Colors.grey)
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    if (comment['user_id'] != null) {
                                                      Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilScreen(publicUserId: comment['user_id'].toString(), publicUserName: comment['author_name'])));
                                                    }
                                                  },
                                                  child: Text(comment['author_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline, color: const Color(0xFF009FE3))),
                                                ),
                                                const SizedBox(width: 5),
                                                Text("· ${timeAgo(comment['created_at'])}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                            Text(comment['content'], style: GoogleFonts.poppins(fontSize: 13)),
                                            if (!isGuest)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 5),
                                              child: GestureDetector(
                                                onTap: () {
                                                  setSheetState(() {
                                                    replyToUser = comment['author_name'];
                                                    commentController.text = "@$replyToUser ";
                                                  });
                                                  FocusScope.of(context).requestFocus(commentFocusNode);
                                                },
                                                child: Text("Balas", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (!isGuest)
                  Container(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 10, left: 15, right: 15, top: 10),
                    decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18, backgroundColor: Colors.grey[200], 
                          child: currentUserFoto.isNotEmpty
                              ? ClipOval(child: Image.network(storageUrl + currentUserFoto, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, size: 20, color: Colors.grey)))
                              : const Icon(Icons.person, size: 20, color: Colors.grey)
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            focusNode: commentFocusNode,
                            decoration: InputDecoration(
                              hintText: replyToUser != null ? "Balas @$replyToUser..." : "Tambahkan komentar...",
                              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            maxLines: null,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (commentController.text.isNotEmpty) {
                              String content = commentController.text;
                              commentController.clear();
                              FocusScope.of(context).unfocus(); 

                              await _apiService.storeComment(post['id'], currentUserName, content);

                              setSheetState(() {
                                replyToUser = null; 
                                
                                post['comments'].insert(0, { 
                                  'author_name': currentUserName,
                                  'content': content,
                                  'created_at': DateTime.now().toIso8601String(),
                                  'user': {
                                    'foto_profil': currentUserFoto,
                                  }
                                });
                                
                                post['comments_count'] = (post['comments_count'] ?? 0) + 1;
                              });

                              _refreshForum(); 
                              
                            }
                          },
                          child: Text("Kirim", style: GoogleFonts.poppins(color: const Color(0xFF009FE3), fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showCreatePostDialog() {
    if (isGuest) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silakan Login dulu!"))); return; }
    TextEditingController contentController = TextEditingController();
    File? selectedImage;
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Buat Topik Baru", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  TextField(controller: contentController, maxLines: 3, decoration: const InputDecoration(hintText: "Apa yang ingin didiskusikan?", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  if (selectedImage != null) _buildImagePreview(FileImage(selectedImage!), () => setModalState(() => selectedImage = null)),
                  TextButton.icon(
                    onPressed: () async { final XFile? picked = await _picker.pickImage(source: ImageSource.gallery); if (picked != null) setModalState(() => selectedImage = File(picked.path)); },
                    icon: const Icon(Icons.image, color: Color(0xFF009FE3)), label: const Text("Tambahkan Foto"),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009FE3)),
                      onPressed: () async {
                        if (contentController.text.isNotEmpty) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(child: CircularProgressIndicator()),
                          );
                          
                          bool success = await _apiService.postForum(
                            currentUserId, currentUserName, contentController.text, selectedImage
                          );
                          
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) Navigator.pop(context);
                          
                          if (success) {
                            _refreshForum();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Postingan berhasil dibuat!"), backgroundColor: Colors.green)
                              );
                            }
                          }
                        }
                      }
                      , child: const Text("Posting", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Forum Komunitas", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF009FE3), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: isGuest 
          ? null 
          : FloatingActionButton(onPressed: _showCreatePostDialog, backgroundColor: const Color(0xFF009FE3), child: const Icon(Icons.add, color: Colors.white)),
      body: FutureBuilder<List<dynamic>>(
        future: _forumList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("Belum ada diskusi.", style: GoogleFonts.poppins()));
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final post = snapshot.data![index];
              bool isMyPost = post['user_id'].toString() == currentUserId;
              bool isLikedByMe = post['is_liked_by_me'] ?? false; 
              
              String fotoProfilUserUrl = '';
              if (post['user'] != null && post['user']['foto_profil'] != null) {
                fotoProfilUserUrl = storageUrl + post['user']['foto_profil'].toString();
              }

              return Container(
                color: Colors.white, margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200], 
                        child: fotoProfilUserUrl.isNotEmpty
                          ? ClipOval(child: Image.network(fotoProfilUserUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.person, color: Colors.grey)))
                          : const Icon(Icons.person, color: Colors.grey)
                      ),
                      title: GestureDetector(
                        onTap: () {
                          if (post['user_id'] != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilScreen(publicUserId: post['user_id'].toString(), publicUserName: post['author_name'])));
                          }
                        },
                        child: Text(post['author_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline, color: const Color(0xFF009FE3))),
                      ),
                      subtitle: Row(
                                      children: [
                                        Text("Petani Budidaya", style: GoogleFonts.poppins(fontSize: 12)),
                                        Text(" · ${timeAgo(post['created_at'])}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                      trailing: (isMyPost && !isGuest) ? PopupMenuButton(
                        onSelected: (value) { if (value == 'edit') {
                          _showEditDialog(post);
                        } else if (value == 'delete') _confirmDelete(post['id']); },
                        itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text("Edit")), const PopupMenuItem(value: 'delete', child: Text("Hapus", style: TextStyle(color: Colors.red)))],
                      ) : null,
                    ),
                    
                    if (post['image'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 500,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10), 
                            child: Image.network(
                              "https://aquara.app/storage/${post['image']}", 
                              width: double.infinity,
                              fit: BoxFit.contain, 
                              errorBuilder: (ctx, err, stack) => Container(
                                height: 200, 
                                color: Colors.grey[200], 
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(post['content'], style: GoogleFonts.poppins(fontSize: 14)),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLikedByMe ? Icons.favorite : Icons.favorite_border,
                                  color: isLikedByMe ? Colors.red : Colors.black87,
                                  size: 26
                                ),
                                onPressed: isGuest ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silakan Login untuk menyukai!"))) : () async {
                                  setState(() {
                                    if (isLikedByMe) {
                                      post['likes_count']--; 
                                      post['is_liked_by_me'] = false; 
                                    } else {
                                      post['likes_count']++; 
                                      post['is_liked_by_me'] = true; 
                                    }
                                  });
                                  await _apiService.toggleLikePost(post['id'], currentUserId);
                                },
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87, size: 24),
                            onPressed: () => _showCommentSheet(post),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, color: Colors.black87, size: 24),
                            onPressed: () => Share.share('Cek diskusi ini dari ${post['author_name']}:\n\n"${post['content']}"'),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      child: Text("${post['likes_count']} suka · ${post['comments_count']} komentar", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}