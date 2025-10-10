import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../db/db_helper.dart';
import '../models/event.dart';
import '../models/user_model.dart';
import 'event_detail_screen.dart';
import 'event_map_screen.dart';
import 'favorite_screen.dart';
import 'figures_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _year = DateTime.now().year;
  int? _month;
  bool _loading = true;
  List<EventModel> _events = [];
  String _filterType = "Tất cả";

  UserModel? _user; // ✅ Nhận từ LoginScreen

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['user'] is UserModel) {
      _user = args['user'];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  /// 📦 Load sự kiện từ DB
  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> rawData;
    if (_month != null) {
      rawData = await DBHelper.eventsOfMonth(_year, _month!);
    } else {
      rawData = await DBHelper.eventsOfYear(_year);
    }

    List<EventModel> allEvents = rawData.map((e) => EventModel.fromMap(e)).toList();
    final now = DateTime.now();

    // Lọc theo loại
    if (_filterType == "Tương lai") {
      allEvents = allEvents.where((e) => e.date != null && e.date!.isAfter(now)).toList();
    } else if (_filterType == "Đã qua") {
      allEvents = allEvents.where((e) => e.date != null && e.date!.isBefore(now)).toList();
    }

    setState(() {
      _events = allEvents;
      _loading = false;
    });
  }

  /// 🎚️ Bộ lọc sự kiện
  void _openFilterDialog() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🔍 Lọc sự kiện"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Tất cả", "Đã qua", "Tương lai"]
              .map((f) => RadioListTile<String>(
            title: Text(f),
            value: f,
            groupValue: _filterType,
            onChanged: (val) => Navigator.pop(ctx, val),
          ))
              .toList(),
        ),
      ),
    );
    if (picked != null && picked != _filterType) {
      setState(() => _filterType = picked);
      await _loadEvents();
    }
  }

  /// 📆 Chọn năm
  void _openYearPicker() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('📆 Chọn năm'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(1000),
              lastDate: DateTime(DateTime.now().year + 50),
              initialDate: DateTime(_year),
              selectedDate: DateTime(_year),
              onChanged: (d) => Navigator.of(ctx).pop(d.year),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _year) {
      setState(() {
        _year = picked;
        _month = null;
      });
      await _loadEvents();
    }
  }

  /// 🗓️ Chọn tháng
  void _openMonthPicker() async {
    final picked = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🗓️ Chọn tháng'),
        content: ListView.builder(
          shrinkWrap: true,
          itemCount: 13,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ListTile(
                title: const Text("📅 Cả năm"),
                onTap: () => Navigator.pop(ctx, null),
              );
            }
            return ListTile(
              title: Text("Tháng $i"),
              onTap: () => Navigator.pop(ctx, i),
            );
          },
        ),
      ),
    );

    if (picked != _month) {
      setState(() => _month = picked);
      await _loadEvents();
    }
  }

  /// 🖼️ Kiểm tra asset tồn tại
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 🖼️ Hiển thị ảnh sự kiện
  Widget _buildThumbnail(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return _fallbackImage();

    String path = imageUrl.replaceAll("\\", "/");
    bool isNetwork = path.startsWith('http');

    if (isNetwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          path,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        ),
      );
    } else {
      String assetPath = path.startsWith('assets/') ? path : 'assets/Image/$path';
      return FutureBuilder<bool>(
        future: _assetExists(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 70,
              height: 70,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snapshot.data == true) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(assetPath, width: 70, height: 70, fit: BoxFit.cover),
            );
          } else {
            return _fallbackImage();
          }
        },
      );
    }
  }

  Widget _fallbackImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown.shade50,

      // 🧭 Drawer
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff8d5524), Color(0xffc68642)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundImage: (_user?.avatar?.isNotEmpty ?? false)
                    ? NetworkImage(_user!.avatar!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              accountName: Text(_user?.fullname ?? _user?.username ?? "Người dùng"),
              accountEmail: Text(_user?.email ?? ""),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Trang chủ'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Nhân vật lịch sử'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FiguresListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Sự kiện yêu thích'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Thông tin cá nhân'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                    settings: RouteSettings(arguments: {'user': _user}),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        elevation: 2,
        title: const Text("🇻🇳 In Old Days", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff8d5524), Color(0xffc68642)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: _openFilterDialog),
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _openYearPicker),
          IconButton(icon: const Icon(Icons.date_range_outlined), onPressed: _openMonthPicker),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(child: Text("😢 Không có sự kiện nào phù hợp."))
          : RefreshIndicator(
        onRefresh: _loadEvents,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _events.length,
          itemBuilder: (ctx, i) {
            final e = _events[i];
            final dateStr = e.date != null
                ? DateFormat('dd/MM/yyyy').format(e.date!)
                : "Không rõ ngày";
            final isFuture = e.date != null && e.date!.isAfter(DateTime.now());
            final chipColor =
            isFuture ? Colors.green.shade100 : Colors.orange.shade100;
            final chipText = isFuture ? "Tương lai" : "Đã qua";

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: () {
                  if (e.eventId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(eventId: e.eventId!),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _buildThumbnail(e.imageUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$dateStr • ${e.locationName ?? 'Không rõ địa điểm'}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Chip(
                                  label: Text(chipText),
                                  backgroundColor: chipColor,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventMapScreen(year: _year, month: _month)),
        ),
        label: const Text("Xem bản đồ"),
        icon: const Icon(Icons.map),
        backgroundColor: Colors.brown.shade400,
      ),
    );
  }
}
