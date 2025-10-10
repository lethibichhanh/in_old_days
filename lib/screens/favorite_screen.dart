import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'event_detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  // ✅ THÊM userId VÀO CONSTRUCTOR
  final int? userId;
  const FavoriteScreen({super.key, this.userId});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ⚠️ Chỉ tải favorites nếu có userId hợp lệ
    if (widget.userId != null) {
      _loadFavorites();
    } else {
      // Nếu không có userId (chưa đăng nhập), dừng loading
      _loading = false;
    }
  }

  /// 🔄 Load danh sách yêu thích
  Future<void> _loadFavorites() async {
    if (widget.userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // ✅ SỬ DỤNG THAM SỐ CÓ TÊN ĐÃ SỬA:
      final data = await DBHelper.getFavoriteEvents(userId: widget.userId!);
      if (mounted) {
        setState(() {
          _favorites = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi load favorites: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 💔 Xóa khỏi danh sách yêu thích
  Future<void> _removeFavorite(int eventId) async {
    // Đảm bảo có userId trước khi xóa
    if (widget.userId == null) return;

    try {
      // ✅ SỬ DỤNG userId ĐƯỢC TRUYỀN VÀO (thay vì mã hóa cứng 1)
      await DBHelper.removeFavorite(eventId, userId: widget.userId!);
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("💔 Đã xóa khỏi danh sách yêu thích")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Lỗi khi xóa yêu thích: $e")),
        );
      }
    }
  }

  /// 🖼️ Xử lý hiển thị ảnh
  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 50, color: Colors.grey);
    }

    // Nếu là ảnh online
    if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
        ),
      );
    }

    // Nếu là ảnh local (assets)
    String fixedPath = imageUrl.replaceAll('\\', '/');
    if (!fixedPath.startsWith('assets/')) {
      fixedPath = 'assets/Image/$fixedPath';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        fixedPath,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Xử lý trường hợp không có User ID (chưa đăng nhập)
    if (widget.userId == null && !_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("❤️ Sự kiện yêu thích")),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Vui lòng đăng nhập để xem danh sách sự kiện yêu thích.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("❤️ Sự kiện yêu thích"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? const Center(
        child: Text(
          "Chưa có sự kiện yêu thích nào!",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView.builder(
          itemCount: _favorites.length,
          itemBuilder: (context, index) {
            final e = _favorites[index];
            final int eventId = e['id'] ?? e['event_id'] ?? 0;
            final String title = e['title'] ?? "Không có tiêu đề";
            final String? date = e['date'];
            final String? imgPath = e['imageUrl'] ?? e['image_url'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: _buildImage(imgPath),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  date ?? "",
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _removeFavorite(eventId),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventId: eventId),
                    ),
                  );
                  _loadFavorites(); // Cập nhật lại khi quay về
                },
              ),
            );
          },
        ),
      ),
    );
  }
}