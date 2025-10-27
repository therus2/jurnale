import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'pair_detail.dart';
import 'dart:math' as math;

class DayScreen extends StatefulWidget {
  @override
  _DayScreenState createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool loading = true;
  List<PairItem> pairs = [];
  final String filename = 'assets/data/monday.json';
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
    await prefs.setString('weekType', weekType);
    setState(() {
      _weekType = weekType;
    });
    if (_scaffoldKey.currentState!.isEndDrawerOpen) {
      Navigator.of(context).pop();
    }
    await loadDay();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Выбрана ${weekType == 'odd' ? 'нечётная' : 'чётная'} неделя')),
    );
  }

  Widget _buildDrawer() {
    String currentWeekType = _getCurrentWeekTypeDisplay();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 234, 228, 255),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 48, color: Colors.red),
                SizedBox(height: 8),
                Text('Понедельник', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Подгруппа: $_groupNumber', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                SizedBox(height: 4),
                Text('Неделя: $currentWeekType', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ),
          ),

          // Выбор подгруппы
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выбери подгруппу:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(Icons.group, color: _groupNumber == 1 ? Colors.blue : Colors.grey),
            title: Text('1 Подгруппа', style: TextStyle(
              fontWeight: _groupNumber == 1 ? FontWeight.bold : FontWeight.normal,
              color: _groupNumber == 1 ? Colors.blue : Colors.black,
            )),
            trailing: _groupNumber == 1 ? Icon(Icons.check, color: Colors.blue) : null,
            onTap: () => _selectGroup(1),
          ),
          ListTile(
            leading: Icon(Icons.group, color: _groupNumber == 2 ? Colors.green : Colors.grey),
            title: Text('2 Подгруппа', style: TextStyle(
              fontWeight: _groupNumber == 2 ? FontWeight.bold : FontWeight.normal,
              color: _groupNumber == 2 ? Colors.green : Colors.black,
            )),
            trailing: _groupNumber == 2 ? Icon(Icons.check, color: Colors.green) : null,
            onTap: () => _selectGroup(2),
          ),

          Divider(),

          // Выбор типа недели
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Выбери тип недели:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(
              Icons.autorenew,
              color: _weekType == null ? Colors.blue : Colors.grey,
            ),
            title: Text(
              'Авто (текущая)',
              style: TextStyle(
                fontWeight: _weekType == null ? FontWeight.bold : FontWeight.normal,
                color: _weekType == null ? Colors.blue : Colors.black,
              ),
            ),
            trailing: _weekType == null ? Icon(Icons.check, color: Colors.blue) : null,
            onTap: () => _selectWeekType('auto'),
          ),
          ListTile(
            leading: Icon(
              Icons.filter_1,
              color: _weekType == 'odd' ? Colors.orange : Colors.grey,
            ),
            title: Text(
              'Нечётная',
              style: TextStyle(
                fontWeight: _weekType == 'odd' ? FontWeight.bold : FontWeight.normal,
                color: _weekType == 'odd' ? Colors.orange : Colors.black,
              ),
            ),
            trailing: _weekType == 'odd' ? Icon(Icons.check, color: Colors.orange) : null,
            onTap: () => _selectWeekType('odd'),
          ),
          ListTile(
            leading: Icon(
              Icons.filter_2,
              color: _weekType == 'even' ? Colors.purple : Colors.grey,
            ),
            title: Text(
              'Чётная',
              style: TextStyle(
                fontWeight: _weekType == 'even' ? FontWeight.bold : FontWeight.normal,
                color: _weekType == 'even' ? Colors.purple : Colors.black,
              ),
            ),
            trailing: _weekType == 'even' ? Icon(Icons.check, color: Colors.purple) : null,
            onTap: () => _selectWeekType('even'),
          ),
          Divider(),
        ],
      ),
    );
  }

  String _getCurrentWeekTypeDisplay() {
    if (_weekType == null) {
      DateTime today = DateTime.now();
      int weekOfYear = getWeekNumber(today);
      return (weekOfYear % 2 == 0) ? 'Чётная (авто)' : 'Нечётная (авто)';
    } else if (_weekType == 'odd') {
      return 'Нечётная';
    } else {
      return 'Чётная';
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
        bool groupMatch = (p.group == 'both' || p.group == group.toString());
        return weekMatch && groupMatch;
      })
          .toList();
    } catch (e) {
      pairs = [];
    }
    setState(() => loading = false);
  }

  void openPair(PairItem p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PairDetailPage(pair: p, dayFile: 'monday.json')));
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
            Text('Понедельник'),
            Text(
              weekTypeDisplay,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () { Navigator.of(context).popUntil((route) => route.isFirst); },
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
            color: Color.fromARGB(255, 234, 228, 255),
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text('${p.index}. ${p.subject}'),
              subtitle: Text('${p.timeStart} — ${p.timeEnd}\n${p.teacher} ${p.room}'),
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