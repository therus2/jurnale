import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'pair_detail.dart';
import 'dart:math' as math;
import 'widgets/app_drawer.dart';

class DayScreen extends StatefulWidget {
  final String? overrideWeekType;
  const DayScreen({Key? key, this.overrideWeekType}) : super(key: key);

  @override
  _DayScreenState createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool loading = true;
  List<PairItem> pairs = [];
  final String filename = 'assets/data/thursday.json';
  int? _groupNumber;
  String? _weekType;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadGroupNumber();
    _loadWeekType();
    loadDay();
  }

  Future<void> _loadGroupNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _groupNumber = prefs.getInt('groupNumber') ?? 1;
    });
  }

  Future<void> _loadWeekType() async {
    if (widget.overrideWeekType != null) {
      setState(() => _weekType = widget.overrideWeekType);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _weekType = prefs.getString('weekType');
    });
  }

  Future<void> _selectGroup(int groupNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('groupNumber', groupNumber);
    setState(() {
      _groupNumber = groupNumber;
    });
    if (_scaffoldKey.currentState!.isEndDrawerOpen) {
      Navigator.of(context).pop();
    }
    await loadDay();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Выбрана подгруппа $groupNumber')),
    );
  }

  Future<void> _selectWeekType(String weekType) async {
    final prefs = await SharedPreferences.getInstance();

    if (weekType == 'auto') {
      await prefs.remove('weekType'); // Удаляем настройку для авторежима
    } else {
      await prefs.setString('weekType', weekType);
    }

    setState(() {
      _weekType = weekType == 'auto' ? null : weekType;
    });

    if (_scaffoldKey.currentState!.isEndDrawerOpen) {
      Navigator.of(context).pop();
    }

    await loadDay();

    String message = weekType == 'auto'
        ? 'Режим "Авто" - используется текущая неделя'
        : 'Выбрана ${weekType == 'odd' ? 'нечётная' : 'чётная'} неделя';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildDrawer() {
    String currentWeekTypeDisplay = _getCurrentWeekTypeDisplay();

    return AppDrawer(
      currentGroup: _groupNumber,
      selectedWeekType: _weekType,
      weekTypeDisplay: currentWeekTypeDisplay,
      onGroupSelect: _selectGroup,
      onWeekTypeSelect: _selectWeekType,
      dayTitle: 'Четверг',
    );
  }

  String _getCurrentWeekTypeDisplay() {
    // Авторежим - когда _weekType равен null
    if (_weekType == null) {
      DateTime today = DateTime.now();
      int weekOfYear = getWeekNumber(today);
      return (weekOfYear % 2 == 0) ? 'Чётная (авто)' : 'Нечётная (авто)';
    } else if (_weekType == 'odd') {
      return 'Нечётная (ручная)';
    } else if (_weekType == 'even') {
      return 'Чётная (ручная)';
    } else {
      // На всякий случай, если какое-то другое значение
      DateTime today = DateTime.now();
      int weekOfYear = getWeekNumber(today);
      return (weekOfYear % 2 == 0) ? 'Чётная (авто)' : 'Нечётная (авто)';
    }
  }

  Future<void> loadDay() async {
    setState(() => loading = true);
    try {
      String raw = await rootBundle.loadString(filename);
      if (raw.trim().isEmpty) {
        pairs = [];
        return;
      }
      if (int.tryParse(raw.trim()) != null) {
        throw Exception('File contains number instead of JSON: $raw');
      }
      dynamic decoded = json.decode(raw);
      if (decoded is! List) {
        throw Exception('Expected List but got: ${decoded.runtimeType}');
      }
      List<dynamic> arr = decoded;

      // Используем выбранный тип недели или автоматический
      String weekType;
      if (_weekType == 'odd' || _weekType == 'even') {
        weekType = _weekType!;
      } else {
        DateTime today = DateTime.now();
        int weekOfYear = getWeekNumber(today);
        weekType = (weekOfYear % 2 == 0) ? 'even' : 'odd';
      }

      int group = _groupNumber ?? 1;
      pairs = arr
          .map((e) {
            try {
              return PairItem.fromMap(e);
            } catch (e) {
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PairItem>()
          .where((p) {
            bool weekMatch = (p.week == 'both' || p.week == weekType);
            bool groupMatch =
                (p.group == 'both' || p.group == group.toString());
            return weekMatch && groupMatch;
          })
          .toList();
    } catch (e) {
      pairs = [];
    }
    setState(() => loading = false);
  }

  void openPair(PairItem p) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PairDetailPage(pair: p, dayFile: 'monday.json')));
    await loadDay();
  }

  int getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = date.difference(firstDayOfYear).inDays;
    return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
  }

  @override
  Widget build(BuildContext context) {
    String weekTypeDisplay = _getCurrentWeekTypeDisplay();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Четверг'),
            Text(
              weekTypeDisplay,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          icon: Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState!.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : pairs.isEmpty
              ? Center(child: Text('На этот день пар нет'))
              : ListView.builder(
                  itemCount: pairs.length,
                  itemBuilder: (context, i) {
                    var p = pairs[i];
                    return Card(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]
                          : const Color.fromARGB(255, 234, 228, 255),
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${p.index}. ${p.subject}'),
                        subtitle: Text(
                            '${p.timeStart} — ${p.timeEnd}\n${p.teacher} ${p.room}'),
                        isThreeLine: true,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          openPair(p);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
