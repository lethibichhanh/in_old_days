import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'event_detail_screen.dart';

// --- Màu Pastel đồng bộ ---
const Color kPrimaryColor = Color(0xFF81C784);
const Color kAppBarColor = Color(0xFF4DB6AC);
const Color kAccentColor = Color(0xFFFFAB91);
const Color kBackgroundColor = Color(0xFFF9F9F9);
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242);
const Color kSubtextColor = Color(0xFF9E9E9E);

class FavoriteScreen extends StatefulWidget {
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
    if (widget.userId != null) {
      _loadFavorites();
    } else {
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
    if (widget.userId == null) return;

    try {
      await DBHelper.removeFavorite(eventId, userId: widget.userId!);
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("💔 Đã xóa khỏi danh sách yêu thích"),
            backgroundColor: kAccentColor,
          ),
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

  /// 🖼️ Hiển thị hình ảnh sự kiện
  Widget _buildImage(String? imageUrl) {
    const double size = 60;
    const double radius = 8;
    const iconSize = 30.0;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Icon(Icons.image_not_supported,
            size: iconSize, color: kPrimaryColor),
      );
    }

    ImageProvider? imageProvider;
    bool isNetwork = imageUrl.startsWith('http');
    String fixedPath = imageUrl.replaceAll('\\', '/');

    if (!isNetwork) {
      if (!fixedPath.startsWith('assets/')) {
        fixedPath = 'assets/Image/$fixedPath';
      }
      imageProvider = AssetImage(fixedPath);
    } else {
      imageProvider = NetworkImage(imageUrl);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image(
        image: imageProvider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: kPrimaryColor.withOpacity(0.1),
          child: const Icon(Icons.broken_image,
              size: iconSize, color: kPrimaryColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null && !_loading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          title: const Text(
            "❤️ Sự kiện yêu thích",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: kAppBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Vui lòng đăng nhập để xem danh sách sự kiện yêu thích.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: kAccentColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          " Sự kiện yêu thích",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : _favorites.isEmpty
          ? Center(
        child: Text(
          "Chưa có sự kiện yêu thích nào!",
          style:
          TextStyle(fontSize: 16, color: kSubtextColor),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadFavorites,
        color: kAppBarColor,
        child: ListView.builder(
          itemCount: _favorites.length,
          itemBuilder: (context, index) {
            final e = _favorites[index];
            final int eventId = e['id'] ?? e['event_id'] ?? 0;
            final String title =
                e['title'] ?? "Không có tiêu đề";
            final String? date = e['date'];
            final String? imgPath =
                e['imageUrl'] ?? e['image_url'];

            // ✅ Định dạng ngày kiểu Việt Nam
            String displayDate = "";
            if (date != null && date.isNotEmpty) {
              try {
                final d = DateTime.parse(date);
                displayDate =
                "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
              } catch (_) {
                displayDate = date;
              }
            }

            return Card(
              color: kCardColor,
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: kPrimaryColor.withOpacity(0.3),
                    width: 1),
              ),
              elevation: 4,
              shadowColor: kPrimaryColor.withOpacity(0.2),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: _buildImage(imgPath),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kTitleTextColor,
                  ),
                ),
                subtitle: Text(
                  displayDate,
                  style: const TextStyle(color: kSubtextColor),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite,
                      color: kAccentColor),
                  onPressed: () => _removeFavorite(eventId),
                ),

                // ✅ Cập nhật phần mở chi tiết sự kiện
                onTap: () async {
                  if (widget.userId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "⚠️ Vui lòng đăng nhập để xem chi tiết."),
                      ),
                    );
                    return;
                  }

                  final bool? result = await Navigator.push<bool?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        eventId: eventId,
                        userId: widget.userId!, // truyền userId
                      ),
                    ),
                  );

                  // Nếu người dùng bỏ yêu thích trong trang chi tiết => cập nhật lại danh sách
                  if (result == false) {
                    await _loadFavorites();
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
