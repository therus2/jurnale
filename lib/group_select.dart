import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class GroupSelectPage extends StatefulWidget {
  @override
  _GroupSelectPageState createState() => _GroupSelectPageState();
}

class _GroupSelectPageState extends State<GroupSelectPage> {
  Future<void> _selectGroup(int groupNumber) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setInt('groupNumber', groupNumber);
    Navigator.pushReplacement(
      context,
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
              Text(
                'Выбери свою подгруппу:',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _selectGroup(1),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 60),
                  backgroundColor: Color.fromARGB(255, 234, 228, 255),
                ),
                child: Text('1 Подгруппа', style: TextStyle(fontSize: 20)),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _selectGroup(2),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 60),
                  backgroundColor: Color.fromARGB(255, 234, 228, 255),
                ),
                child: Text('2 Подгруппа', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
