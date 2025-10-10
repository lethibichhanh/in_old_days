import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/event.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter/services.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventModel? _event;
  bool _loading = true;
  bool _isFavorite = false;
  maplibre.MaplibreMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  /// 📦 Lấy dữ liệu sự kiện + kiểm tra yêu thích
  Future<void> _loadEvent() async {
    try {
      final e = await DBHelper.getEventById(widget.eventId);
      final isFav = await DBHelper.isFavorite(widget.eventId);
      setState(() {
        _event = e != null ? EventModel.fromMap(e) : null;
        _isFavorite = isFav;
        _loading = false;
      });
    } catch (e) {
      debugPrint("❌ Lỗi load event: $e");
      setState(() => _loading = false);
    }
  }

  /// ❤️ Thêm / xoá yêu thích
  Future<void> _toggleFavorite() async {
    if (_event == null) return;

    try {
      if (_isFavorite) {
        await DBHelper.removeFavorite(widget.eventId, userId: 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("💔 Đã xoá khỏi danh sách yêu thích")),
        );
      } else {
        await DBHelper.addFavorite(widget.eventId, userId: 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❤️ Đã thêm vào danh sách yêu thích")),
        );
      }
      setState(() => _isFavorite = !_isFavorite);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Lỗi khi cập nhật yêu thích: $e")),
      );
    }
  }

  /// 🖼️ Hiển thị hình ảnh
  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
      );
    }

    String path = imageUrl.replaceAll("\\", "/");
    final bool isNetwork = path.startsWith('http://') || path.startsWith('https://');

    if (isNetwork) {
      return Image.network(
        path,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
        ),
      );
    } else {
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.asset(
              snapshot.data!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            );
          }
          return const Center(
            child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
          );
        },
      );
    }
  }

  Future<String?> _tryLoadAsset(List<String> candidates) async {
    for (var path in candidates) {
      try {
        await rootBundle.load(path);
        debugPrint("✅ Tìm thấy asset: $path");
        return path;
      } catch (_) {}
    }
    return null;
  }

  /// 🗺️ Hiển thị bản đồ
  Widget _buildMapWidget() {
    if (_event?.latitude == null || _event?.longitude == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 300,
      child: maplibre.MaplibreMap(
        styleString: 'https://demotiles.maplibre.org/style.json',
        initialCameraPosition: maplibre.CameraPosition(
          target: maplibre.LatLng(_event!.latitude!, _event!.longitude!),
          zoom: 6.0,
        ),
        myLocationEnabled: false,
        compassEnabled: false,
        onMapCreated: (controller) async {
          _mapController = controller;
          await _mapController!.addSymbol(
            maplibre.SymbolOptions(
              geometry: maplibre.LatLng(_event!.latitude!, _event!.longitude!),
              textField: _event!.title ?? 'Sự kiện',
              textSize: 12.0,
              textOffset: const Offset(0, 1.5),
              iconImage: "marker-15",
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sự kiện'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(_isFavorite),
                color: _isFavorite ? Colors.red : Colors.white,
              ),
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_event == null)
          ? const Center(
        child: Text(
          '❌ Sự kiện không tồn tại hoặc đã bị xóa.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎯 Tiêu đề
            Text(
              _event!.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 📅 Thời gian
            Text(
              _event!.date != null
                  ? '📆 Ngày: ${DateFormat('dd/MM/yyyy').format(_event!.date!)}'
                  : (_event!.year != null
                  ? '📆 Năm: ${_event!.year}'
                  : '📆 Ngày: Không rõ'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 🖼️ Ảnh
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: _buildImageWidget(_event!.imageUrl),
              ),
            ),
            const SizedBox(height: 16),

            // 📖 Mô tả
            if ((_event!.description ?? '').isNotEmpty)
              Text(
                _event!.description!,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            const SizedBox(height: 16),

            // 📚 Nguồn
            if ((_event!.source ?? '').isNotEmpty)
              Text(
                '📚 Nguồn: ${_event!.source}',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),

            // 🗺️ Bản đồ
            if (_event!.latitude != null && _event!.longitude != null) ...[
              const Text(
                "🗺️ Vị trí sự kiện:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              _buildMapWidget(),
              const SizedBox(height: 16),
            ],

            // 📍 Địa điểm
            if ((_event!.locationName?.isNotEmpty ?? false))
              Text(
                '📍 Địa điểm: ${_event!.locationName}',
                style: const TextStyle(fontSize: 16),
              ),
            if ((_event!.region?.isNotEmpty ?? false))
              Text(
                '🌍 Khu vực: ${_event!.region}',
                style: const TextStyle(fontSize: 16),
              ),

            const SizedBox(height: 32),

            // ❤️ Nút lưu sự kiện yêu thích
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFavorite ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                label: Text(
                  _isFavorite
                      ? 'Đã lưu vào yêu thích'
                      : 'Lưu lại sự kiện yêu thích',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
