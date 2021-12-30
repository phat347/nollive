import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/model/appConfig.dart';
import 'package:livekit_example/model/getRoomInfoResponse.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:livekit_example/model/roomRequest.dart';
import 'package:livekit_example/service/ApiService.dart';
import 'package:livekit_example/widgets/text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';
import '../exts.dart';
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
  static const _storeKeyRoomID = 'roomID';
  static const _storeKeyUserName = 'userName';
  static const _storeKeySimulcast = 'simulcast';

  final _roomIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _simulcast = true;
  bool _busy = false;
  String liveKitToken = '';
  String livekitSocketURL = AppConfig.livekitURL;
  EnterRoomResponse enterRoomRes = EnterRoomResponse('', null);
  bool failedRoom = false;

  String get _roomID {
    String splitRoomId = _roomIdCtrl.text.split('/').last.trim();
    return splitRoomId;
  }

  String get _userName {
    return _nameCtrl.text.trim();
  }

  String roomPass = '';

  @override
  void initState() {
    super.initState();
    _readPrefs();
  }

  @override
  void dispose() {
    _roomIdCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void connectToServer(BuildContext ctx) {
    try {

      // Configure socket transports must be sepecified

      IO.Socket socket = IO.io(AppConfig.socketURL,
          OptionBuilder()
              .setTransports(['websocket']) // for Flutter or Dart VM
              .disableAutoConnect() // disable auto-connection
              .setAuth({'fullname': _userName,'jwt': ''}) // optional
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
              enterRoomRes = EnterRoomResponse.fromJson(jsonDecode(data));
              liveKitToken = enterRoomRes.livekitToken;
              print('${NOL_SocketEvent} log liveKitToken: liveKitToken');
              _connectLiveKitRoom(ctx);
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
    _roomIdCtrl.text = 'https://nol-v2.hatto.com/r/c2a7e8d2-1ce7-46f7-a5f3-df7232bdcd66';//prefs.getString(_storeKeyRoomID) ?? '';
    _nameCtrl.text = prefs.getString(_storeKeyUserName) ?? '';
    setState(() {
      _simulcast = prefs.getBool(_storeKeySimulcast) ?? true;
    });
  }

  // Save URL and Token
  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKeyRoomID, _roomIdCtrl.text);
    await prefs.setString(_storeKeyUserName, _nameCtrl.text);
    await prefs.setBool(_storeKeySimulcast, _simulcast);
  }

  Future<void> _connect(BuildContext ctx) async {
    if (_roomIdCtrl.text.isEmpty ||
        _nameCtrl.text.isEmpty ||
        _roomID.isEmpty ||
        _userName.isEmpty) {
      await ctx.showErrorDialog('Hãy nhập đầy đủ thông tin');
      return;
    }

    // RoomRequest _requestRoom = RoomRequest(_roomID);
    GetRoomInfoResponse _roomInfoRes = await ApiService.create().getSingleRoomInfo(_roomID);
    if (_roomInfoRes.status != 'OK') {
      await ctx.showErrorDialog('Không thể lấy thông tin phòng!');
      return;
    }
    else if (_roomInfoRes.roomInfo.room_private == 1){
      roomPass = await ctx.showInputDialog('Nhập mật khẩu') ?? '';
    }
    connectToServer(ctx);
  }

  Future<void> _connectLiveKitRoom(BuildContext ctx) async {
    //
    try {
      setState(() {
        _busy = true;
      });

      // Save URL and Token for convenience
      await _writePrefs();

      print('Connecting with roomID: ${_roomIdCtrl.text}, '
          'user name: ${_nameCtrl.text}...');

      // Try to connect to a room
      // This will throw an Exception if it fails for any reason.
      final room = await LiveKitClient.connect(
        _roomIdCtrl.text,
        _nameCtrl.text,
        roomOptions: RoomOptions(
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: _simulcast,
          ),
        ),
      );

      await Navigator.push<void>(
        ctx,
        MaterialPageRoute(
            builder: (_) => RoomPage(room, enterRoomRes)
        ),
      );
    }
    catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog('Phòng này hiện đã hết hạn hoặc không tồn tại!');
    }
    finally {
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
                      padding: const EdgeInsets.only(bottom: 50),
                      child: SvgPicture.asset(
                        'images/nol-logo.svg',
                        width: 180,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: NolTextField(
                        label: 'Nhập địa chỉ phòng',
                        placeHolder: 'Hãy nhập đường dẫn hoặc id địa chỉ phòng',
                        inputType: TextInputType.url,
                        ctrl: _roomIdCtrl,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: NolTextField(
                        label: 'Nhập tên',
                        placeHolder: 'Hãy nhập tên',
                        ctrl: _nameCtrl,
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
                            activeTrackColor: NolColors.lkBlue,
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
