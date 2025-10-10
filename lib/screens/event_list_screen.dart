// File: event_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';
import 'home_screen.dart'; // Màn hình chính
import 'package:flutter/foundation.dart'; // Thêm để dùng debugPrint

class EventListScreen extends StatelessWidget {
  final List<EventModel> events;

  const EventListScreen({super.key, required this.events});

  /// ✅ Hàm load hình ảnh Asset hoặc Network
  Widget _buildImageWidget(EventModel e, Color secondaryTextColor) {
    if (e.imageUrl == null || e.imageUrl!.trim().isEmpty) {
      return Icon(Icons.history_toggle_off,
          size: 40, color: secondaryTextColor);
    }

    String imageUrl = e.imageUrl!.replaceAll('\\', '/').trim();
    final bool isNetwork =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (isNetwork) {
      // Ảnh từ URL
      if (kDebugMode) debugPrint("🌐 Load ảnh từ mạng: $imageUrl");
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          if (kDebugMode) debugPrint("❌ Lỗi tải ảnh mạng: $imageUrl");
          return Icon(Icons.broken_image, size: 40, color: secondaryTextColor);
        },
      );
    } else {
      // ✅ Ảnh asset cục bộ
      String assetPath = imageUrl;

      // 🌟 FIX: thay dấu "-" bằng "_"
      assetPath = assetPath.replaceAll('-', '_');

      // 1. Nếu DB chỉ lưu tên file → thêm prefix
      if (!assetPath.startsWith('assets/')) {
        assetPath = 'assets/Image/$assetPath';
      }

      // 2. Danh sách các đường dẫn tiềm năng
      List<String> candidates = [];
      if (assetPath.endsWith(".png") || assetPath.endsWith(".jpg")) {
        candidates.add(assetPath);
      } else {
        candidates.add("$assetPath.png");
        candidates.add("$assetPath.jpg");
      }

      // 3. Load asset với fallback
      return _loadAssetWithFallback(candidates, secondaryTextColor);
    }
  }

  /// 🖼️ Hàm hỗ trợ load Asset với cơ chế Fallback
  Widget _loadAssetWithFallback(List<String> paths, Color secondaryTextColor) {
    if (paths.isEmpty) {
      return Icon(Icons.broken_image, size: 40, color: secondaryTextColor);
    }

    final String primaryPath = paths.first;
    final List<String> fallbackPaths = paths.skip(1).toList();

    return Image.asset(
      primaryPath,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) debugPrint("❌ Lỗi Asset: $primaryPath");
        if (fallbackPaths.isNotEmpty) {
          return _loadAssetWithFallback(fallbackPaths, secondaryTextColor);
        }
        return Icon(Icons.broken_image, size: 40, color: secondaryTextColor);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color cardColor = Colors.white;
    final Color textColor = Colors.black87;
    final Color secondaryTextColor = Colors.grey.shade600;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'DÒNG THỜI GIAN LỊCH SỬ',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        elevation: 1,
      ),

      // 🏠 Nút về Trang Chủ
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.home_outlined),
        tooltip: 'Về màn hình chính',
      ),

      // 📜 Danh sách sự kiện
      body: events.isEmpty
          ? Center(
        child: Text(
          '📭 Không có sự kiện nào trong danh sách.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: secondaryTextColor,
          ),
        ),
      )
          : ListView.builder(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];

          // 📅 Ngày tháng hiển thị
          final String dateStr = e.date != null
              ? DateFormat('dd/MM/yyyy').format(e.date!)
              : (e.year != null
              ? 'Năm: ${e.year}'
              : 'Ngày: Không rõ');

          // 📍 Vị trí hiển thị
          String locationInfo = '';
          if (e.locationName?.isNotEmpty ?? false) {
            locationInfo += e.locationName!;
          }
          if (e.region?.isNotEmpty ?? false) {
            locationInfo += locationInfo.isEmpty
                ? e.region!
                : ' - ${e.region!}';
          }

          // 📦 Card sự kiện
          return Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                  color: Colors.grey.shade300, width: 0.5),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (e.eventId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        eventId: e.eventId!,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🖼️ Ảnh sự kiện
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: _buildImageWidget(
                            e, secondaryTextColor),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 📝 Chi tiết sự kiện
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          // 🏷️ Tiêu đề
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // 📅 Ngày tháng
                          Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  child: Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                ),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: dateStr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 📍 Địa điểm
                          if (locationInfo.isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.only(top: 2),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    WidgetSpan(
                                      child: Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const TextSpan(text: ' '),
                                    TextSpan(
                                      text: locationInfo,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                        secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 📌 Biểu tượng bản đồ nếu có tọa độ
                    if (e.latitude != null && e.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.map,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
