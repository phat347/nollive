import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

class GetRoomInfoResponse extends ChangeNotifier {
  String status;
  InfoRoomResponse roomInfo;

  GetRoomInfoResponse(
      this.status,
      this.roomInfo
      );

  GetRoomInfoResponse.fromJson(Map<String, dynamic> responseJson):
        status = responseJson['status'] as String,
        roomInfo = InfoRoomResponse.fromJson(responseJson['room_info']);
}

class InfoRoomResponse extends ChangeNotifier {
  String room;
  String room_name;
  int room_private;
  String? room_pass;

  InfoRoomResponse(
      this.room,
      this.room_name,
      this.room_private,
      this.room_pass
      );

  InfoRoomResponse.fromJson(Map<String, dynamic> responseJson):
        room = responseJson['room'] as String,
        room_name = responseJson['room_name'] as String,
        room_private = responseJson['room_private'] as int;
}