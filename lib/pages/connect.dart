import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:livekit_example/widgets/text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';
import '../exts.dart';
import '../main.dart';
import '../theme.dart';
import 'room.dart';

const String NOL_SocketEvent = 'NOL Event\n';

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
  String liveKitToken = '';
  String socketURL = 'wss://demo.nol.live:443/sfu';
  EnterRoomResponse enterRoomRes = EnterRoomResponse('', null);
  bool failedRoom = false;

  @override
  void initState() {
    connectToServer();
    super.initState();
    _readPrefs();
  }

  @override
  void dispose() {
    _uriCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void connectToServer() {
    try {

      // Configure socket transports must be sepecified

      IO.Socket socket = IO.io('wss://demo.nol.live:443/',
          OptionBuilder()
              .setTransports(['websocket']) // for Flutter or Dart VM
              .disableAutoConnect() // disable auto-connection
              .setAuth({'fullname': 'Hung Native 123','jwt': ''}) // optional
              .build()
      );

      socket.connect();

      // Handle socket events
      socket.onConnect((data) {
        print('${NOL_SocketEvent} connect to Socket: ${data.toString()}');

        //request_enter_room
        socket.emit('request_enter_room', {'room': '89475597-2f6d-4096-8b92-0bc51ddb5cc1'});
      });
      
      socket.on('connected', (data) {
        print('${NOL_SocketEvent}connected: ${data.toString()}');
      });

      socket.on('failed_room',
              (data) {
            print('${NOL_SocketEvent} failed_room: ${data.toString()}');
            FailedRoomResponse _failedRoom = FailedRoomResponse.fromJson(jsonDecode(data));
            print('_failedRoom: ${_failedRoom..status} - ${_failedRoom.message}');
            if (_failedRoom.status == 'FAILED' && _failedRoom.message == 'INVALID_ROOM') {

              setState(() {
                failedRoom = true;
                print('setState \nfailedRoom: ${failedRoom}');
              });
            }
          }
      );

      //call back entered_room
      socket.on(
          'entered_room',
              (data) {
            print('${NOL_SocketEvent} entered_room: ${data.toString()}');
            final Map<String, dynamic> jsonData = jsonDecode(data);
            if (jsonData.keys.contains('livekit_token')) {
              setState(() {
                enterRoomRes = EnterRoomResponse.fromJson(jsonDecode(data));
                liveKitToken = enterRoomRes.livekitToken;
                print('${NOL_SocketEvent} log liveKitToken: liveKitToken');
                _readPrefs();
              });
            }

          }
      );

      socket.on(
          'AREYOUTHERE',
              (data) {
            print('${NOL_SocketEvent} AREYOUTHERE');
            print('${NOL_SocketEvent} AREYOUTHERE ${data.toString()}');
            socket.emit('IAMHERE', data);
          }
      );

      socket.onPing((data) {
        print('${NOL_SocketEvent} onPing: ${data.toString()}');
      });

      socket.onDisconnect((_) => {
        print('${NOL_SocketEvent} disconnect')
      });


    } catch (e) {
      print(e.toString());
    }


  }

  // Read saved URL and Token
  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _uriCtrl.text = socketURL;//prefs.getString(_storeKeyUri) ?? '';
    _tokenCtrl.text = liveKitToken;//prefs.getString(_storeKeyToken) ?? '';
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
        MaterialPageRoute(builder: (_) => RoomPage(room, enterRoomRes)),
      );
    } catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog('Phòng này hiện đã hết hạn hoặc không tồn tại!');
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

  Future<void> _checkFailedRoom(BuildContext context) async{
    if (failedRoom == true) {
      await context.showErrorDialog('Phòng này hiện đã hết hạn hoặc không tồn tại!');
    }
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkFailedRoom(context);
    });

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                      padding: const EdgeInsets.only(bottom: 70),
                      child: SvgPicture.asset(
                        'images/logo-dark.svg',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: LKTextField(
                        label: 'Server URL',
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
                            activeTrackColor: LKColors.lkBlue,
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
                          const Text('CONNECT'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
