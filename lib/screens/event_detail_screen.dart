// File: event_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/db_helper.dart';
import '../models/event.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

// --- Màu Pastel đồng bộ ---
const Color kPrimaryColor = Color(0xFF81C784);
const Color kAppBarColor = Color(0xFF4DB6AC);
const Color kAccentColor = Color(0xFFFFAB91);
const Color kBackgroundColor = Color(0xFFF9F9F9);
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242);
const Color kSubtextColor = Color(0xFF9E9E9E);

class EventDetailScreen extends StatefulWidget {
  final int eventId;
  final int? userId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.userId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventModel? _event;
  bool _loading = true;
  bool _isFavorite = false;
  maplibre.MaplibreMapController? _mapController;

  String _getText(String key) {
    return AppLocalizations.of(context)?.translate(key) ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cập nhật lại trạng thái yêu thích nếu có thay đổi bên ngoài
    _refreshFavoriteStatus();
  }

  Future<void> _refreshFavoriteStatus() async {
    if (widget.userId != null) {
      bool isFav = await DBHelper.isFavorite(widget.eventId, userId: widget.userId!);
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    }
  }

  @override
  void dispose() {
    _mapController?.onSymbolTapped.clear();
    _mapController = null;
    super.dispose();
  }

  Future<void> _loadEvent() async {
    try {
      final e = await DBHelper.getEventById(widget.eventId);
      bool isFav = false;
      if (widget.userId != null) {
        isFav = await DBHelper.isFavorite(widget.eventId, userId: widget.userId!);
      }
      if (mounted) {
        setState(() {
          _event = e != null ? EventModel.fromMap(e) : null;
          _isFavorite = isFav;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi load event: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ❤️ Thêm / Xoá yêu thích
  Future<void> _toggleFavorite() async {
    if (_event == null) return;
    final tr = AppLocalizations.of(context)!;

    try {
      if (_isFavorite) {
        await DBHelper.removeFavorite(widget.eventId, userId: widget.userId ?? 0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.translate('favorite_removed'))),
          );
        }
      } else {
        await DBHelper.addFavorite(widget.eventId, userId: widget.userId ?? 0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.translate('favorite_added'))),
          );
        }
      }
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.translate('favorite_error'))),
        );
      }
    }
  }

  /// 🖼️ Hiển thị hình ảnh
  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(Icons.image_not_supported, size: 80, color: kSubtextColor),
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
        errorBuilder: (_, __, ___) =>
            Center(child: Icon(Icons.broken_image, size: 80, color: kSubtextColor)),
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
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.asset(
              snapshot.data!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Center(child: Icon(Icons.broken_image, size: 80, color: kSubtextColor)),
            );
          }
          return Center(child: Icon(Icons.broken_image, size: 80, color: kSubtextColor));
        },
      );
    }
  }

  Future<String?> _tryLoadAsset(List<String> candidates) async {
    for (var path in candidates) {
      try {
        await rootBundle.load(path);
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

    return Card(
      elevation: 6,
      shadowColor: kPrimaryColor.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
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
                  textField: _event!.title ?? _getText('event_default_name'),
                  textSize: 12.0,
                  textColor: kTitleTextColor.toHexString(),
                  textHaloColor: kCardColor.toHexString(),
                  textHaloWidth: 1.0,
                  textOffset: const Offset(0, 1.5),
                  iconImage: "marker-15",
                  iconAnchor: 'bottom',
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(tr.translate('detail_title'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _isFavorite),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(_isFavorite),
                color: _isFavorite ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : (_event == null)
          ? Center(
        child: Text(
          tr.translate('event_not_exist'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: kTitleTextColor),
        ),
      )
          : _buildDetailBody(tr),
    );
  }

  Widget _buildDetailBody(AppLocalizations tr) {
    final datePrefix = tr.translate('date_prefix_long');
    final yearPrefix = tr.translate('year_prefix_long');
    final dateUnknown = tr.translate('date_unknown');
    final sourcePrefix = tr.translate('source_prefix');
    final mapLocation = tr.translate('map_location');
    final locationName = tr.translate('location_name');
    final regionName = tr.translate('region_name');
    final savedFavorite = tr.translate('saved_favorite');
    final saveFavorite = tr.translate('save_favorite');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _event!.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: kTitleTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _event!.date != null
                  ? '$datePrefix: ${DateFormat('dd/MM/yyyy').format(_event!.date!)}'
                  : (_event!.year != null
                  ? '$yearPrefix: ${_event!.year}'
                  : '$datePrefix: $dateUnknown'),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 6,
            shadowColor: kPrimaryColor.withOpacity(0.4),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _buildImageWidget(_event!.imageUrl)),
            ),
          ),
          const SizedBox(height: 20),
          if ((_event!.description ?? '').isNotEmpty)
            Text(
              _event!.description!,
              style: const TextStyle(fontSize: 16, height: 1.4, color: kTitleTextColor),
              textAlign: TextAlign.justify,
            ),
          const SizedBox(height: 20),
          if ((_event!.source ?? '').isNotEmpty)
            Text(
              '$sourcePrefix: ${_event!.source}',
              style: TextStyle(fontStyle: FontStyle.italic, color: kSubtextColor),
            ),
          const SizedBox(height: 20),
          if (_event!.latitude != null && _event!.longitude != null) ...[
            Text(
              mapLocation,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: kAppBarColor),
            ),
            const SizedBox(height: 12),
            _buildMapWidget(),
            const SizedBox(height: 20),
          ],
          if ((_event!.locationName?.isNotEmpty ?? false))
            Text(
              '$locationName: ${_event!.locationName}',
              style:
              const TextStyle(fontSize: 16, color: kTitleTextColor),
            ),
          if ((_event!.region?.isNotEmpty ?? false))
            Text(
              '$regionName: ${_event!.region}',
              style:
              const TextStyle(fontSize: 16, color: kTitleTextColor),
            ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                _isFavorite ? Colors.redAccent : kPrimaryColor,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 6,
              ),
              onPressed: _toggleFavorite,
              icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white),
              label: Text(
                _isFavorite ? savedFavorite : saveFavorite,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// 🧩 Chuyển Color -> Hex
extension HexColor on Color {
  String toHexString({bool withHash = true}) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    return (withHash ? '#' : '') + hex.substring(2);
  }
}
