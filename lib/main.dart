import 'package:flutter/material.dart';
import 'package:livekit_example/theme.dart';
import 'package:logging/logging.dart';

import 'pages/connect.dart';

void main() {
  // configure logs for debugging
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  runApp(const NolApp());
}

class NolApp extends StatelessWidget {
  //
  const NolApp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Nol App',
      theme: NolTheme().buildThemeData(context),
      home: const ConnectPage(),
    );
}
