import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/historical_figure.dart';
import 'figure_detail_screen.dart';

class FiguresListScreen extends StatefulWidget {
  const FiguresListScreen({super.key});

  @override
  State<FiguresListScreen> createState() => _FiguresListScreenState();
}

class _FiguresListScreenState extends State<FiguresListScreen> {
  // Kiểu dữ liệu đã khớp với DBHelper.getAllFigures()
  late Future<List<HistoricalFigure>> _futureFigures;

  @override
  void initState() {
    super.initState();
    // Gọi hàm đã sửa lỗi và trả về đúng kiểu dữ liệu
    _futureFigures = DBHelper.getAllFigures();
  }

  // Hàm refresh danh sách nhân vật
  Future<void> _refreshFigures() async {
    setState(() {
      _futureFigures = DBHelper.getAllFigures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📜 Nhân vật lịch sử')),
      body: FutureBuilder<List<HistoricalFigure>>(
        future: _futureFigures,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('❌ Lỗi: ${snapshot.error}'),
              ),
            );
          }

          final figures = snapshot.data ?? [];
          if (figures.isEmpty) {
            return const Center(child: Text('⚠️ Không có nhân vật nào trong cơ sở dữ liệu.'));
          }

          return RefreshIndicator(
            onRefresh: _refreshFigures,
            child: ListView.builder(
              itemCount: figures.length,
              itemBuilder: (context, index) {
                final figure = figures[index];

                // Sử dụng thuộc tính 'description' của model
                final description = (figure.description ?? 'Đang cập nhật tiểu sử.').trim();
                final shortDesc = description.length > 60
                    ? '${description.substring(0, 60)}...'
                    : description;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundImage: (figure.imageUrl != null && figure.imageUrl!.isNotEmpty)
                          ? NetworkImage(figure.imageUrl!)
                          : null,
                      child: (figure.imageUrl == null || figure.imageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 28)
                          : null,
                    ),
                    title: Text(
                      figure.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(shortDesc),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FigureDetailScreen(figure: figure),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}