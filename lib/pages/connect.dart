import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/widgets/text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exts.dart';
import '../theme.dart';
import 'room.dart';

class ConnectPage extends StatefulWidget {
  //
  const ConnectPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  //
  static const _storeKeyUri = 'uri';
  static const _storeKeyToken = 'token';
  static const _storeKeySimulcast = 'simulcast';

  final _uriCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _simulcast = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _readPrefs();
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // Read saved URL and Token
  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _uriCtrl.text = 'wss://demo.nol.live:443/sfu'; //prefs.getString(_storeKeyUri) ?? '';
    _tokenCtrl.text = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ2aWRlbyI6eyJyb29tQ3JlYXRlIjpmYWxzZSwicm9vbUpvaW4iOnRydWUsInJvb21MaXN0IjpmYWxzZSwicm9vbVJlY29yZCI6dHJ1ZSwicm9vbUFkbWluIjpmYWxzZSwicm9vbSI6Ijg4MzBiZDNlLTlmMjUtNGY4MC05ZjNhLTZlZDIzNmY3MTY2ZSIsImNhblB1Ymxpc2giOnRydWUsImNhblN1YnNjcmliZSI6dHJ1ZSwiY2FuUHVibGlzaERhdGEiOmZhbHNlLCJoaWRkZW4iOmZhbHNlfSwibWV0YWRhdGEiOiIiLCJzaGEyNTYiOiI5YTI2MzdhNy1lMmM4LTQ4MTEtYmQ1NS02MWVkMGNiMGM1MWMiLCJpc3MiOiJBUEl5cENIVHdvb3FZeDYiLCJleHAiOjE2NDA3NjMzNjgsIm5iZiI6MCwic3ViIjoiR0gtc2ZBVTBfNXVDQ3RHNkFBQkIiLCJqd3RpZCI6IkdILXNmQVUwXzV1Q0N0RzZBQUJCIn0.RUnYJOYNYLSI6fqBoG72HtcSAXUH3PwV2TEgCOBVGFM';// prefs.getString(_storeKeyToken) ?? '';
    setState(() {
      _simulcast = prefs.getBool(_storeKeySimulcast) ?? true;
    });
  }

  // Save URL and Token
  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKeyUri, _uriCtrl.text);
    await prefs.setString(_storeKeyToken, _tokenCtrl.text);
    await prefs.setBool(_storeKeySimulcast, _simulcast);
  }

  Future<void> _connect(BuildContext ctx) async {
    //
    try {
      setState(() {
        _busy = true;
      });

      // Save URL and Token for convenience
      await _writePrefs();

      print('Connecting with url: ${_uriCtrl.text}, '
          'token: ${_tokenCtrl.text}...');

      // Try to connect to a room
      // This will throw an Exception if it fails for any reason.
      final room = await LiveKitClient.connect(
        _uriCtrl.text,
        _tokenCtrl.text,
        roomOptions: RoomOptions(
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: _simulcast,
          ),
        ),
      );

      await Navigator.push<void>(
        ctx,
        MaterialPageRoute(builder: (_) => RoomPage(room)),
      );
    } catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog(error);
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  void _setSimulcast(bool? value) async {
    if (value == null || _simulcast == value) return;
    setState(() {
      _simulcast = value;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50, top: 10),
                    child: SvgPicture.asset(
                      'images/nol-logo.svg',
                      height: 65,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'Server Socket URL',
                      ctrl: _uriCtrl,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25),
                    child: LKTextField(
                      label: 'Token',
                      ctrl: _tokenCtrl,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Simulcast'),
                        Switch(
                          value: _simulcast,
                          onChanged: (value) => _setSimulcast(value),
                          inactiveTrackColor: Colors.white.withOpacity(.2),
                          activeTrackColor: NolColors.greenyBlue,
                          inactiveThumbColor: Colors.white.withOpacity(.5),
                          activeColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : () => _connect(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        const Text('Kết nối'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
