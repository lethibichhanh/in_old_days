// File: home_screen.dart (ĐÃ FIX LỖI SẮP XẾP ĐỂ CHỌN SỰ KIỆN GẦN NHẤT)
import 'dart:io';
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
import '../l10n/app_localizations.dart';
import '../main.dart';

// --- Khai báo màu sắc Pastel Tươi sáng & Chill hơn ---
const Color kPrimaryColor = Color(0xFF81C784); // Xanh Mint Nhẹ (Light Mint)
const Color kAppBarColor = Color(0xFF4DB6AC); // Xanh Mint Đậm hơn
const Color kAccentColor = Color(0xFFFFAB91); // Hồng Đào/Coral Nhạt - Cho điểm nhấn/nút nổi
const Color kBackgroundColor = Color(0xFFF9F9F9); // Nền trắng ngà rất nhẹ (Chill)
const Color kCardColor = Colors.white;
const Color kTitleTextColor = Color(0xFF424242); // Xám Đen Nhẹ
const Color kSubtextColor = Color(0xFF9E9E9E); // Xám Rất Nhẹ

enum AppLanguage { vi, en, zh }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ Đảm bảo _year luôn khởi tạo là năm hiện tại
  int _year = DateTime.now().year;
  int? _month;
  int? _day; // 🆕 State cho ngày cụ thể
  bool _loading = true;
  List<EventModel> _events = [];
  EventModel? _featuredEvent;
  String _filterType = "Tất cả"; // Giá trị mặc định ban đầu

  UserModel? _user;
  int? get _currentUserId => _user?.id;
  bool _didLoadUser = false;

  Map<String, List<EventModel>> _groupedEvents = {};

  // --- Hàm hỗ trợ Dịch thuật ---
  String _getText(String key) {
    return AppLocalizations.of(context)?.translate(key) ?? key;
  }

  // 🔹 Chuyển ngôn ngữ (Giữ nguyên)
  void _changeLanguage(AppLanguage newLanguage) {
    String code = 'en';

    switch (newLanguage) {
      case AppLanguage.vi:
        code = 'vi';
        break;
      case AppLanguage.en:
        code = 'en';
        break;
      case AppLanguage.zh:
        code = 'zh';
        break;
    }

    InOldDaysApp.setLocale(context, Locale(code));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didLoadUser) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['user'] != null) {
        UserModel? tempUser;
        if (args['user'] is Map<String, dynamic>) {
          tempUser = UserModel.fromMap(args['user'] as Map<String, dynamic>);
        } else if (args['user'] is UserModel) {
          tempUser = args['user'] as UserModel;
        }

        if (tempUser != null) {
          setState(() {
            _user = tempUser;
            _didLoadUser = true;
          });
        }
      }
    }

    // Cập nhật _filterType từ bản dịch khi ngôn ngữ thay đổi
    final tr = AppLocalizations.of(context);
    if (tr != null) {
      if (_filterType == "Tất cả" || _filterType == "All" || _filterType == "所有") {
        _filterType = tr.translate('filter_all');
      } else if (_filterType == "Quá khứ" || _filterType == "Past" || _filterType == "过去") {
        _filterType = tr.translate('filter_past');
      } else if (_filterType == "Tương lai" || _filterType == "Future" || _filterType == "未来") {
        _filterType = tr.translate('filter_future');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // --- Hàm nhóm sự kiện (Đã xác nhận dùng dd/MM/yyyy) ---
  void _groupEvents(List<EventModel> events) {
    _groupedEvents.clear();

    final unknownDateKey = _getText('unknown_date');

    for (var event in events) {
      String key;
      if (event.date != null) {
        // ✅ Đảm bảo định dạng DD/MM/YYYY
        key = DateFormat('dd/MM/yyyy').format(event.date!);
      } else {
        key = unknownDateKey;
      }

      if (!_groupedEvents.containsKey(key)) {
        _groupedEvents[key] = [];
      }
      _groupedEvents[key]!.add(event);
    }
    _groupedEvents = Map.fromEntries(
      _groupedEvents.entries.toList()..sort((e1, e2) {
        if (e1.key == unknownDateKey) return 1;
        if (e2.key == unknownDateKey) return -1;
        return e2.key.compareTo(e1.key);
      }),
    );
  }

  /// 📦 Load sự kiện từ DB (CẬP NHẬT: Kết hợp sự kiện Ngày cụ thể và Ngày/Tháng lặp lại)
  /// 📦 Load sự kiện từ DB (CẬP NHẬT: Tách logic tìm Featured Event)
  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> rawData = [];
    final currentYear = _year;

    // Lọc theo Ngày/Tháng/Năm
    if (_day != null && _month != null) {
      // 1. Lọc theo ngày cụ thể (YYYY-MM-DD): Sự kiện lịch sử diễn ra đúng ngày đó
      DateTime selectedDate = DateTime(currentYear, _month!, _day!);
      final specificDayEvents = await DBHelper.eventsOfDay(selectedDate);
      rawData.addAll(specificDayEvents);

      // 2. Lọc theo ngày & tháng (MM-DD): Sự kiện kỷ niệm lặp lại
      final recurringEvents = await DBHelper.eventsByDayAndMonth(_month!, _day!);

      // Lọc các sự kiện kỷ niệm trùng lặp với sự kiện lịch sử (nếu có)
      final specificDayIds = specificDayEvents.map((e) => e['event_id']).toSet();
      final filteredRecurringEvents = recurringEvents.where((e) => !specificDayIds.contains(e['event_id']));

      rawData.addAll(filteredRecurringEvents.toList());

    } else if (_month != null) {
      // Lọc theo tháng
      rawData = await DBHelper.eventsOfMonth(currentYear, _month!);
    } else {
      // Lọc theo năm
      rawData = await DBHelper.eventsOfYear(currentYear);
    }

    // Loại bỏ hoàn toàn các sự kiện trùng lặp (phòng trường hợp)
    final uniqueEventsMap = <int, Map<String, dynamic>>{};
    for (var row in rawData) {
      if (row['event_id'] is int) {
        uniqueEventsMap[row['event_id'] as int] = row;
      }
    }
    List<EventModel> allEvents = uniqueEventsMap.values.map((e) => EventModel.fromMap(e)).toList();

    final now = DateTime.now();
    final filterFuture = _getText('filter_future');
    final filterPast = _getText('filter_past');

    // --- 1. TÌM SỰ KIỆN NỔI BẬT (Gần nhất trong Tương lai) ---
    // Lấy tất cả sự kiện trong tương lai có ngày xác định
    List<EventModel> futureEvents = allEvents
        .where((e) => e.date != null && e.date!.isAfter(now))
        .toList();

    // Sắp xếp Tăng Dần để sự kiện gần nhất trong tương lai lên đầu
    futureEvents.sort((a, b) => a.date!.compareTo(b.date!));

    EventModel? nearestFutureEvent;
    if (futureEvents.isNotEmpty) {
      nearestFutureEvent = futureEvents.first;
      // Loại bỏ sự kiện nổi bật ra khỏi danh sách sự kiện chính
      allEvents.removeWhere((e) => e.eventId == nearestFutureEvent!.eventId);
    }
    // ----------------------------------------------------

    // --- 2. ÁP DỤNG BỘ LỌC THỜI GIAN CỦA NGƯỜI DÙNG CHO DANH SÁCH CÒN LẠI ---
    if (_filterType == filterFuture) {
      // Nếu người dùng lọc Future, chỉ giữ lại các sự kiện FUTURE còn lại
      allEvents = allEvents.where((e) => e.date != null && e.date!.isAfter(now)).toList();
    } else if (_filterType == filterPast) {
      // Nếu người dùng lọc Past, chỉ giữ lại các sự kiện PAST
      allEvents = allEvents.where((e) => e.date != null && e.date!.isBefore(now)).toList();
    }

    // --- 3. SẮP XẾP DANH SÁCH SỰ KIỆN CÒN LẠI (events) ---
    // Sắp xếp các sự kiện còn lại theo ngày GIẢM DẦN (mới nhất lên đầu)
    allEvents.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!); // Sắp xếp GIẢM DẦN (Latest date first)
    });

    _groupEvents(allEvents);

    setState(() {
      _featuredEvent = nearestFutureEvent; // Cập nhật Featured Event
      _events = allEvents; // Cập nhật danh sách sự kiện chính (đã loại bỏ featured)
      _loading = false;
    });
  }
  /// 🎚️ Bộ lọc sự kiện (Giữ nguyên)
  void _openFilterDialog() async {
    final tr = AppLocalizations.of(context)!;

    final List<String> filterOptions = [
      tr.translate('filter_all'),
      tr.translate('filter_past'),
      tr.translate('filter_future')
    ];

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.translate('filter_title'), style: const TextStyle(color: kTitleTextColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: filterOptions
              .map((f) => RadioListTile<String>(
            title: Text(f, style: const TextStyle(color: kTitleTextColor)),
            value: f,
            groupValue: _filterType,
            activeColor: kPrimaryColor,
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


  /// 🗓️ Chọn tháng (ĐÃ CẬP NHẬT: Reset _day)
  void _openMonthPicker() async {
    final tr = AppLocalizations.of(context)!;

    final picked = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr.translate('select_month'), style: const TextStyle(color: kTitleTextColor, fontWeight: FontWeight.bold)),
        content: ListView.builder(
          shrinkWrap: true,
          itemCount: 13,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ListTile(
                title: Text(tr.translate('full_year'), style: const TextStyle(fontWeight: FontWeight.bold, color: kTitleTextColor)),
                onTap: () => Navigator.pop(ctx, null),
              );
            }
            return ListTile(
              title: Text("${tr.translate('month')} $i", style: TextStyle(color: i == _month ? kPrimaryColor : kTitleTextColor)),
              selected: i == _month,
              selectedColor: kPrimaryColor,
              onTap: () => Navigator.pop(ctx, i),
            );
          },
        ),
      ),
    );

    if (picked != _month) {
      setState(() {
        _month = picked;
        _day = null; // ✅ Reset ngày
      });
      await _loadEvents();
    }
  }

  /// 🗓️ 🆕 Chọn ngày cụ thể (Giữ nguyên)
  void _openDatePicker() async {
    final tr = AppLocalizations.of(context)!;

    // Ngày khởi tạo: Ưu tiên ngày đang chọn, nếu không có thì lấy ngày hôm nay trong năm đang chọn
    final initialDate = (_month != null && _day != null)
        ? DateTime(_year, _month!, _day!)
        : DateTime(_year, DateTime.now().month, DateTime.now().day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1000),
      lastDate: DateTime(DateTime.now().year + 50),
      helpText: tr.translate('select_date'),
      confirmText: tr.translate('confirm'),
      cancelText: tr.translate('cancel'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: kPrimaryColor,
            colorScheme: ColorScheme.light(primary: kPrimaryColor, onPrimary: Colors.white, surface: kCardColor),
            dialogBackgroundColor: kCardColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      // Nếu ngày được chọn, cập nhật cả năm, tháng, và ngày.
      if (pickedDate.year != _year || pickedDate.month != _month || pickedDate.day != _day) {
        setState(() {
          _year = pickedDate.year;
          _month = pickedDate.month;
          _day = pickedDate.day;
        });
        await _loadEvents();
      }
    } else {
      // Nếu hủy chọn ngày (nhưng trước đó đã có ngày), reset _day để trở về lọc theo tháng/năm
      if (_day != null) {
        setState(() {
          _day = null;
        });
        await _loadEvents();
      }
    }
  }

  // --- Các hàm hỗ trợ hình ảnh (Giữ nguyên) ---
  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildThumbnail(String? imageUrl, {required double height}) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return _fallbackImage(height: height);

    String path = imageUrl.replaceAll("\\", "/");
    bool isNetwork = path.startsWith('http');

    if (isNetwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          path,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(height: height),
        ),
      );
    } else {
      String assetPath = path.startsWith('assets/') ? path : 'assets/Image/$path';
      return FutureBuilder<bool>(
        future: _assetExists(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: height,
              width: double.infinity,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kAccentColor)),
            );
          }
          if (snapshot.data == true) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(assetPath, height: height, width: double.infinity, fit: BoxFit.cover),
            );
          } else {
            return _fallbackImage(height: height);
          }
        },
      );
    }
  }

  Widget _fallbackImage({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.history_edu_outlined, color: kPrimaryColor.withOpacity(0.5), size: height * 0.4),
    );
  }

  // --- Widget Thẻ Sự kiện Tiêu chuẩn (Đã xác nhận dùng dd/MM/yyyy) ---
  Widget _buildStandardEventCard(EventModel e) {
    // ✅ Đảm bảo định dạng DD/MM/YYYY
    final dateStr = e.date != null
        ? DateFormat('dd/MM/yyyy').format(e.date!)
        : _getText('unknown_date');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: InkWell(
        onTap: () {
          if (e.eventId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.eventId!, userId: _currentUserId)),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kSubtextColor.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3), // shadow nhẹ
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ảnh nhỏ bên trái
              SizedBox(
                width: 100,
                height: 100,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // Góc bo tròn hơn
                    child: _buildThumbnail(e.imageUrl, height: 80),
                  ),
                ),
              ),

              // Thông tin bên phải
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTitleTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 13, color: kPrimaryColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.locationName ?? _getText('unknown_location'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kSubtextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Thẻ Sự kiện Nổi bật (Đã xác nhận dùng dd/MM/yyyy) ---
  Widget _buildFeaturedCard(EventModel e) {
    // ✅ Đảm bảo định dạng DD/MM/YYYY
    final dateStr = e.date != null ? DateFormat('dd/MM/yyyy').format(e.date!) : _getText('unknown_date');
    final isFuture = e.date != null && e.date!.isAfter(DateTime.now());
    final statusText = isFuture ? _getText('filter_future') : _getText('filter_past');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: InkWell(
        onTap: () {
          if (e.eventId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.eventId!, userId: _currentUserId)),
            );
          }
        },
        borderRadius: BorderRadius.circular(20), // Bo tròn cực lớn
        child: Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kAppBarColor.withOpacity(0.15), // Shadow đậm hơn
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề nổi bật trong ảnh
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: _buildThumbnail(e.imageUrl, height: 180),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: kAccentColor.withOpacity(0.9), // Accent color nổi bật
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kTitleTextColor,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: kAppBarColor.withOpacity(0.7), // Overlay Xanh Mint đậm
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Nội dung mô tả
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 14, color: kPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      e.description ?? _getText('no_description'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: kSubtextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // --- Widget để nhóm các Sự kiện theo Ngày (Giữ nguyên logic dịch) ---
// --- Widget để nhóm các Sự kiện theo Ngày (ĐÃ SỬA: Dùng _featuredEvent) ---
  List<Widget> _buildGroupedEventList() {
    List<Widget> widgets = [];

    final unknownDateKey = _getText('unknown_date');
    final otherEvents = _getText('other_events');
    final featuredEvents = _getText('featured_events');
    final datePrefix = _getText('date_prefix');
    final noEventsFound = _getText('no_events_found');

    // Thẻ nổi bật đầu tiên
    if (_featuredEvent != null) { // 👈 CHỈ HIỂN THỊ NẾU CÓ SỰ KIỆN NỔI BẬT ĐƯỢC TÌM THẤY
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10, left: 20, right: 16),
        child: Text(featuredEvents, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kTitleTextColor)),
      ));
      // Dùng _featuredEvent
      widgets.add(_buildFeaturedCard(_featuredEvent!));
    }

    // Danh sách sự kiện còn lại (đã được lọc và sắp xếp)
    final eventsToGroup = _events;

    if (eventsToGroup.isNotEmpty) {

      // Nếu không có sự kiện nổi bật, tiêu đề đầu tiên sẽ là 'Sự kiện nổi bật',
      // Nếu đã có sự kiện nổi bật, tiêu đề đầu tiên sẽ là 'Sự kiện khác'.
      if (_featuredEvent == null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, left: 20, right: 16),
          child: Text(featuredEvents, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kTitleTextColor)),
        ));
      }

      Map<String, List<EventModel>> remainingGroupedEvents = {};
      for (var event in eventsToGroup) {
        // ✅ Đảm bảo định dạng DD/MM/YYYY
        String key = event.date != null ? DateFormat('dd/MM/yyyy').format(event.date!) : unknownDateKey;
        if (!remainingGroupedEvents.containsKey(key)) {
          remainingGroupedEvents[key] = [];
        }
        remainingGroupedEvents[key]!.add(event);
      }

      remainingGroupedEvents = Map.fromEntries(
        remainingGroupedEvents.entries.toList()..sort((e1, e2) {
          if (e1.key == unknownDateKey) return 1;
          if (e2.key == unknownDateKey) return -1;
          // Sắp xếp nhóm ngày theo ngày (giảm dần)
          return e2.key.compareTo(e1.key);
        }),
      );


      remainingGroupedEvents.forEach((dateKey, events) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 25.0, bottom: 8.0, left: 20.0, right: 16.0),
            child: Text(
              dateKey == unknownDateKey ? otherEvents : "$datePrefix $dateKey", // Dịch
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kAppBarColor,
              ),
            ),
          ),
        );
        for (var e in events) {
          widgets.add(_buildStandardEventCard(e));
        }
      });
    }

    if (widgets.isEmpty && !_loading) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Text(
              noEventsFound, // Dịch
              textAlign: TextAlign.center,
              style: const TextStyle(color: kSubtextColor, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
  // --- Hàm hỗ trợ hiển thị tiêu đề bộ lọc ngày tháng (Đã xác nhận dùng dd/MM/yyyy) ---
  String _buildDateFilterText(AppLocalizations tr) {
    if (_day != null) {
      // ✅ Lọc theo ngày cụ thể: Format ra DD/MM/YYYY
      return DateFormat('dd/MM/yyyy').format(DateTime(_year, _month!, _day!));
    } else if (_month != null) {
      // Lọc theo tháng
      return "${tr.translate('month_prefix')} $_month ${tr.translate('year_prefix')} $_year";
    } else {
      // Lọc theo năm
      return "${tr.translate('full_year')} $_year";
    }
  }


  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final title = tr.translate('app_title');

    return Scaffold(
      backgroundColor: kBackgroundColor,

      // 🧭 Drawer
      drawer: _buildDrawer(),

      // AppBar
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kAppBarColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // NÚT CHUYỂN ĐỔI NGÔN NGỮ
          PopupMenuButton<AppLanguage>(
            onSelected: _changeLanguage,
            itemBuilder: (context) => const [
              PopupMenuItem(value: AppLanguage.vi, child: Text('🇻🇳 Tiếng Việt')),
              PopupMenuItem(value: AppLanguage.en, child: Text('🇺🇸 English')),
              PopupMenuItem(value: AppLanguage.zh, child: Text('🇨🇳 中文')),
            ],
            icon: const Icon(Icons.language, color: Colors.white),
          ),
          // CÁC NÚT KHÁC
          IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: tr.translate('filter_tooltip'),
              onPressed: _openFilterDialog
          ),
          // NÚT CHỌN NĂM (Icons.calendar_today) ĐÃ ĐƯỢC XÓA THEO YÊU CẦU
        ],
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Thanh Chọn Ngày/Tháng/Năm (Sticky Header) ---
          Container(
            color: kAppBarColor,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 🆕 NÚT CHỌN NGÀY CỤ THỂ (HIỂN THỊ NGÀY ĐANG LỌC)
                TextButton.icon(
                  onPressed: _openDatePicker,
                  icon: const Icon(Icons.today, color: Colors.white, size: 20),
                  label: Text(
                    _buildDateFilterText(tr), // Hiển thị ngày/tháng/năm đang lọc
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    backgroundColor: kPrimaryColor, // Màu nền cho nút
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Góc bo tròn
                    elevation: 4, // Thêm shadow nhẹ
                  ),
                ),
                const SizedBox(width: 8),

                // NÚT CHỌN THÁNG (Icon nhỏ hơn)
                Container(
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.date_range, color: Colors.white, size: 20),
                    tooltip: tr.translate('select_month'),
                    onPressed: _openMonthPicker,
                  ),
                ),

                // NÚT CHỌN NĂM (Vẫn giữ lại để người dùng có thể lọc theo năm cụ thể)
                const SizedBox(width: 8),


              ],
            ),
          ),

          // --- Nội dung chính (Sự kiện) ---
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : RefreshIndicator(
              onRefresh: _loadEvents,
              color: kPrimaryColor,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80), // Tăng padding để FAB không che
                children: _buildGroupedEventList(),
              ),
            ),
          ),
        ],
      ),

      // Nút Bản đồ trở về vị trí FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          // CẬP NHẬT: THÊM tham số day: _day
          MaterialPageRoute(builder: (_) => EventMapScreen(year: _year, month: _month, day: _day, userId: _currentUserId)),
        ),
        label: Text(tr.translate('view_map_button'), style: const TextStyle(fontWeight: FontWeight.bold)), // Dịch
        icon: const Icon(Icons.map_outlined),
        backgroundColor: kAccentColor, // Hồng Đào/Coral Nhạt
        foregroundColor: kTitleTextColor, // Màu chữ đen
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Bo tròn FAB
      ),
    );
  }

  // Widget hỗ trợ cho Drawer (Cập nhật logic hiển thị Avatar)
  Widget _buildDrawer() {
    final tr = AppLocalizations.of(context)!;

    // --- Xử lý hiển thị Avatar trong Drawer ---
    ImageProvider? avatarImage;
    if (_user?.avatar?.isNotEmpty ?? false) {
      final avatarPath = _user!.avatar!;
      if (avatarPath.startsWith('http')) {
        avatarImage = NetworkImage(avatarPath);
      } else if (File(avatarPath).existsSync()) {
        avatarImage = FileImage(File(avatarPath));
      }
    }

    // THÊM: Nếu không có ảnh hợp lệ, dùng icon/placeholder mặc định
    final Widget avatarWidget = CircleAvatar(
      backgroundColor: kAccentColor.withOpacity(0.8),
      radius: 30, // Kích thước cố định cho CircleAvatar
      child: ClipOval(
        child: (avatarImage != null)
            ? Image(
          image: avatarImage,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          // Fallback nếu ảnh không load được
          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Colors.white),
        )
            : const Icon(Icons.person, size: 40, color: Colors.white),
      ),
    );


    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: kAppBarColor,
            ),
            currentAccountPicture: avatarWidget, // Sử dụng widget đã xử lý
            accountName: Text(_user?.fullname ?? _user?.username ?? tr.translate('drawer_guest'), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
            accountEmail: Text(_user?.email ?? "", style: const TextStyle(color: kAccentColor)),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: kPrimaryColor),
            title: Text(tr.translate('drawer_home'), style: const TextStyle(color: kTitleTextColor, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_pin_circle_outlined, color: kPrimaryColor),
            title: Text(tr.translate('drawer_figures'), style: const TextStyle(color: kTitleTextColor)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FiguresListScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border, color: kPrimaryColor),
            title: Text(tr.translate('drawer_favorites'), style: const TextStyle(color: kTitleTextColor)),
            onTap: () {
              Navigator.pop(context);
              if (_currentUserId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FavoriteScreen(userId: _currentUserId!)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr.translate('snack_login_fav'))),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined, color: kPrimaryColor),
            title: Text(tr.translate('drawer_profile'), style: const TextStyle(color: kTitleTextColor)),
            onTap: () async {
              Navigator.pop(context);
              // Dòng này đã đúng: Chờ kết quả trả về từ ProfileScreen
              final updatedUser = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                  settings: RouteSettings(arguments: {'user': _user}),
                ),
              );

              if (updatedUser is UserModel) {
                if (mounted) {
                  setState(() {
                    _user = updatedUser; // Cập nhật state _user, kích hoạt lại _buildDrawer và hiển thị Avatar mới
                  });
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(tr.translate('drawer_logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              _user = null;
              setState(() {});
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}