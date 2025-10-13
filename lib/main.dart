import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'group_select.dart';

import 'monday.dart' as monday;
import 'tuesday.dart' as tuesday;
import 'wednesday.dart' as wednesday;
import 'thursday.dart' as thursday;
import 'friday.dart' as friday;
import 'saturday.dart' as saturday;
import 'sunday.dart' as sunday;

// ===== Функция расчёта номера недели =====
int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}

// ===== Точка входа =====
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);

  SharedPreferences sp = await SharedPreferences.getInstance();
  int? group = sp.getInt('groupNumber');

  runApp(MyApp(startOnSelect: group == null));
}

// ===== Корневой виджет =====
class MyApp extends StatelessWidget {
  final bool startOnSelect;
  const MyApp({super.key, required this.startOnSelect});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ИП-152 Расписание',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: startOnSelect ? GroupSelectPage() : HomePage(),
    );
  }
}

// ===== Главная страница расписания =====
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String weekType = '';
  String todayName = '';
  int todayWeekday = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    determineWeek();
  }

  void determineWeek() {
    DateTime now = DateTime.now();
    int weekOfYear = getWeekNumber(now);
    weekType = (weekOfYear % 2 == 0) ? 'Чётная неделя' : 'Нечётная неделя';
    todayName = DateFormat.EEEE('ru').format(now);
    setState(() {});
  }

  void openToday() {
    switch (todayWeekday) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => sunday.DayScreen()));
        break;
    }
  }

  void openTomorrow() {
    int tomorrow = todayWeekday + 1;
    if (tomorrow > 7) tomorrow = 1;

    switch (tomorrow) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => sunday.DayScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ИП-152 — Расписание')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color.fromARGB(255, 234, 228, 255),
              child: Column(
                children: [
                  ListTile(
                    title: Text(weekType, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Сегодня: $todayName'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          openToday();
                        },
                        child: const Text('Открыть сегодня'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          openTomorrow();
                        },
                        child: const Text('Открыть завтра'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3 / 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _dayButton('Понедельник', monday.DayScreen()),
                  _dayButton('Вторник', tuesday.DayScreen()),
                  _dayButton('Среда', wednesday.DayScreen()),
                  _dayButton('Четверг', thursday.DayScreen()),
                  _dayButton('Пятница', friday.DayScreen()),
                  _dayButton('Суббота', saturday.DayScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayButton(String label, Widget page) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(const Color.fromARGB(255, 234, 228, 255)),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }
}
