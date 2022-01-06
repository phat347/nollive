import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/Socket/SocketManager.dart';
import 'package:livekit_example/model/appConfig.dart';
import 'package:livekit_example/model/getRoomInfoResponse.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:livekit_example/model/roomRequest.dart';
import 'package:livekit_example/service/ApiService.dart';
import 'package:livekit_example/widgets/text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uni_links/uni_links.dart';
import '../exts.dart';
import '../main.dart';
import '../theme.dart';
import 'room.dart';

const String NOL_SocketEvent = 'NOL Event\n';

bool _initialUriIsHandled = false;

class ConnectPage extends StatefulWidget {
  //
  const ConnectPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {

  Uri? _initialUri;
  Uri? _latestUri;
  Object? _err;

  StreamSubscription? _sub;
  final _scaffoldKey = GlobalKey();

  //
  static const _storeKeyRoomID = 'roomID';
  static const _storeKeyUserName = 'userName';
  static const _storeKeySimulcast = 'simulcast';

  final _roomIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _simulcast = true;
  bool _busy = false;
  bool _isJoinedRoom = false;
  String liveKitToken = '';
  String livekitSocketURL = AppConfig.livekitURL;
  EnterRoomResponse enterRoomRes = EnterRoomResponse('', null);
  bool failedRoom = false;
  String _roomID = '';

  String get _userName {
    return _nameCtrl.text.trim();
  }

  String roomPass = '';
  List<UsersResponse> itemListUser = [];
  Room? room;


  @override
  void initState() {
    super.initState();
    _readPrefs();
    _handleIncomingLinks();
    _handleInitialUri();
  }

  /// Handle incoming links - the ones that the app will recieve from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _sub = uriLinkStream.listen((Uri? uri) {

        if (!mounted) return;
        else if (_latestUri.toString() == uri.toString()) { return; }

        print('got uri: $uri');
        setState(() {
          _latestUri = uri;
          print('latestURI : ${_latestUri}');
          final queryParams = _latestUri?.pathSegments.toList();
          parseUriToRoomid(queryParams);
          _err = null;
        });
      }, onError: (Object err) {
        if (!mounted) return;
        print('got err: $err');
        setState(() {
          _latestUri = null;
          print('latestURI : ${_latestUri}');
          if (err is FormatException) {
            _err = err;
          } else {
            _err = null;
          }
        });
      });
    }
  }
  /// Handle the initial Uri - the one the app was started with
  ///
  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  ///
  /// We handle all exceptions, since it is called from initState.
  Future<void> _handleInitialUri() async {
    // In this example app this is an almost useless guard, but it is here to
    // show we are not going to call getInitialUri multiple times, even if this
    // was a weidget that will be disposed of (ex. a navigation route change).
    if (!_initialUriIsHandled) {
      _initialUriIsHandled = true;
      // _showSnackBar('_handleInitialUri called');
      try {
        final uri = await getInitialUri();
        if (uri == null) {
          print('no initial uri');
        }
        else {
          print('got initial uri: $uri');
        }
        if (!mounted) return;
        setState(() {
          _initialUri = uri;
          final queryParams = _initialUri?.pathSegments.toList();
          // final queryParams = _initialUri?.queryParametersAll.entries.toList();
          parseUriToRoomid(queryParams);
        });
      }
      on PlatformException {
        // Platform messages may fail but we ignore the exception
        print('falied to get initial uri');
      }
      on FormatException catch (err) {
        if (!mounted) return;
        print('malformed initial uri');
        setState(() => _err = err);
      }
    }
  }

  void parseUriToRoomid(List<String>? queryParams) {
    if (queryParams != null) {
      if (queryParams.isNotEmpty) {
        print('Phat room id ${queryParams[1]}');
        _roomIdCtrl.text = queryParams[1];
        _roomID = queryParams[1];
        _showSnackBar('room id: ${queryParams[1]}');
      }
    }
    else {
      print('Phat no deeplink');
    }
  }

  void _showSnackBar(String msg) {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      final context = _scaffoldKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
        ));
      }
    });
  }

  @override
  void dispose() {
    clearData();
    super.dispose();
  }

  void clearData() {
    _roomIdCtrl.dispose();
    _nameCtrl.dispose();

    _sub?.cancel();
    // _latestUri = null;
    // _initialUri = null;
    // _roomID = '';
  }

  void connectToServer(BuildContext ctx) {
    try {

      if (SocketManager.shared.socket != null){
        SocketManager.shared.closeSocket(_roomID);
      }

      SocketManager.shared.connectAndJoinRoom(
          _roomID,
          _userName,
              (roomRes) async { /// Entered Room
            if (roomRes != null) {
              setState(() {
                enterRoomRes = roomRes;
                liveKitToken = enterRoomRes.livekitToken;
                returnList(enterRoomRes.room_info?.users);
              });
              if (!_isJoinedRoom) {
                _isJoinedRoom = true;
                await _connectLiveKitRoom(ctx);
                setState(() {
                  _busy = false;
                });
              }
            }
            else {
              // sendActiveSignal (not use)
              // _socketManager?.emit(WebSocketEvents.iAmInRoom.description, {'room': _roomID});

              // if ((enterRoomRes.room_info?.users.length ?? 0) < (room?.participants.length ?? 0)) {
                // request_enter_room again to get list new name
                SocketManager.shared.socket?.emit(WebSocketEvents.requestEnterRoom.description, {'room': _roomID});
              // }
            }
          },
              () { /// Failed Room
            setState(() {
              failedRoom = true;
              print('setState \nfailedRoom: ${failedRoom}');
            });
          }
      );



    } catch (e) {
      print(e.toString());
      setState(() {
        _busy = false;
      });
    }
  }

  void handleSocketLeftRoom() {
    SocketManager.shared.closeSocket(_roomID);
    _isJoinedRoom = false;
  }

  List<UsersResponse> returnList(Map<String, dynamic>? parsedJson) {
    itemListUser.clear();
    parsedJson?.forEach((k, v) => itemListUser.add(UsersResponse.fromJson(v)));
    return itemListUser;
  }
  // Read saved URL and Token
  Future<void> _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // _roomIdCtrl.text = prefs.getString(_storeKeyRoomID) ?? '';
    _nameCtrl.text = prefs.getString(_storeKeyUserName) ?? '';
    setState(() {
      _simulcast = prefs.getBool(_storeKeySimulcast) ?? true;
    });
  }

  // Save URL and Token
  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // await prefs.setString(_storeKeyRoomID, _roomIdCtrl.text);
    await prefs.setString(_storeKeyUserName, _nameCtrl.text);
    await prefs.setBool(_storeKeySimulcast, _simulcast);
  }

  Future<void> _connect(BuildContext ctx) async {

    setState(() {
      _busy = true;
    });

    if (_roomIdCtrl.text.isEmpty ||
        _nameCtrl.text.isEmpty ||
        _userName.isEmpty) {
      await ctx.showErrorDialog('Hãy nhập đầy đủ thông tin');
      setState(() {
        _busy = false;
      });
      return;
    }
    else if (_roomID.isEmpty && _roomIdCtrl.text.isNotEmpty) {
      _roomID = _roomIdCtrl.text.split('/').last.trim();
    }

    // RoomRequest _requestRoom = RoomRequest(_roomID);
    try {
      GetRoomInfoResponse _roomInfoRes = await ApiService.create().getSingleRoomInfo(_roomID);

      if (_roomInfoRes.status != 'OK') {
        await ctx.showErrorDialog('Không thể lấy thông tin phòng!');
        setState(() {
          _busy = false;
        });
        return;
      }
      else if (_roomInfoRes.roomInfo.room_private == 1){
        roomPass = await ctx.showInputDialog('Nhập mật khẩu') ?? '';
      }
      connectToServer(ctx);
    }
    catch(e) {
      print('Error to get Room Info: ${e}');
      setState(() {
        _busy = false;
      });
    }

  }

  Future<void> _connectLiveKitRoom(BuildContext ctx) async {
    //
    try {

      // Save URL and Token for convenience
      await _writePrefs();

      print('Connecting with roomID: ${_roomID}, '
          'token: ${liveKitToken}...');

      // create custom video config
      const customParameter =  VideoParameters(
        description: 'FHD(1080x1920) 9:16',
        dimensions: VideoDimensions(1080, 1920),
        encoding: VideoEncoding(
          maxBitrate: 3000000,
          maxFramerate: 30,
        ),
      );
      // Try to connect to a room
      // This will throw an Exception if it fails for any reason.

      room = await LiveKitClient.connect(
        AppConfig.livekitURL,
        liveKitToken,
        roomOptions: RoomOptions(
          defaultCameraCaptureOptions: const CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            params: customParameter
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoEncoding: customParameter.encoding,
            simulcast: _simulcast,
          ),
        ),
      );

      await Navigator.push<void>(
        ctx,
        MaterialPageRoute(
            builder: (_) => RoomPage(
              room: room!,
              itemListUser: itemListUser,
              onDisconnected: (() {
                print('\n\nRoomPage onDisconnected\n\n');
                handleSocketLeftRoom();
              }),
            )
        ),
      );
    }
    catch (error) {
      print('Could not connect $error');
      await ctx.showErrorDialog('Phòng này hiện đã hết hạn hoặc không tồn tại!');
      setState(() {
        _busy = false;
      });
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

  Future<void> _checkFailedRoom(BuildContext context) async {
    if (failedRoom == true) {
      String mess = 'Phòng này hiện đã hết hạn hoặc không tồn tại!';
      if (rootContext != null && rootContext != context) {
        await rootContext?.showErrorDialog(mess);
        Navigator.pop(rootContext!);
      }
      else {
        await context.showErrorDialog(mess);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    // final queryParams = _initialUri?.pathSegments.toList();
    rootContext = context;

    Future.delayed(const Duration(milliseconds: 500), () {
      _checkFailedRoom(context);
    });

    return Scaffold(
      key: _scaffoldKey,
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
                    Visibility(
                      visible: false,
                      child: Padding(
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
                          const Text('Vào phòng'),
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
