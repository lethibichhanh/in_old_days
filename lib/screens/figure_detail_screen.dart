// lib/screens/figure_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // 🌟 CẦN THÊM DÒNG NÀY ĐỂ DÙNG rootBundle
import '../db/db_helper.dart';
import '../models/historical_figure.dart';
import 'event_detail_screen.dart';
import '../l10n/app_localizations.dart';

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


// 🌟 CHUYỂN SANG STATEFULWIDGET
class FigureDetailScreen extends StatefulWidget {
  final HistoricalFigure figure;
  final int? userId;

  const FigureDetailScreen({super.key, required this.figure, this.userId});

  @override
  State<FigureDetailScreen> createState() => _FigureDetailScreenState();
}

class _FigureDetailScreenState extends State<FigureDetailScreen> {

  // ================== LOGIC XỬ LÝ ẢNH (ASSET & NETWORK) ==================

  // Hàm tiện ích: Kiểm tra xem tệp asset có tồn tại hay không
  Future<String?> _tryLoadAsset(List<String> candidates) async {
    for (var path in candidates) {
      try {
        await rootBundle.load(path);
        return path;
      } catch (_) {}
    }
    return null;
  }

  // Hàm tiện ích: Xây dựng widget ảnh sự kiện, xử lý cả URL Mạng và Asset cục bộ
  Widget _buildEventImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      // Nếu không có URL ảnh, trả về Icon sự kiện mặc định
      return const Icon(Icons.event, size: 30, color: kPrimaryColor);
    }

    String path = imageUrl.replaceAll("\\", "/");
    final bool isNetwork = path.startsWith('http://') || path.startsWith('https://');

    // Kích thước cố định cho ListTile.leading
    const double size = 50;

    if (isNetwork) {
      // Tải ảnh MẠNG
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.image_not_supported, size: 30, color: kAccentColor), // Lỗi tải mạng
      );
    } else {
      // Tải ảnh ASSET (Cục bộ)
      String assetPath = path.replaceAll('-', '_');
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

      return FutureBuilder<String?>(
        future: _tryLoadAsset(candidates),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 2)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.asset(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 30, color: kAccentColor), // Lỗi tải asset
            );
          }
          return const Icon(Icons.image_not_supported, size: 30, color: kAccentColor); // Không tìm thấy asset
        },
      );
    }
  }

  // ================== HÀM BUILD ==================

  @override
  Widget build(BuildContext context) {
    // 🌟 TRUY CẬP figure VÀ userId THÔNG QUA widget.
    final figure = widget.figure;
    final userId = widget.userId;

    // ✅ TRUY CẬP LOCALIZATIONS
    final tr = AppLocalizations.of(context)!;

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH
    final noDescription = tr.translate('no_description');
    final eventRelated = tr.translate('figure_event_related');
    final errorLoadEvent = tr.translate('figure_error_load_event');
    final noRelatedEvent = tr.translate('figure_no_related_event');
    final noTitle = tr.translate('no_title');
    final dateformat = tr.locale.languageCode == 'vi' ? 'dd/MM/yyyy' : 'MM/dd/yyyy';

    // 🌟 XỬ LÝ CHUỖI lifeSpan: Tách ngày sinh và ngày mất, thay thế '-' bằng '/'
    String formattedLifeSpan = '';
    if (figure.lifeSpan.isNotEmpty) {
      // Tách chuỗi theo separator " - "
      final parts = figure.lifeSpan.split(' - ');

      final formattedParts = parts.map((part) {
        // Thay thế tất cả '-' trong mỗi phần (DD-MM-YYYY) bằng '/'
        return part.trim().replaceAll('-', '/');
      }).toList();

      // Nối lại các phần đã định dạng bằng separator " - "
      formattedLifeSpan = formattedParts.join(' - ');
    }
    // Chuỗi formattedLifeSpan sẽ là: "13/03/1884 - 04/04/1978"

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          figure.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kAppBarColor, // Màu Mint đậm
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ Ảnh nhân vật (Giữ nguyên logic)
            if (figure.imageUrl != null && figure.imageUrl!.isNotEmpty)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280), // Giới hạn chiều cao
                  decoration: BoxDecoration(
                    color: kCardColor, // Nền trắng cho ảnh contain
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      figure.imageUrl!,
                      // Chiều cao tự động điều chỉnh theo ảnh, tối đa 280
                      height: 280,
                      width: double.infinity,
                      fit: BoxFit.contain, // ✅ KHÔNG CẮT ẢNH
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 200,
                        child: Center(
                          child: Icon(Icons.broken_image, size: 50, color: kSubtextColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Tên nhân vật (Giữ nguyên)
            Text(
              figure.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: kTitleTextColor),
            ),
            const SizedBox(height: 8),

            // ✅ HIỂN THỊ: Ngày sinh - Ngày mất (Đã định dạng lại)
            if (formattedLifeSpan.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.calendar_month, size: 20, color: kPrimaryColor), // Icon Lịch/Tuổi thọ
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedLifeSpan, // HIỂN THỊ CẢ HAI NGÀY ĐÃ FORMAT: 13/03/1884 - 04/04/1978
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: kAccentColor, fontWeight: FontWeight.bold), // Màu Coral
                    ),
                  ),
                ],
              ),
            // ✅ Kết thúc phần hiển thị cải tiến
            const SizedBox(height: 20),

            // Mô tả
            Text(
              figure.description ?? noDescription, // ✅ Dịch: 'Không có mô tả chi tiết.'
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTitleTextColor),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 30),

            // Sự kiện liên quan
            FutureBuilder<List<Map<String, dynamic>>>(
              // GỌI HÀM DB LẤY SỰ KIỆN THEO ID NHÂN VẬT (Đã được cập nhật để loại bỏ trùng lặp)
              future: DBHelper.getEventsByFigureId(figure.figureId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                } else if (snapshot.hasError) {
                  return Text('$errorLoadEvent: ${snapshot.error}', style: const TextStyle(color: Colors.red)); // ✅ Dịch lỗi tải
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(noRelatedEvent, style: TextStyle(color: kSubtextColor)); // ✅ Dịch: 'Không có sự kiện liên quan.'
                }

                final events = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Tiêu đề sử dụng số lượng sự kiện ĐÃ LỌC DUY NHẤT
                      '$eventRelated (${events.length}):', // ✅ Dịch: '🗓 Sự kiện liên quan'
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAppBarColor),
                    ),
                    const SizedBox(height: 12),

                    ...events.map((event) {
                      DateTime? eventDate;
                      // 🌟 LOGIC XỬ LÝ NGÀY THÁNG ĐÃ ĐƯỢC CẬP NHẬT Ở PHẢN HỒI TRƯỚC (Giữ nguyên)
                      final dateStr = event['date']?.toString().trim() ?? '';

                      if (dateStr.isNotEmpty) {
                        eventDate = DateTime.tryParse(dateStr);

                        if (eventDate == null) {
                          if (dateStr.length == 4) { // Chỉ có YYYY
                            eventDate = DateTime.tryParse('$dateStr-01-01');
                          } else if (dateStr.length >= 6 && dateStr.length <= 7 && dateStr.contains('-')) {
                            try {
                              List<String> parts = dateStr.split('-');
                              if (parts.length == 2) {
                                String year = parts[0];
                                String month = parts[1].padLeft(2, '0');
                                eventDate = DateTime.tryParse('$year-$month-01');
                              }
                            } catch (_) {
                              // Bỏ qua lỗi tách chuỗi
                            }
                          }
                        }
                      }
                      // -------------------------------------------------------------

                      return Card(
                        color: kCardColor,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 4,
                        shadowColor: kPrimaryColor.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: kPrimaryColor.withOpacity(0.1), width: 1),
                        ),
                        child: ListTile(

                          // 🌟 KHỐI LEADING ĐÃ ĐƯỢC CẬP NHẬT
                          leading: SizedBox(
                            width: 50,
                            height: 50,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              // Gọi hàm mới đã xử lý cả Mạng và Asset
                              child: _buildEventImageWidget(event['image_url']),
                            ),
                          ),

                          title: Text(
                            event['title'] ?? noTitle, // ✅ Dịch: 'Không có tiêu đề'
                            style: const TextStyle(fontWeight: FontWeight.w700, color: kTitleTextColor),
                          ),
                          subtitle: Text(
                            // Sử dụng định dạng ngày theo ngôn ngữ
                            (eventDate != null && eventDate.year > 0)
                                ? DateFormat(dateformat).format(eventDate)
                                : event['year']?.toString() ?? '',
                            style: const TextStyle(color: kSubtextColor),
                          ),
                          trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16, color: kAccentColor), // Icon Coral
                          onTap: () {
                            final eventId = event['event_id'] as int?; // Lấy ID
                            if (eventId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(
                                    eventId: eventId, // TRUYỀN ID VÀO
                                    userId: userId, // ✅ TRUYỀN userId
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}