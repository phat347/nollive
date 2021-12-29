
import 'package:flutter/cupertino.dart';

class EnterRoomResponse extends ChangeNotifier {

  String livekitToken;

  EnterRoomResponse(this.livekitToken);

  EnterRoomResponse.fromJson(Map<String, dynamic> responseJson):
    livekitToken = responseJson['livekit_token'] as String;

}