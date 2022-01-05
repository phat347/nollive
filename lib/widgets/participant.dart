import 'package:collection/collection.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_example/model/roomInfo.dart';
import 'package:livekit_example/theme.dart';

import 'no_video.dart';
import 'participant_info.dart';

typedef OnPinnedParticipant = void Function();

abstract class ParticipantWidget extends StatefulWidget {
  // Convenience method to return relevant widget for participant
  static ParticipantWidget widgetFor(
      Participant participant,
      OnPinnedParticipant onPinned,
      RTCVideoViewObjectFit fit,
      bool isPinned
      ) {
    if (participant is LocalParticipant) {
      return LocalParticipantWidget(
          participant,
              () {},
          fit
      );
    }
    else if (participant is RemoteParticipant) {
      return RemoteParticipantWidget(
          participant,
          onPinned,
          fit,
          isPinned
      );
    }
    throw UnimplementedError('Unknown participant type');
  }

  // Must be implemented by child class
  abstract final Participant participant;
  final VideoQuality quality;
  abstract final OnPinnedParticipant onPinnedParticipant;
  final bool isPinned;
  final RTCVideoViewObjectFit fit;

  const ParticipantWidget({
    this.isPinned = false,
    this.quality = VideoQuality.HIGH,
    this.fit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    Key? key,
  }) : super(key: key);
}

class LocalParticipantWidget extends ParticipantWidget {
  @override
  final LocalParticipant participant;

  @override
  final OnPinnedParticipant onPinnedParticipant;

  @override
  final RTCVideoViewObjectFit fit;

  const LocalParticipantWidget(
      this.participant,
      this.onPinnedParticipant,
      this.fit,
      {
        Key? key,
      }
      ) : super(key: key);

  @override
  State<StatefulWidget> createState() => _LocalParticipantWidgetState();
}

class RemoteParticipantWidget extends ParticipantWidget {
  @override
  final RemoteParticipant participant;

  @override
  final OnPinnedParticipant onPinnedParticipant;

  @override
  final RTCVideoViewObjectFit fit;

  @override
  final bool isPinned;

  const RemoteParticipantWidget(
      this.participant,
      this.onPinnedParticipant,
      this.fit,
      this.isPinned,
      {
        Key? key,
      }
      ) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RemoteParticipantWidgetState();
}

abstract class _ParticipantWidgetState<T extends ParticipantWidget> extends State<T> {
  //
  bool _visible = true;
  VideoTrack? get activeVideoTrack;
  TrackPublication? get firstVideoPublication;
  TrackPublication? get firstAudioPublication;


  @override
  void initState() {
    super.initState();
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
  }

