import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'roomRequest.g.dart';

@JsonSerializable(explicitToJson: true)
class RoomRequest extends ChangeNotifier {
  String room;

  RoomRequest(this.room);

  factory RoomRequest.fromJson(Map <String,dynamic> data) =>_$RoomRequestFromJson(data);

  Map<String,dynamic> toJson() => _$RoomRequestToJson(this);
}