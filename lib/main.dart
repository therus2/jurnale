import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'monday.dart' as monday;
import 'tuesday.dart' as tuesday;
import 'wednesday.dart' as wednesday;
import 'thursday.dart' as thursday;
import 'friday.dart' as friday;
import 'saturday.dart' as saturday;
import 'sunday.dart' as sunday;

int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ИП-152 Расписание',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
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
    setState((){});
  }

  void openToday() {
    switch(todayWeekday) {
      case 1: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>monday.DayScreen())); break;
      case 2: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>tuesday.DayScreen())); break;
      case 3: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>wednesday.DayScreen())); break;
      case 4: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>thursday.DayScreen())); break;
      case 5: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>friday.DayScreen())); break;
      case 6: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>saturday.DayScreen())); break;
      case 7: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>sunday.DayScreen())); break;
    }
  }

  void openTomorrow() {
    int tomorrow = todayWeekday + 1;
    if (tomorrow > 7) tomorrow = 1; // если воскресенье → понедельник

    switch (tomorrow) {
      case 1: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>monday.DayScreen())); break;
      case 2: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>tuesday.DayScreen())); break;
      case 3: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>wednesday.DayScreen())); break;
      case 4: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>thursday.DayScreen())); break;
      case 5: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>friday.DayScreen())); break;
      case 6: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>saturday.DayScreen())); break;
      case 7: Navigator.of(context).push(MaterialPageRoute(builder: (_)=>sunday.DayScreen())); break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ИП-152 — Расписание')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Color.fromARGB(255, 234, 228, 255),
              child: Column(
                children: [
                  ListTile(
                    title: Text(weekType, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Сегодня: $todayName'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: openToday,
                        child: Text('Открыть сегодня'),
                      ),
                      ElevatedButton(
                        onPressed: openTomorrow,
                        child: Text('Открыть завтра'),
                      ),

                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height:12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3/2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>monday.DayScreen())),
                      child: Text('Понедельник', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>tuesday.DayScreen())),
                      child: Text('Вторник', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>wednesday.DayScreen())),
                      child: Text('Среда', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>thursday.DayScreen())),
                      child: Text('Четверг', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>friday.DayScreen())),
                      child: Text('Пятница', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                  ElevatedButton(
                      onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder: (_)=>saturday.DayScreen())),
                      child: Text('Суббота', style: TextStyle(fontSize: 17),),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color.fromARGB(255, 234, 228, 255)),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
