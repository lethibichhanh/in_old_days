// File: event_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';
import 'home_screen.dart';
import 'package:flutter/foundation.dart';
import '../l10n/app_localizations.dart'; // ✅ THÊM IMPORT NGÔN NGỮ

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


class EventListScreen extends StatelessWidget {
  final List<EventModel> events;
  // ✅ THÊM userId VÀO CONSTRUCTOR (để truyền vào EventDetailScreen)
  final int? userId;

  const EventListScreen({
    super.key,
    required this.events,
    this.userId, // Nhận userId
  });

  /// ✅ Hàm load hình ảnh Asset hoặc Network (Giữ nguyên)
  Widget _buildImageWidget(EventModel e, Color secondaryTextColor) {
    if (e.imageUrl == null || e.imageUrl!.trim().isEmpty) {
      return Icon(Icons.history_toggle_off,
          size: 40, color: kPrimaryColor);
    }

    String imageUrl = e.imageUrl!.replaceAll('\\', '/').trim();
    final bool isNetwork =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    if (isNetwork) {
      if (kDebugMode) debugPrint("🌐 Load ảnh từ mạng: $imageUrl");
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          if (kDebugMode) debugPrint("❌ Lỗi tải ảnh mạng: $imageUrl");
          return Icon(Icons.broken_image, size: 40, color: kPrimaryColor);
        },
      );
    } else {
      String assetPath = imageUrl;
      assetPath = assetPath.replaceAll('-', '_');

      if (!assetPath.startsWith('assets/')) {
        assetPath = 'assets/Image/$assetPath';
      }

      List<String> candidates = [];
      if (assetPath.endsWith(".png") || assetPath.endsWith(".jpg")) {
        candidates.add(assetPath);
      } else {
        candidates.add("$assetPath.png");
        candidates.add("$assetPath.jpg");
      }

      return _loadAssetWithFallback(candidates, secondaryTextColor);
    }
  }

  /// 🖼️ Hàm hỗ trợ load Asset với cơ chế Fallback (Giữ nguyên)
  Widget _loadAssetWithFallback(List<String> paths, Color secondaryTextColor) {
    if (paths.isEmpty) {
      return Icon(Icons.broken_image, size: 40, color: kPrimaryColor);
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
        return Icon(Icons.broken_image, size: 40, color: kPrimaryColor);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GỌI APP LOCALIZATIONS
    final tr = AppLocalizations.of(context)!;

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH
    final appBarTitle = tr.translate('timeline_title');
    final noEventFound = tr.translate('list_no_event_found');
    final yearPrefix = tr.translate('year_prefix_long_no_icon');
    final datePrefix = tr.translate('date_prefix_long_no_icon');
    final dateUnknown = tr.translate('date_unknown');
    final homeTooltip = tr.translate('home_tooltip');


    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          appBarTitle, // ✅ Dịch: 'DÒNG THỜI GIAN LỊCH SỬ'
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: kAppBarColor,
        elevation: 0,
      ),

      // 🏠 Nút về Trang Chủ
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        backgroundColor: kAccentColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.home_outlined),
        tooltip: homeTooltip, // ✅ Dịch: 'Về màn hình chính'
      ),

      // 📜 Danh sách sự kiện
      body: events.isEmpty
          ? Center(
        child: Text(
          noEventFound, // ✅ Dịch: '📭 Không có sự kiện nào trong danh sách.'
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: kSubtextColor,
          ),
        ),
      )
          : ListView.builder(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];

          // 📅 Ngày tháng hiển thị
          final String dateStr = e.date != null
              ? DateFormat('dd/MM/yyyy').format(e.date!)
              : (e.year != null
              ? '$yearPrefix: ${e.year}' // ✅ Dịch tiền tố Năm
              : '$datePrefix: $dateUnknown'); // ✅ Dịch tiền tố Ngày + Không rõ

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
            color: kCardColor,
            elevation: 4,
            shadowColor: kPrimaryColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: kPrimaryColor.withOpacity(0.2), width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 15),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (e.eventId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        eventId: e.eventId!,
                        userId: userId, // ✅ TRUYỀN userId
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🖼️ Ảnh sự kiện
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: kPrimaryColor.withOpacity(0.1),
                        child: _buildImageWidget(
                            e, kPrimaryColor),
                      ),
                    ),
                    const SizedBox(width: 15),

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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kTitleTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // 📅 Ngày tháng
                          Text.rich(
                            TextSpan(
                              children: [
                                const WidgetSpan(
                                  child: Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: kPrimaryColor, // Icon Mint
                                  ),
                                ),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: dateStr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: kSubtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 📍 Địa điểm
                          if (locationInfo.isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets.only(top: 4),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const WidgetSpan(
                                      child: Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: kPrimaryColor, // Icon Mint
                                      ),
                                    ),
                                    const TextSpan(text: ' '),
                                    TextSpan(
                                      text: locationInfo,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kSubtextColor,
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
                          color: kAccentColor, // Icon Coral
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