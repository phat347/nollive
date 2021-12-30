
import 'package:flutter/cupertino.dart';

class FailedRoomResponse extends ChangeNotifier {
  String status;
  String message;
  RequestRoom request;

  FailedRoomResponse.fromJson(Map<String, dynamic> responseJson):
        status = responseJson['status'] as String,
        message = responseJson['message'] as String,
        request = RequestRoom.fromJson(responseJson['request']);
}

class RequestRoom extends ChangeNotifier {
  String room;

  RequestRoom.fromJson(Map<String, dynamic> responseJson):
      room = responseJson['room'] as String;
}

class EnterRoomResponse extends ChangeNotifier {

  RoomInfoResponse? room_info;
  String livekitToken;

  EnterRoomResponse(this.livekitToken, this.room_info);

  EnterRoomResponse.fromJson(Map<String, dynamic> responseJson):
        room_info = RoomInfoResponse.fromJson(responseJson['room_info']),
        livekitToken = responseJson['livekit_token'] as String;
}

class RoomInfoResponse extends ChangeNotifier {
  String room_name;
  int max_users;
  int room_type;
  String from_datetime;
  String to_datetime;
  String created_by;
  int admin_required;
  int room_private;
  String package;
  String owner_ip;
  String owner_agent;
  dynamic bookingid;
  dynamic paid;
  dynamic recording_path;
  dynamic recording_url;
  LivekitRoomResponse livekit;
  String room;
  String created;
  String expiry_datetime;
  List<UsersResponse> users;

  RoomInfoResponse.fromJson(Map<String, dynamic> responseJson) :
        room_name = responseJson['room_name'] as String,
        max_users = responseJson['max_users'] as int,
        room_type = responseJson['room_type'] as int,
        from_datetime = responseJson['from_datetime'] as String,
        to_datetime = responseJson['to_datetime'] as String,
        created_by = responseJson['created_by'] as String,
        admin_required = responseJson['admin_required'] as int,
        room_private = responseJson['room_private'] as int,
        package = responseJson['package'] as String,
        owner_ip = responseJson['owner_ip'] as String,
        owner_agent = responseJson['owner_agent'] as String,
        bookingid = responseJson['bookingid'],
        paid = responseJson['paid'],
        recording_path = responseJson['recording_path'],
        recording_url = responseJson['recording_url'],
        livekit = LivekitRoomResponse.fromJson(responseJson['livekit']),
        room = responseJson['room'] as String,
        created = responseJson['created'] as String,
        expiry_datetime = responseJson['expiry_datetime'] as String,
        users = responseJson['users'].map((userJson) => UsersResponse.fromJson(userJson));
}

class LivekitRoomResponse extends ChangeNotifier {
  String sid;
  String name;
  int empty_timeout;
  int max_participants;
  String creation_time;
  String turn_password;
  EnableCodecsResponse enabled_codecs;
  bool active_recording;

  LivekitRoomResponse.fromJson(Map<String, dynamic> responseJson):
        sid = responseJson['sid'] as String,
        empty_timeout = responseJson['empty_timeout'] as int,
        name = responseJson['name'] as String,
        max_participants = responseJson['max_participants'] as int,
        creation_time = responseJson['creation_time'] as String,
        turn_password = responseJson['turn_password'] as String,
        enabled_codecs = EnableCodecsResponse.fromJson(responseJson['enabled_codecs']),
        active_recording = responseJson['active_recording'] as bool;
}

class EnableCodecsResponse extends ChangeNotifier {
  String mine;
  String fmtp_line;

  EnableCodecsResponse.fromJson(Map<String, dynamic> responseJson):
        mine = responseJson['mime'] as String,
        fmtp_line = responseJson['fmtp_line'] as String;

}

class UsersResponse extends ChangeNotifier {
  String joint;
  UserInfoResponse info;

  UsersResponse.fromJson(Map<String, dynamic> responseJson):
        joint = responseJson['joint'] as String,
        info = UserInfoResponse.fromJson(responseJson['info']);
}

class UserInfoResponse extends ChangeNotifier {

  String connected;
  String sid;
  String fullname;

  UserInfoResponse.fromJson(Map<String, dynamic> responseJson) :
        connected = responseJson['connected'] as String,
        sid       = responseJson['sid'] as String,
        fullname  = responseJson['fullname'] as String;
}