import 'package:flutter/material.dart';

void main() {

  runApp(clothing());}

class clothing extends StatefulWidget{
  @override
  State<StatefulWidget> createState() => _clothingstate();
}
class _clothingstate extends State<clothing> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('STYLES'),
          ),
          body:
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('graphics/bg.jpg'),
                opacity: 0.8,
                fit: BoxFit.cover,
              ),
            ),
          )
      ),
    );
  }
}