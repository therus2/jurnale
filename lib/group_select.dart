import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupSelectPage extends StatefulWidget {
  @override
  _GroupSelectPageState createState() => _GroupSelectPageState();
}

class _GroupSelectPageState extends State<GroupSelectPage> {
  Future<void> _selectGroup(int groupNumber) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt('groupNumber', groupNumber);

    // Просто возвращаемся на предыдущий экран (главный)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school,
                size: 80,
                color: Color.fromARGB(255, 234, 228, 255),
              ),
              SizedBox(height: 20),
              Text(
                'Добро пожаловать!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Выбери свою подгруппу:',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _selectGroup(1),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 70),
                  backgroundColor: Color.fromARGB(255, 234, 228, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group, size: 30, color: Colors.blue),
                    SizedBox(height: 8),
                    Text('1 Подгруппа', style: TextStyle(fontSize: 20, color: Colors.black87)),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _selectGroup(2),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 70),
                  backgroundColor: Color.fromARGB(255, 234, 228, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group, size: 30, color: Colors.green),
                    SizedBox(height: 8),
                    Text('2 Подгруппа', style: TextStyle(fontSize: 20, color: Colors.black87)),
                  ],
                ),
              ),
              SizedBox(height: 30),
              Text(
                'Этот выбор можно будет изменить позже в настройках',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Временный класс HomePage для навигации
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ИП-152 Расписание')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Загрузка...'),
          ],
        ),
      ),
    );
  }
}