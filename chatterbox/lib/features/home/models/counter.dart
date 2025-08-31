import 'package:flutter/material.dart';

class Counter extends ChangeNotifier {
  int count = 0;

  Counter({required this.count});

  void increment() {
    count++;
    notifyListeners();
  }

  void decrement() {
    count--;
    notifyListeners();
  }
}