  @override
  void dispose() {
    widget.participant.removeListener(_onParticipantChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    oldWidget.participant.removeListener(_onParticipantChanged);
    widget.participant.addListener(_onParticipantChanged);
    _onParticipantChanged();
    super.didUpdateWidget(oldWidget);
  }

  // Notify Flutter that UI re-build is required, but we don't set anything here
  // since the updated values are computed properties.
  void _onParticipantChanged() => setState(() {});

  // Widgets to show above the info bar
  List<Widget> extraWidgets() => [];

  @override
  Widget build(BuildContext ctx) => Container(
        foregroundDecoration: BoxDecoration(
          border: widget.participant.isSpeaking
              ? Border.all(
                  width: 5,
                  color: NolColors.redPink,
                )
              : null,
        ),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
        ),
        child: Stack(
          children: [
            // Video
            InkWell(
              onTap: () => setState(() => _visible = !_visible),
              child: activeVideoTrack != null
                  ? VideoTrackRenderer(
                activeVideoTrack!,
                fit: widget.fit,
              )
                  : const NoVideoWidget(),
            ),

            // Bottom bar
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...extraWidgets(),
                  ParticipantInfoWidget(
                    title: widget.participant.identity,
                    audioAvailable: firstAudioPublication?.muted == false && firstAudioPublication?.subscribed == true,
                    connectionQuality: widget.participant.connectionQuality,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LocalParticipantWidgetState extends _ParticipantWidgetState<LocalParticipantWidget> {
  @override
  LocalTrackPublication<LocalVideoTrack>? get firstVideoPublication => widget.participant.videoTracks.firstOrNull;

  @override
  LocalTrackPublication<LocalAudioTrack>? get firstAudioPublication => widget.participant.audioTracks.firstOrNull;

  @override
  VideoTrack? get activeVideoTrack {
    if (firstVideoPublication?.subscribed == true && firstVideoPublication?.muted == false && _visible) {
      return firstVideoPublication?.track;
    }
  }
}

class _RemoteParticipantWidgetState extends _ParticipantWidgetState<RemoteParticipantWidget> {
  @override
  RemoteTrackPublication<RemoteVideoTrack>? get firstVideoPublication => widget.participant.videoTracks.firstOrNull;

  @override
  RemoteTrackPublication<RemoteAudioTrack>? get firstAudioPublication => widget.participant.audioTracks.firstOrNull;

  @override
  VideoTrack? get activeVideoTrack {
    for (final trackPublication in widget.participant.videoTracks) {
      print('video track ${trackPublication.sid} subscribed ${trackPublication.subscribed} muted ${trackPublication.muted}');
      if (trackPublication.subscribed && !trackPublication.muted) {
        return trackPublication.track;
      }
    }
  }

  void _onPinned() {
    print('_onPinned pressed');
    widget.onPinnedParticipant();
  }

  @override
  void initState() {
    firstAudioPublication?.track?.mediaStreamTrack.enableSpeakerphone(true);
    widget.participant.audioLevel = 1;
    super.initState();
  }

  @override
  List<Widget> extraWidgets() => [
    Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Menu for Pinned Video
        if(firstVideoPublication != null && !widget.isPinned)
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)
            ),
            child: Material(
              color: Colors.black.withOpacity(0.2),
              child: IconButton(
                onPressed: _onPinned,
                icon: SvgPicture.asset(
                  'images/ic_pinned.svg',
                  width: 15,
                  height: 20
                ),
                tooltip: 'pinned',
              ),
            ),
          ),
        // Menu for RemoteTrackPublication<RemoteVideoTrack>
        if (firstVideoPublication != null)
          if (widget.isPinned)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)
              ),
              child: RemoteTrackPublicationMenuWidget(
                pub: firstVideoPublication!,
                icon: EvaIcons.videoOutline,
              ),
            )
          else
            RemoteTrackPublicationMenuWidget(
              pub: firstVideoPublication!,
              icon: EvaIcons.videoOutline,
            ),
        // Menu for RemoteTrackPublication<RemoteAudioTrack>
        if (firstAudioPublication != null)
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16)
            ),
            child: RemoteTrackPublicationMenuWidget(
              pub: firstAudioPublication!,
              icon: EvaIcons.volumeUpOutline,
            ),
          ),
      ],
    ),
  ];
}

class RemoteTrackPublicationMenuWidget extends StatelessWidget {
  final IconData icon;
  final RemoteTrackPublication pub;
  const RemoteTrackPublicationMenuWidget({
    required this.pub,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.2),
        child: PopupMenuButton<Function>(
          icon: Icon(icon),
          onSelected: (value) => value(),
          itemBuilder: (BuildContext context) {
            return <PopupMenuEntry<Function>>[
              // Subscribe/Unsubscribe
              if (pub.subscribed == false)
                PopupMenuItem(
                  child: const Text('Mở'),
                  value: () => pub.subscribed = true,
                )
              else if (pub.subscribed == true)
                PopupMenuItem(
                  child: const Text('Tắt'),
                  value: () => pub.subscribed = false,
                ),
            ];
          },
        ),
      );
}
