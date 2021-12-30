import 'package:flutter/material.dart';
import 'package:livekit_example/theme.dart';
import 'package:logging/logging.dart';

import 'pages/connect.dart';

void main() {
  // Nếu bắt Charles thì bật
  // if (!kReleaseMode) {
  //   // For Android devices you can also allowBadCertificates: true below, but you should ONLY do this when !kReleaseMode
  //   final proxy = CustomProxy(
  //       ipAddress: "192.168.0.100", port: 8888, allowBadCertificates: true);
  //   proxy.enable();
  // }
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
