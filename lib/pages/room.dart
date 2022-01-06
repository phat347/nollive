import 'dart:convert';
import 'dart:math' as math;


import 'package:audioplayers/audioplayers.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/main.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_example/theme.dart';
import 'package:livekit_example/widgets/no_video.dart';

import '../exts.dart';
import '../widgets/controls.dart';
import '../widgets/participant.dart';

const double participantPortraitHeight = 150;
const double participantLanscapeWidth = 180;

typedef OnDisconnect = void Function();

class RoomPage extends StatefulWidget {
  //
  final Room room;
  List<UsersResponse> itemListUser = [];
  final OnDisconnect onDisconnected;

  RoomPage({
    Key? key,
    required this.room,
    required this.itemListUser,
    required this.onDisconnected
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  //
  List<Participant> participants = [];
  late final EventsListener<RoomEvent> _listener = widget.room.createListener();
  Participant? pinnedParticipant;

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioCache? _audioCache;
  String audioPath = 'mp3/pubpub.mp3';

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomDidUpdate);
    _setUpListeners();
    // _sortParticipants();
    WidgetsBinding.instance?.addPostFrameCallback((_) => _askPublish());
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    // always dispose listener
    (() async {
      widget.room.removeListener(_onRoomDidUpdate);
      await _listener.dispose();
      await widget.room.dispose();
      await _audioPlayer.release();
      await _audioPlayer.dispose();
      await _audioCache?.clearAll();
    })();
    super.dispose();
  }

  void _setupAudioPlayer(){
    _audioCache = AudioCache(fixedPlayer: _audioPlayer);
  }

  void _playAudio() async {
    await _audioCache?.play(audioPath);
  }

  void _setUpListeners() => _listener
    ..on<RoomDisconnectedEvent>((_) async {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {
        widget.onDisconnected();
        Navigator.pop(context);
      });
    })
    ..on<ParticipantConnectedEvent>((event) async {
      print('hung log ParticipantConnectedEvent: ${event.participant.identity}');
      print('\nPlay Enter room Sound\n');
      /// Play Sound Enter Room
      _playAudio();
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

  void _onRoomDidUpdate() {
    // _sortParticipants();
    onPinnedParticipant();
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
        for (var j = 0; j < widget.itemListUser.length; j++) {
          if(participants[i].identity==widget.itemListUser[j].info.sid)
          {
            participants[i].identity = widget.itemListUser[j].info.fullname;
          }
        }
      }
      this.participants = participants;

    });
  }

  void onPinnedParticipant() {

    List<Participant> participants = [];
    participants.addAll(widget.room.participants.values);

    if (pinnedParticipant == null && participants.isNotEmpty) {
      participants.sort((a, b) { /// Sort last participant to pin in first time in room
        // joinedAt
        return a.joinedAt.millisecondsSinceEpoch -
            b.joinedAt.millisecondsSinceEpoch;
      });
      pinnedParticipant = participants.first ;
    }
    else if (pinnedParticipant is RemoteParticipant) {
      print('Remote pinned Participant: ${pinnedParticipant?.identity}');
      // sort speakers for the grid
      participants.sort((a, b) {
        if (a.identity != b.identity) {
          print('Sort a: ${a.identity}, b: ${b.identity}');
          if (a.identity == pinnedParticipant?.identity) {
            return -1;
          }
          if (b.identity == pinnedParticipant?.identity) {
            return 1;
          }
        }
        // joinedAt
        return a.joinedAt.millisecondsSinceEpoch -
            b.joinedAt.millisecondsSinceEpoch;
      });
    }

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
        for (var j = 0; j < widget.itemListUser.length; j++) {
          if(participants[i].identity==widget.itemListUser[j].info.sid)
          {
            participants[i].identity = widget.itemListUser[j].info.fullname;
          }
        }
      }
      this.participants = participants;
    });
  }

  void _onFullscreenParticipantPinned(BuildContext context) {
    print('_onFullscreenParticipantPinned');

    if (pinnedParticipant is RemoteParticipant) {
      RemoteParticipant _pinnedParticipant = pinnedParticipant as RemoteParticipant;

      print('fullscreen participant name: ${_pinnedParticipant.identity}');
      VideoTrack? pinnedTrack = _pinnedParticipant.videoTracks.first.track;

      var videoSettings = _pinnedParticipant.videoTracks.first.dimension;
      var videoSettingWidth = videoSettings?.width ?? 0;
      var videoSettingHeight = videoSettings?.height ?? 0;

      print('\n videoSettingWidth: ${videoSettingWidth}\n videoSettingHeight: ${videoSettingHeight}');

      if (videoSettingWidth > videoSettingHeight) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
      }

      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => Stack(
            children: [
              Container(
                  color: NolColors.nolColor,
                  child: pinnedTrack!= null ?
                  VideoTrackRenderer(
                      pinnedTrack,
                      fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                  ) : const NoVideoWidget()
              ),
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                          Radius.circular(16)
                      ),
                      child: Material(
                        color: NolColors.redPink.withOpacity(0.2),
                        child: IconButton(
                          onPressed: () {
                            if (videoSettingWidth > videoSettingHeight) {
                              SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                              ]);
                            }
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(EvaIcons.close),
                          tooltip: 'closeFullScreen',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
      );
    }

  }

  Widget pinParticipant(BuildContext context) => Expanded(
      child: participants.isNotEmpty
          ? ParticipantWidget.widgetFor(
          participants.first,
              () {},
          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          true,
              () => { _onFullscreenParticipantPinned(context) }
      )
          : Container()
  );

  Widget otherParticipant(Orientation orientation) => SizedBox(
      height: orientation == Orientation.portrait ? participantPortraitHeight*2 : null,
      width: orientation == Orientation.portrait ? null : participantLanscapeWidth,
      child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: orientation == Orientation.portrait ? 2 : 1,
              crossAxisSpacing: 10
          ),
          scrollDirection: Axis.vertical,
          itemCount: math.max(0, participants.length - 1),
          itemBuilder: (BuildContext context, int index) => SizedBox(
              child: ParticipantWidget.widgetFor(
                  participants[index + 1],
                      () { // Pinned Participant
                    print('onPinned at index: ${index + 1}');
                    setState(() {
                      pinnedParticipant = participants[index + 1];
                      onPinnedParticipant();
                    });
                  },
                  RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  false,
                      () { /* Fullscreen participant (pinned only)*/ }
              )
          )
      )
  );

  Widget controlWidget(Orientation orientation) {
    ControlsWidget ctrlWidget = ControlsWidget(widget.room, widget.room.localParticipant!);

    return orientation == Orientation.portrait ?
    SafeArea(
        top: false,
        child: ctrlWidget
    ) :
    SafeArea(
        left: false,
        child: SizedBox(width: 80, child: ctrlWidget)
    );
  }

  @override
  Widget build(BuildContext context) {

    rootContext = context;

    return Scaffold(
      body: OrientationBuilder(
          builder:(context, orientation) {
            if (orientation == Orientation.portrait) {
              return Column(
                children: [
                  pinParticipant(context),
                  otherParticipant(orientation),
                  if (widget.room.localParticipant != null)
                    controlWidget(orientation)
                ],
              );
            }
            else {
              return Row(
                children: [
                  pinParticipant(context),
                  otherParticipant(orientation),
                  if (widget.room.localParticipant != null)
                    controlWidget(orientation)
                ],
              );
            }
          }
      ),
    );
  }
}
