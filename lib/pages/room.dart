import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/model/roomInfo.dart';

import '../exts.dart';
import '../widgets/controls.dart';
import '../widgets/participant.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';
const double participantHeight = 100;

class RoomPage extends StatefulWidget {
  //
  final Room room;
  List<UsersResponse> itemListUser = [];
  // final EnterRoomResponse enterRoomRes;
  IO.Socket socket;
  RoomPage(
      this.room,
      this.itemListUser,
      this.socket,
      // this.enterRoomRes,
      {
        Key? key,
      }
      ) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  //
  List<Participant> participants = [];
  late final EventsListener<RoomEvent> _listener = widget.room.createListener();

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    _sortParticipants();
    WidgetsBinding.instance?.addPostFrameCallback((_) => _askPublish());
  }

  @override
  void dispose() {
    // always dispose listener
    (() async {
      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
    })();
    super.dispose();
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((_) async {
      WidgetsBinding.instance
          ?.addPostFrameCallback((timeStamp) => Navigator.pop(context));
    })
    ..on<DataReceivedEvent>((event) {
      String decoded = 'Failed to decode';
      try {
        decoded = utf8.decode(event.data);
      } catch (_) {
        print('Failed to decode: $_');
      }
      context.showDataReceivedDialog(decoded);
    });

  void _askPublish() async {
    final result = await context.showPublishDialog();
    if (result != true) return;
    // video will fail when running in ios simulator
    try {
      await widget.room.localParticipant?.setCameraEnabled(true);
    } catch (error) {
      print('could not publish video: $error');
      await context.showErrorDialog(error);
    }
    try {
      await widget.room.localParticipant?.setMicrophoneEnabled(true);
    } catch (error) {
      print('could not publish audio: $error');
      await context.showErrorDialog(error);
    }
  }
  List<UsersResponse> returnList(Map<String, dynamic>? parsedJson) {
    widget.itemListUser.clear();
    parsedJson?.forEach((k, v) => widget.itemListUser.add(UsersResponse.fromJson(v)));
    return widget.itemListUser;
  }
  void connectToServer() {
    try {

      //call back entered_room
      widget.socket.on(
          'entered_room',
              (data) {
            final Map<String, dynamic> jsonData = jsonDecode(data);
            print('Phat log enteredroom passed socked');
            setState(() {
              EnterRoomResponse enterRoomRes = EnterRoomResponse('', null);

              enterRoomRes = EnterRoomResponse.fromJson(jsonData);
              widget.itemListUser.clear();
              enterRoomRes.room_info?.users.forEach((k, v) => widget.itemListUser.add(UsersResponse.fromJson(v)));

              for (var i = 0; i < participants.length; i++) {
                print('Phat debug identity: ${participants[i].identity}');
                for (var j = 0; j < widget.itemListUser.length; j++) {
                  print('Phat debug identity 2: ${widget.itemListUser[j].info.sid}');
                  if(participants[i].identity==widget.itemListUser[j].info.sid)
                  {
                    participants[i].identity = widget.itemListUser[j].info.fullname;
                  }
                }
              }
            });
          }
      );




    } catch (e) {
      print('Phat error ${e.toString()}');

    }

  }

  void _onRoomDidUpdate() {
    connectToServer();
    _sortParticipants();
  }

  void _sortParticipants() {
    List<Participant> participants = [];
    participants.addAll(widget.room.participants.values);
    // sort speakers for the grid
    participants.sort((a, b) {
      // loudest speaker first
      if (a.isSpeaking && b.isSpeaking) {
        if (a.audioLevel > b.audioLevel) {
          return -1;
        } else {
          return 1;
        }
      }

      // last spoken at
      final aSpokeAt = a.lastSpokeAt?.millisecondsSinceEpoch ?? 0;
      final bSpokeAt = b.lastSpokeAt?.millisecondsSinceEpoch ?? 0;

      if (aSpokeAt != bSpokeAt) {
        return aSpokeAt > bSpokeAt ? -1 : 1;
      }

      // video on
      if (a.hasVideo != b.hasVideo) {
        return a.hasVideo ? -1 : 1;
      }

      // joinedAt
      return a.joinedAt.millisecondsSinceEpoch -
          b.joinedAt.millisecondsSinceEpoch;
    });

    final localParticipant = widget.room.localParticipant;
    if (localParticipant != null) {
      if (participants.length > 1) {
        participants.insert(1, localParticipant);
      } else {
        participants.add(localParticipant);
      }
    }
    setState(() {
      for (var i = 0; i < participants.length; i++) {
        print('Phat debug identity: ${participants[i].identity}');
        for (var j = 0; j < widget.itemListUser.length; j++) {
          print('Phat debug identity: ${widget.itemListUser[j].info.sid}');
          if(participants[i].identity==widget.itemListUser[j].info.sid)
          {
            participants[i].identity = widget.itemListUser[j].info.fullname;
          }
        }
      }
      this.participants = participants;

    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Expanded(
            child: participants.isNotEmpty
                ? ParticipantWidget.widgetFor(
                participants.first
            )
                : Container()),
        SizedBox(
          height: participantHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: math.max(0, participants.length - 1),
            itemBuilder: (BuildContext context, int index) => SizedBox(
              width: participantHeight * (16/9),
              height: participantHeight,
              child: ParticipantWidget.widgetFor(
                  participants[index + 1]
              )
            )
          )
        ),
        if (widget.room.localParticipant != null)
          SafeArea(
            top: false,
            child:
            ControlsWidget(widget.room, widget.room.localParticipant!),
          ),
      ],
    ),
  );
}
