// lib/screens/figure_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/historical_figure.dart';
import 'event_detail_screen.dart';
import '../l10n/app_localizations.dart'; // ✅ THÊM IMPORT NGÔN NGỮ

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


class FigureDetailScreen extends StatelessWidget {
  final HistoricalFigure figure;
  // ✅ THÊM userId ĐỂ TRUYỀN XUỐNG EventDetailScreen (Nếu cần, đảm bảo tính nhất quán)
  final int? userId;

  const FigureDetailScreen({super.key, required this.figure, this.userId});

  @override
  Widget build(BuildContext context) {
    // ✅ TRUY CẬP LOCALIZATIONS
    final tr = AppLocalizations.of(context)!;

    // ✅ KHAI BÁO CÁC CHUỖI DỊCH
    final noDescription = tr.translate('no_description');
    final eventRelated = tr.translate('figure_event_related');
    final errorLoadEvent = tr.translate('figure_error_load_event');
    final noRelatedEvent = tr.translate('figure_no_related_event');
    final noTitle = tr.translate('no_title');
    final dateformat = tr.locale.languageCode == 'vi' ? 'dd/MM/yyyy' : 'MM/dd/yyyy';

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

            // Ngày sinh – ngày mất (Giữ nguyên)
            Text(
              figure.lifeSpan,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: kAccentColor, fontWeight: FontWeight.bold), // Màu Coral
            ),
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
              // GỌI HÀM DB LẤY SỰ KIỆN THEO ID NHÂN VẬT
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
                      '$eventRelated (${events.length}):', // ✅ Dịch: '🗓 Sự kiện liên quan'
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kAppBarColor),
                    ),
                    const SizedBox(height: 12),

                    ...events.map((event) {
                      DateTime? eventDate;
                      if (event['date'] != null &&
                          event['date'].toString().isNotEmpty) {
                        // Thêm logic xử lý ngày không hợp lệ (ví dụ: chỉ có năm)
                        eventDate = DateTime.tryParse(event['date'].toString().length < 10 ?
                        '${event['date'].toString().padRight(10, '0').substring(0, 4)}-01-01' :
                        event['date'].toString());
                      }

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
                          leading: event['image_url'] != null &&
                              event['image_url'].isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              event['image_url'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, color: kPrimaryColor),
                            ),
                          )
                              : const Icon(Icons.event, size: 30, color: kPrimaryColor), // Icon Mint
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
            ),
          ],
        ),
      ),
    );
  }
}