import 'package:chatterbox/features/chat/chatpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/interestsUi.dart';


class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                showInterestsBottomSheet(context);
              },
              child: Text('LOAD INTERESTS'),
            ),
            SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      // Use Navigator.push
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(title: 'Chat with Stranger'),
                      ), // Construct ChatPage here
                    );
                  },
                  child: Text('TEXT'),
                ),
                SizedBox(width: 12.0),
                ElevatedButton(
                  onPressed: () => ChatPage(),
                  child: Text('VIDEO'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
