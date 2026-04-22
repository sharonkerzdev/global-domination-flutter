import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FallbackErrorWidget extends StatelessWidget {
  const FallbackErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: SystemNavigator.pop,
                child: const Text('Restart'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
