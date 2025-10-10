// lib/screens/figure_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/historical_figure.dart';
import 'event_detail_screen.dart';

class FigureDetailScreen extends StatelessWidget {
  final HistoricalFigure figure;

  const FigureDetailScreen({super.key, required this.figure});

  @override
  Widget build(BuildContext context) {
    // ⚠️ CHÚ Ý: Logic xử lý figure đã được chuyển sang router hoặc màn hình gọi.
    // Nếu bạn đang dùng code này, bạn PHẢI đảm bảo HistoricalFigure đã được truyền vào
    // constructor một cách hợp lệ, không thông qua ModalRoute như code cũ bị lỗi.

    return Scaffold(
      appBar: AppBar(
        title: Text(figure.name),
        backgroundColor: Colors.brown.shade300,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh nhân vật
            if (figure.imageUrl != null && figure.imageUrl!.isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    figure.imageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 220,
                      child: Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Tên nhân vật
            Text(
              figure.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Ngày sinh – ngày mất
            Text(
              figure.lifeSpan,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // Mô tả
            Text(
              figure.description ?? 'Không có mô tả chi tiết.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),

            // Sự kiện liên quan
            FutureBuilder<List<Map<String, dynamic>>>(
              // GỌI HÀM DB LẤY SỰ KIỆN THEO ID NHÂN VẬT
              future: DBHelper.getEventsByFigureId(figure.figureId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Lỗi tải sự kiện: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // DÒNG NÀY SẼ HIỆN NẾU BẢNG 'event_figures' TRONG DB RỖNG
                  return const Text('Không có sự kiện liên quan.');
                }

                final events = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🗓 Sự kiện liên quan:',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

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
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: event['image_url'] != null &&
                              event['image_url'].isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              event['image_url'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                            ),
                          )
                              : const Icon(Icons.event, size: 40),
                          title: Text(
                            event['title'] ?? 'Không có tiêu đề',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            // Hiển thị ngày tháng đầy đủ nếu có, nếu không thì hiển thị năm
                            (eventDate != null && eventDate.year > 0)
                                ? DateFormat('dd/MM/yyyy').format(eventDate)
                                : event['year']?.toString() ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing:
                          const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            final eventId = event['event_id'] as int?; // Lấy ID
                            if (eventId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(
                                    eventId: eventId, // TRUYỀN ID VÀO
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