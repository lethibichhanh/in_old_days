// lib/screens/figures_list_screen.dart

import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/historical_figure.dart';
import 'figure_detail_screen.dart';
import '../l10n/app_localizations.dart'; // ✅ THÊM IMPORT NGÔN NGỮ

// --- Khai báo màu sắc Pastel Tươi sáng (Đồng bộ) ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ


class FiguresListScreen extends StatefulWidget {
  // ✅ THÊM userId (Nếu bạn muốn truyền nó xuống DetailScreen)
  final int? userId;
  const FiguresListScreen({super.key, this.userId});

  @override
  State<FiguresListScreen> createState() => _FiguresListScreenState();
}

class _FiguresListScreenState extends State<FiguresListScreen> {
  late Future<List<HistoricalFigure>> _futureFigures;
  late AppLocalizations tr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tr = AppLocalizations.of(context)!;
  }

  @override
  void initState() {
    super.initState();
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
    // ✅ KHAI BÁO CÁC CHUỖI DỊCH
    final figuresTitle = tr.translate('figures_title');
    final loadingError = tr.translate('figures_error_loading'); // Khóa mới
    final figuresNoFound = tr.translate('figures_no_found');
    final figuresDefaultDesc = tr.translate('figures_default_desc'); // Khóa mới

    return Scaffold(
      backgroundColor: kBackgroundColor, // Nền Pastel
      appBar: AppBar(
        title: Text(
          figuresTitle, // ✅ Dịch tiêu đề
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kAppBarColor, // Màu Mint đậm
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<HistoricalFigure>>(
        future: _futureFigures,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '$loadingError: ${snapshot.error}', // ✅ Dịch lỗi
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final figures = snapshot.data ?? [];
          if (figures.isEmpty) {
            return Center(
              child: Text(
                figuresNoFound, // ✅ Dịch thông báo rỗng
                style: TextStyle(color: kSubtextColor, fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFigures,
            color: kAppBarColor, // Màu Mint cho loading indicator
            child: ListView.builder(
              itemCount: figures.length,
              itemBuilder: (context, index) {
                final figure = figures[index];

                final description = (figure.description ?? figuresDefaultDesc).trim(); // ✅ Dịch mô tả mặc định
                final shortDesc = description.length > 60
                    ? '${description.substring(0, 60)}...'
                    : description;

                return Card(
                  color: kCardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: kPrimaryColor.withOpacity(0.3), width: 1),
                  ),
                  elevation: 4,
                  shadowColor: kPrimaryColor.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (figure.imageUrl != null && figure.imageUrl!.isNotEmpty)
                            ? Image.network(
                          figure.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person, size: 30, color: kAppBarColor),
                        )
                            : const Icon(Icons.person, size: 30, color: kAppBarColor), // Icon màu Mint
                      ),
                    ),
                    title: Text(
                      figure.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kTitleTextColor),
                    ),
                    subtitle: Text(
                      shortDesc,
                      style: const TextStyle(color: kSubtextColor),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kPrimaryColor), // Icon màu Mint
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FigureDetailScreen(
                            figure: figure,
                            userId: widget.userId, // Truyền userId (nếu có)
                          ),
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