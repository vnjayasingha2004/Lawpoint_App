# Platform setup for LawPoint video calling

This Flutter package adds WebRTC video consultation using `flutter_webrtc` and runtime permission handling using `permission_handler`.

Because the uploaded UI package did not include the full `android/` and `ios/` folders, add the following entries in your real Flutter project before running on-device.

## Android - AndroidManifest.xml

Add these permissions inside the `<manifest>` element:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

Optional, depending on your target devices and Bluetooth audio routing:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

## iOS - Info.plist

Add:

```xml
<key>NSCameraUsageDescription</key>
<string>LawPoint needs camera access for secure lawyer consultations.</string>
<key>NSMicrophoneUsageDescription</key>
<string>LawPoint needs microphone access for secure lawyer consultations.</string>
```

## Runtime permission flow

The Flutter screen already requests:

- camera
- microphone

through `permission_handler`.

## Socket connection

The video call screen connects to the backend Socket.IO namespace:

- namespace: `/ws/video`
- auth transport: websocket
- token delivery: query string `?token=...`

## Backend expectation

The backend should only issue video tokens for valid scheduled consultations inside the allowed appointment window.
