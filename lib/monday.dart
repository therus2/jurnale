import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'pair_detail.dart'; // <<< ИМПОРТИРУЕМ PairItem ИЗ pair_detail.dart >>>

// <<< УБРАНО: class PairItem {...} (теперь используется из pair_detail.dart) >>>

// <<< УБРАНО: int getWeekNumber(...) (теперь используется из main.dart или вынести в отдельный файл) >>>

class DayScreen extends StatefulWidget {
  @override
  _DayScreenState createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool loading = true;
  List<PairItem> pairs = [];
  final String filename = 'assets/data/monday.json';

  @override
  void initState() {
    super.initState();
    loadDay();
  }

  // <<< ИСПРАВЛЕННАЯ И ОБНОВЛЁННАЯ ФУНКЦИЯ loadDay() >>>
  Future<void> loadDay() async {
    print('=== loadDay() called ==='); // <-- Отладка
    setState(() => loading = true);

    try {
      // Загружаем raw JSON строку
      String raw = await rootBundle.loadString(filename);
      print('File loaded, length: ${raw.length}'); // <-- Отладка
      // print('File content: $raw'); // <-- Закомментировано, чтобы не засорять лог

      // Декодируем в List
      List<dynamic> arr = json.decode(raw);
      print('Decoded array type: ${arr.runtimeType}'); // <-- Отладка
      print('Decoded array length: ${arr.length}'); // <-- Отладка
      // print('Decoded array: $arr'); // <-- Закомментировано, чтобы не засорять лог

      // Получаем тип недели
      DateTime today = DateTime.now();
      int weekOfYear = getWeekNumber(today); // <-- Убедись, что getWeekNumber доступна
      String weekType = (weekOfYear % 2 == 0) ? 'even' : 'odd';
      print('Current week type: $weekType'); // <-- Отладка

      // Получаем номер группы
      SharedPreferences sp = await SharedPreferences.getInstance();
      int group = sp.getInt('groupNumber') ?? 1;
      print('User group number: $group'); // <-- Отладка

      // Фильтруем пары по неделе и группе
      pairs = arr
          .map((e) => PairItem.fromMap(e))
          .where((p) {
        bool weekMatch = (p.week == 'both' || p.week == weekType);
        bool groupMatch = (p.group == 'both' || p.group == group.toString());
        bool matches = weekMatch && groupMatch;
        print('Pair: ${p.subject}, Week: ${p.week}, Group: ${p.group}, Matches: $matches'); // <-- Отладка
        return matches;
      })
          .toList();

      print('Filtered pairs count: ${pairs.length}'); // <-- Отладка

    } catch (e) {
      print('Error in loadDay: $e'); // <-- Отладка
      pairs = []; // На случай ошибки
    }

    // Один вызов setState в конце
    setState(() {
      loading = false;
    });
  }


  void openPair(PairItem p) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PairDetailPage(pair: p, dayFile: 'monday.json')));
    await loadDay(); // Перезагружаем расписание после возврата из заметок
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Понедельник')),
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

// <<< УБРАНО: int getWeekNumber(...) (теперь должно быть в main.dart или общем файле) >>>