import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../Data/storage/appConfig.dart';
import '../Models/video_session.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.session,
  });

  final VideoSession session;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  io.Socket? _socket;

  bool _joining = true;
  bool _localReady = false;
  bool _remoteConnected = false;
  String _statusText = 'Preparing video session...';

  @override
  void initState() {
    super.initState();
    _start();
  }

  String _socketUrl(String socketPath) {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(path: socketPath).toString();
  }

  Future<void> _start() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final session = widget.session;

      if (!session.canJoinNow || (session.socketToken?.isEmpty ?? true)) {
        setState(() {
          _joining = false;
          _statusText = session.message;
        });
        return;
      }

      final permissions = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (permissions[Permission.camera] != PermissionStatus.granted ||
          permissions[Permission.microphone] != PermissionStatus.granted) {
        setState(() {
          _joining = false;
          _statusText = 'Camera and microphone permissions are required.';
        });
        return;
      }

      final localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });

      _localStream = localStream;
      _localRenderer.srcObject = localStream;

      final pc = await createPeerConnection({
        'iceServers': session.iceServers.isNotEmpty
            ? session.iceServers
            : [
                {'urls': 'stun:stun.l.google.com:19302'}
              ],
      });

      for (final track in localStream.getTracks()) {
        await pc.addTrack(track, localStream);
      }

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _socket?.emit('ice-candidate', {
          'candidate': candidate.toMap(),
        });
      };

      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams.first;
          if (mounted) {
            setState(() {
              _remoteConnected = true;
              _statusText = 'Connected';
            });
          }
        }
      };

      pc.onConnectionState = (state) {
        if (!mounted) return;
        setState(() {
          _statusText = 'Connection: $state';
        });
      };

      _peerConnection = pc;
      await _connectSocket(session);

      if (mounted) {
        setState(() {
          _joining = false;
          _localReady = true;
          _statusText = 'Waiting for the other participant...';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _statusText = 'Failed to start video call: $e';
      });
    }
  }

  Future<void> _connectSocket(VideoSession session) async {
    final socket = io.io(
      _socketUrl(session.socketPath),
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1500,
        'auth': {
          'token': session.socketToken,
        },
      },
    );

    socket.onConnect((_) {
      socket.emit('join-room');
    });

    socket.onConnectError((error) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Connection failed: $error';
      });
    });

    socket.on('room-joined', (_) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Joined room';
      });
    });

    socket.on('room-full', (payload) {
      if (!mounted) return;
      setState(() {
        _statusText = (payload is Map && payload['error'] != null)
            ? payload['error'].toString()
            : 'Room is already full.';
      });
      socket.disconnect();
    });

    socket.on('peer-joined', (_) async {
      final pc = _peerConnection;
      if (pc == null) return;

      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      socket.emit('offer', {
        'sdp': offer.toMap(),
      });

      if (mounted) {
        setState(() {
          _statusText = 'Calling...';
        });
      }
    });

    socket.on('offer', (payload) async {
      final pc = _peerConnection;
      if (pc == null) return;

      final remote = payload['sdp'];
      await pc.setRemoteDescription(
        RTCSessionDescription(
          remote['sdp'] as String,
          remote['type'] as String,
        ),
      );

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      socket.emit('answer', {
        'sdp': answer.toMap(),
      });

      if (mounted) {
        setState(() {
          _statusText = 'Joining...';
        });
      }
    });

    socket.on('answer', (payload) async {
      final pc = _peerConnection;
      if (pc == null) return;

      final remote = payload['sdp'];
      await pc.setRemoteDescription(
        RTCSessionDescription(
          remote['sdp'] as String,
          remote['type'] as String,
        ),
      );
    });

    socket.on('ice-candidate', (payload) async {
      final pc = _peerConnection;
      if (pc == null) return;

      final candidateMap = payload['candidate'];
      if (candidateMap == null) return;

      final rawIndex = candidateMap['sdpMLineIndex'];
      final lineIndex =
          rawIndex is int ? rawIndex : int.tryParse(rawIndex?.toString() ?? '');

      await pc.addCandidate(
        RTCIceCandidate(
          candidateMap['candidate'] as String?,
          candidateMap['sdpMid'] as String?,
          lineIndex,
        ),
      );
    });

    socket.on('peer-left', (_) {
      if (!mounted) return;
      _remoteRenderer.srcObject = null;
      setState(() {
        _remoteConnected = false;
        _statusText = 'The other participant left the call.';
      });
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Disconnected';
      });
    });

    socket.connect();
    _socket = socket;
  }

  Future<void> _toggleMute() async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !track.enabled;
    }
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      track.enabled = !track.enabled;
    }
    setState(() {});
  }

  Future<void> _endCall() async {
    _socket?.emit('leave-room');
    await _socket?.disconnect();
    await _peerConnection?.close();
    await _localStream?.dispose();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget remoteView() {
      if (_remoteConnected) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_call_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (_joining) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      );
    }

    Widget localView() {
      if (_localReady) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(
              color: Colors.black87,
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
        );
      }

      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'Local preview unavailable',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live video call')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            remoteView(),
            const SizedBox(height: 16),
            SizedBox(width: 140, child: localView()),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _toggleMute,
                  icon: const Icon(Icons.mic_off_rounded),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _toggleCamera,
                  icon: const Icon(Icons.videocam_off_rounded),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _endCall,
                  icon: const Icon(Icons.call_end_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
