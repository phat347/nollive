import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/Socket/SocketManager.dart';

import '../exts.dart';


class ControlsWidget extends StatefulWidget {
  //
  final Room room;
  final LocalParticipant participant;

  const ControlsWidget(
      this.room,
      this.participant,
      {
        Key? key,
      }
      ) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ControlsWidgetState();
}

class _ControlsWidgetState extends State<ControlsWidget> {
  //
  CameraPosition position = CameraPosition.front;
  //
  bool enableSpeaker = true;

  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    participant.addListener(_onChange);
  }

  @override
  void dispose() {
    participant.removeListener(_onChange);
    super.dispose();
  }

  LocalParticipant get participant => widget.participant;

  void _onChange() {
    // trigger refresh
    setState(() {});
  }

  void _unpublishAll() async {
    final result = await context.showUnPublishDialog();
    if (result == true) await participant.unpublishAllTracks();
  }

  void _disableAudio() async {
    SocketManager.shared.updateOnOffAudio(false, participant);
    await participant.setMicrophoneEnabled(false);
  }

  Future<void> _enableAudio() async {
    SocketManager.shared.updateOnOffAudio(true, participant);
    await participant.setMicrophoneEnabled(true);
  }

  void _disableVideo() async {
    SocketManager.shared.updateOnOffVideo(false, participant);
    await participant.setCameraEnabled(false);
  }

  void _enableVideo() async {
    SocketManager.shared.updateOnOffVideo(true, participant);
    await participant.setCameraEnabled(true);
  }

  void _toggleCamera() async {
    //
    final track = participant.videoTracks.firstOrNull?.track;
    if (track == null) return;

    try {
      final newPosition = position.switched();
      await track.setCameraPosition(newPosition);
      setState(() {
        position = newPosition;
      });
    } catch (error) {
      print('could not restart track: $error');
      return;
    }
  }

  void _enableScreenShare() async {
    await participant.setScreenShareEnabled(true);

    if (Platform.isAndroid) {
      // Android specific
      try {
        // Required for android screenshare.
        const androidConfig = FlutterBackgroundAndroidConfig(
          notificationTitle: 'Screen Sharing',
          notificationText: 'LiveKit Example is sharing the screen.',
          notificationImportance: AndroidNotificationImportance.Default,
          notificationIcon:
              AndroidResource(name: 'livekit_ic_launcher', defType: 'mipmap'),
        );
        await FlutterBackground.initialize(androidConfig: androidConfig);
        await FlutterBackground.enableBackgroundExecution();
      } catch (e) {
        print('could not publish video: $e');
      }
    }
  }

  void _disableScreenShare() async {
    await participant.setScreenShareEnabled(false);
    if (Platform.isAndroid) {
      // Android specific
      try {
        //   await FlutterBackground.disableBackgroundExecution();
      } catch (error) {
        print('error disabling screen share: $error');
      }
    }
  }

  void _onTapDisconnect() async {
    final result = await context.showDisconnectDialog();
    if (result == true) await widget.room.disconnect();
  }

  void _onTapReconnect() async {
    final result = await context.showReconnectDialog();
    if (result == true) {
      try {
        await widget.room.reconnect();
        await context.showReconnectSuccessDialog();
      } catch (error) {
        await context.showErrorDialog(error);
      }
    }
  }

  void _onTapSendData() async {
    final result = await context.showSendDataDialog();
    if (result == true) {
      await widget.participant.publishData(
        utf8.encode('This is a sample data message'),
      );
    }
  }

  void _onTapEnableSpeaker() {

    setState(() {
      isBusy = true;
      enableSpeaker = !enableSpeaker;
    });

    print('enableSpeaker: ${enableSpeaker}');
    widget.room.participants.forEach((key, participant) {
      if (participant.sid == widget.participant.sid) { return; }
      participant.audioTracks.firstOrNull?.track?.mediaStreamTrack.enableSpeakerphone(enableSpeaker);
    });
    setState(() {
      isBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 10,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        children: [
          // IconButton(
          //   onPressed: _unpublishAll,
          //   icon: const Icon(EvaIcons.closeCircleOutline),
          //   tooltip: 'Unpublish all',
          // ),
          if (participant.isMicrophoneEnabled())
            IconButton(
              onPressed: _disableAudio,
              icon: const Icon(EvaIcons.mic),
              tooltip: 'mute audio',
            )
          else
            IconButton(
              onPressed: _enableAudio,
              icon: const Icon(EvaIcons.micOff),
              tooltip: 'un-mute audio',
            ),
          if (participant.isCameraEnabled())
            IconButton(
              onPressed: _disableVideo,
              icon: const Icon(EvaIcons.video),
              tooltip: 'mute video',
            )
          else
            IconButton(
              onPressed: _enableVideo,
              icon: const Icon(EvaIcons.videoOff),
              tooltip: 'un-mute video',
            ),

          IconButton(
            icon: (position == CameraPosition.back) ?
            const Icon(EvaIcons.person) :
            SvgPicture.asset(
                'assets/images/switchCamera.svg',
                width: 20,
                height: 20
            ),
            onPressed: () => _toggleCamera(),
            tooltip: 'toggle camera',
          ),
          // if (participant.isScreenShareEnabled())
          //   IconButton(
          //     icon: const Icon(EvaIcons.monitorOutline),
          //     onPressed: () => _disableScreenShare(),
          //     tooltip: 'unshare screen (experimental)',
          //   )
          // else
          //   IconButton(
          //     icon: const Icon(EvaIcons.monitor),
          //     onPressed: () => _enableScreenShare(),
          //     tooltip: 'share screen (experimental)',
          //   ),
          IconButton(
            onPressed: _onTapDisconnect,
            icon: const Icon(EvaIcons.phoneOffOutline),
            tooltip: 'disconnect',
          ),
          Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox(
                      height: 10,
                      width: 10,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: isBusy ? null : _onTapEnableSpeaker,
                  icon: enableSpeaker ? const Icon(EvaIcons.volumeUpOutline) : const Icon(EvaIcons.volumeMuteOutline),
                  tooltip: 'enableSpeaker',
                ),
              ]
          ),
          // IconButton(
          //   onPressed: _onTapSendData,
          //   icon: const Icon(EvaIcons.paperPlane),
          //   tooltip: 'send demo data',
          // ),
          // IconButton(
          //   onPressed: _onTapReconnect,
          //   icon: const Icon(EvaIcons.refresh),
          //   tooltip: 're-connect',
          // ),
        ],
      ),
    );
  }
}
