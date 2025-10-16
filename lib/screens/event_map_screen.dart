import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../l10n/app_localizations.dart';
import '../db/db_helper.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

// --- Màu sắc ---
const Color kPrimaryColor = Color(0xFF81C784);
const Color kAppBarColor = Color(0xFF4DB6AC);
const Color kBackgroundColor = Color(0xFFF9F9F9);
const Color kTitleTextColor = Color(0xFF424242);
const Color kCardColor = Colors.white;

class EventMapScreen extends StatefulWidget {
  final int year;
  final int? month;
  final int? day;
  final List<EventModel>? events;
  final int? userId;

  const EventMapScreen({
    super.key,
    required this.year,
    this.month,
    this.day,
    this.events,
    this.userId,
  });

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  List<EventModel> _events = [];
  bool _loading = true;
  maplibre.MaplibreMapController? _controller;
  bool _mapInitialized = false;
  bool _provinceLayersAdded = false;
  bool _eventSymbolsAdded = false;

  static const String defaultIconId = "default-event-marker";
  maplibre.Symbol? _selectedSymbol;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _controller?.onSymbolTapped.clear();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    List<EventModel> events = widget.events ?? [];

    if (widget.events == null) {
      List<Map<String, dynamic>> rawData = [];

      if (widget.day != null && widget.month != null) {
        final selectedDate = DateTime(widget.year, widget.month!, widget.day!);
        rawData = await DBHelper.eventsOfDay(selectedDate);
      } else if (widget.month != null) {
        rawData = await DBHelper.eventsOfMonth(widget.year, widget.month!);
      } else {
        rawData = await DBHelper.eventsOfYear(widget.year);
      }

      events = rawData.map((e) => EventModel.fromMap(e)).toList();
    }

    _events = events
        .where((e) => e.latitude != null && e.longitude != null && e.eventId != null)
        .toList();
    _events.sort((a, b) => a.eventId!.compareTo(b.eventId!));

    debugPrint("✅ Đã tải ${_events.length} sự kiện có tọa độ.");
    setState(() => _loading = false);
  }

  // ✅ Marker lớn và rõ hơn
  Future<Uint8List> _loadDefaultMarkerImage() async {
    final data = await rootBundle.load('assets/marker.png');
    final bytes = data.buffer.asUint8List();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final resized = img.copyResize(decoded, width: 64, height: 64);
      return Uint8List.fromList(img.encodePng(resized));
    }
    return bytes;
  }

  Map<String, dynamic> _filterUniqueProvinces(Map<String, dynamic> geoJson) {
    final features = geoJson['features'] as List<dynamic>? ?? [];
    final seenNames = <String>{};
    final uniqueFeatures = <Map<String, dynamic>>[];

    for (final feature in features) {
      if (feature is Map<String, dynamic>) {
        final props = feature['properties'] as Map<String, dynamic>? ?? {};
        final name = props['ten_tinh'] ?? props['name'];
        if (name != null && name is String && name.isNotEmpty && !seenNames.contains(name)) {
          seenNames.add(name);
          uniqueFeatures.add(feature);
        }
      }
    }

    return {
      'type': 'FeatureCollection',
      'name': geoJson['name'] ?? 'Vietnam',
      'features': uniqueFeatures,
    };
  }

  Future<void> _addProvinceLayers() async {
    if (_controller == null || _provinceLayersAdded) return;
    const sourceId = 'vn-provinces-source';
    Map<String, dynamic>? geoJson;

    try {
      final data = await rootBundle.loadString('assets/vn.json');
      geoJson = jsonDecode(data);
    } catch (_) {
      debugPrint("⚠️ Lỗi đọc GeoJSON");
      return;
    }

    if (geoJson == null) return;
    final filtered = _filterUniqueProvinces(geoJson);
    await _controller!.addGeoJsonSource(sourceId, filtered);

    await _controller!.addLineLayer(
      sourceId,
      'vn-outline',
      maplibre.LineLayerProperties(
        lineColor: MapHexColor(kPrimaryColor).toHexString(),
        lineWidth: 1.5,
      ),
    );

    await _controller!.addSymbolLayer(
      sourceId,
      'vn-label',
      maplibre.SymbolLayerProperties(
        textField: ['get', 'ten_tinh'],
        textSize: 10,
        textColor: MapHexColor(kTitleTextColor).toHexString(),
        textHaloColor: MapHexColor(kCardColor).toHexString(),
        textHaloWidth: 1.2,
      ),
    );
    _provinceLayersAdded = true;
  }

  Future<void> _addEventSymbols() async {
    if (_controller == null || _events.isEmpty || _eventSymbolsAdded) return;

    final markerBytes = await _loadDefaultMarkerImage();
    try {
      await _controller!.addImage(defaultIconId, markerBytes);
    } catch (_) {}

    int count = 0;
    for (final e in _events) {
      if (e.latitude == null || e.longitude == null || e.eventId == null) continue;
      try {
        await _controller!.addSymbol(
          maplibre.SymbolOptions(
            geometry: maplibre.LatLng(e.latitude!, e.longitude!),
            iconImage: defaultIconId,
            iconSize: 1.8,
          ),
          {
            "eventId": e.eventId.toString(),
            "title": e.title ?? "Sự kiện không tên",
          },
        );
        count++;
      } catch (_) {}
    }

    if (count > 0) _eventSymbolsAdded = true;
  }

  Future<void> _onMapCreated(maplibre.MaplibreMapController controller) async {
    _controller = controller;

    // Khi nhấn marker → hiển thị popup + nút xem chi tiết
    _controller!.onSymbolTapped.add((symbol) {
      setState(() {
        _selectedSymbol = symbol;
      });
      final raw = symbol.data?["eventId"];
      int? eid = raw is String ? int.tryParse(raw) : null;
      if (eid == null) return;

      final event = _events.firstWhere((e) => e.eventId == eid);
      _showEventPopup(event);
    });

    if (!_mapInitialized) {
      _mapInitialized = true;
      await _addProvinceLayers();
      await _addEventSymbols();
    }
  }

  void _showEventPopup(EventModel event) {
    final latLng = maplibre.LatLng(event.latitude!, event.longitude!);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(event.title ?? "Sự kiện", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          (event.shortDescription ?? "Không có mô tả"),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // đóng popup
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(
                    eventId: event.eventId!,
                    userId: widget.userId,
                  ),
                ),
              );
            },
            child: const Text("Xem chi tiết"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final title = StringBuffer(tr.translate('map_title_prefix'));
    if (widget.day != null && widget.month != null) {
      title.write(' ${widget.day}/${widget.month}/${widget.year}');
    } else if (widget.month != null) {
      title.write(' ${widget.month}/${widget.year}');
    } else {
      title.write(' ${widget.year}');
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          title.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kAppBarColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : maplibre.MaplibreMap(
        styleString: 'https://demotiles.maplibre.org/style.json',
        initialCameraPosition: const maplibre.CameraPosition(
          target: maplibre.LatLng(16.0, 107.0),
          zoom: 5.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

// --- Tiện ích định dạng màu HEX ---
extension MapHexColor on Color {
  String toHexString({bool withHash = true}) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    final rgb = hex.substring(2);
    return (withHash ? '#' : '') + rgb;
  }
}
