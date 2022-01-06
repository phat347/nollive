
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/model/appConfig.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:livekit_example/pages/connect.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum WebSocketEvents {

  /// sent
  requestEnterRoom,
  leaveRoom,

  muteSeftAudioVideo,
  iAmInRoom,

  /// Recieve
  enteredRoom,
  failedRoom,
  leftRoom,
  userStatusChange,


  /// Ping Pong
  areYouThere,
  iAmHere

}

extension WebSocketEventsExtentsion on WebSocketEvents {
  String get rawValue => describeEnum(this);

  String get description {
    switch (this) {

      case WebSocketEvents.requestEnterRoom:
        return 'request_enter_room';

      case WebSocketEvents.failedRoom:
        return 'failed_room';

      case WebSocketEvents.leftRoom:
        return 'left_room';

      case WebSocketEvents.enteredRoom:
        return 'entered_room';

      case WebSocketEvents.leaveRoom:
        return 'leave_room';

      case WebSocketEvents.muteSeftAudioVideo:
        return 'mute_self_audio_video';

      case WebSocketEvents.iAmInRoom:
        return 'i_am_in_room';

      case WebSocketEvents.userStatusChange:
        return 'user_status_change';

      case WebSocketEvents.areYouThere:
        return 'AREYOUTHERE';

      case WebSocketEvents.iAmHere:
        return 'IAMHERE';

      default:
        return '';
    }
  }
}

typedef OnEnteredRoom = void Function(EnterRoomResponse?);
typedef OnFailedRoom = void Function();

class SocketManager {
  static SocketManager shared = SocketManager();

  IO.Socket? socket;
  bool isDisconnectedSocket = true;

  void connectAndJoinRoom( String roomId, String name, OnEnteredRoom enteredRoom, OnFailedRoom failedRoom) {
// Configure socket transports must be sepecified
    socket = IO.io(AppConfig.socketURL,
        IO.OptionBuilder()
            .setTransports(['websocket']) // for Flutter or Dart VM
            .disableAutoConnect() // disable auto-connection
            .setAuth({'fullname': name,'jwt': ''}) // optional
            .build()
    );

    socket?.connect();

    isDisconnectedSocket = false;

    // Handle socket events
    socket?.onConnect((data) {
      print('${NOL_SocketEvent} connect to Socket: ${data.toString()}');

      //request_enter_room
      socket?.emit(WebSocketEvents.requestEnterRoom.description, {'room': roomId});
    });

    // socket?.on('connected', (data) {
    //   print('${NOL_SocketEvent} connected: ${data.toString()}');
    // });

    socket?.on(WebSocketEvents.failedRoom.description,
            (data) {
          print('${NOL_SocketEvent} failed_room: ${data.toString()}');
          FailedRoomResponse _failedRoom = FailedRoomResponse.fromJson(jsonDecode(data));
          print('_failedRoom: ${_failedRoom..status} - ${_failedRoom.message}');
          if (_failedRoom.status == 'FAILED' && _failedRoom.message == 'INVALID_ROOM') {
            failedRoom();
          }
        }
    );

    //call back entered_room
    socket?.on(
        WebSocketEvents.enteredRoom.description,
            (data) {
          print('${NOL_SocketEvent} entered_room: ${data.toString()}');
          final Map<String, dynamic> jsonData = jsonDecode(data);

          if (jsonData.keys.contains('livekit_token')) {
            print('${NOL_SocketEvent} log have liveKitToken');
            var enterRoomRes = EnterRoomResponse.fromJson(jsonData);
            var liveKitToken = enterRoomRes.livekitToken;
            print('${NOL_SocketEvent} log liveKitToken: ${liveKitToken}');

            enteredRoom(enterRoomRes);
          }
          else {
            print('${NOL_SocketEvent} log new participant entered room: ${jsonData.toString()}');
            enteredRoom(null);
          }
        }
    );

    socket?.on(
        WebSocketEvents.userStatusChange.description,
            (data) {
          print('${WebSocketEvents.userStatusChange.description}: ${data.toString()}');
        }
    );

    socket?.on(
        WebSocketEvents.areYouThere.description,
            (data) {
          print('${NOL_SocketEvent} ${WebSocketEvents.areYouThere.description}');
          print('${NOL_SocketEvent} ${WebSocketEvents.areYouThere.description} ${data.toString()}');

          if (SocketManager.shared.isDisconnectedSocket) { return; }

          socket?.emit(WebSocketEvents.iAmHere.description, data);
        }
    );

    socket?.on(
        WebSocketEvents.leftRoom.description,
            (data) {
          print('${NOL_SocketEvent} left_room');
          print('${NOL_SocketEvent} left_room ${data.toString()}');
        }
    );

    socket?.onPing((data) {
      print('${NOL_SocketEvent} onPing: ${data.toString()}');
    });

    socket?.onDisconnect((_) {
      print('${NOL_SocketEvent} disconnect');
      socket?.close();
      socket?.dispose();
      socket?.destroy();
    });

  }

  void updateOnOffVideo(bool isOn, LocalParticipant participant) {
    print('${WebSocketEvents.muteSeftAudioVideo.description}: ${isOn}');
    socket?.emit(
        WebSocketEvents.muteSeftAudioVideo.description,
        {
          'sid': participant.sid,
          'channel': 'video',
          'status': isOn ? 'on' : 'off'
        }
    );
  }

  void  updateOnOffAudio(bool isOn, LocalParticipant participant) {
    socket?.emit(
        WebSocketEvents.muteSeftAudioVideo.description,
        {
          'sid': participant.sid,
          'channel': 'audio',
          'status': isOn ? 'on' : 'off'
        }
    );
  }

  void _closeAll() {
    socket?.disconnect();
    socket?.close();
    socket?.dispose();
    socket?.destroy();
    socket = null;
  }

  void closeSocket(String roomId) {
    try {
      socket?.emit(WebSocketEvents.leaveRoom.description, {'room': roomId});
      _closeAll();
      isDisconnectedSocket = true;
    }
    catch(e) {
      print('Socket Disconnect Error ${e}');
    }
  }

}