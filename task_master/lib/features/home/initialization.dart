import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/counter.dart';

final counterObject = ChangeNotifierProvider<Counter>((ref){
  return Counter(count: 0);
});