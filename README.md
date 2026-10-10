# MULMEDMUMED
> **MULMEDMUMED** is a high-precision, low-latency mobile broadcast controller and multiview monitor designed for OBS Studio and live video production. Switch scenes, control audio, trigger transitions, and monitor stream health directly from your mobile device.

> **Status:** 🚧 In active development

<!-- TODO: add banner / demo GIF here -->
<!-- ![Screenshot](docs/screenshots/home.png) -->

## Features

Tick what is already implemented and delete what is not.

- [ ] Connect to OBS Studio via obs-websocket
- [ ] Start / stop streaming (on-air / off-air)
- [ ] Stream status (bitrate, dropped frames, uptime, etc.)
- [ ] Scene preview and scene switcher
- [ ] Transitions
- [ ] Live chat
- [ ] Support for other tools (Streamlabs, vMix)

## Tech Stack

| Layer            | Technology                                 |
| ---------------- | ------------------------------------------ |
| App              | Flutter / Dart                             |
| Protocol         | obs-websocket (WebSocket, v5)              |
| State management | `TODO` (Provider / Riverpod / Bloc / GetX) |

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `TODO: version`
- Android Studio or VS Code with the Flutter extension
- OBS Studio 28+ (obs-websocket is built in)
- Phone and PC on the **same local network**

## OBS Setup

1. Open OBS Studio, then **Tools → WebSocket Server Settings**.
2. Enable **Enable WebSocket server**.
3. Set a server port (default `4455`) and a password.
4. Note your PC's local IP address (e.g. `192.168.1.10`).

## Getting Started

```bash
# Clone the repository
git clone https://github.com/abetkalinggaw/obscontrol_app.git
cd obscontrol_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

## Usage

1. Launch the app.
2. Enter the OBS host (PC IP), port, and password.
3. Tap **Connect**.
4. Switch scenes, start/stop the stream, and monitor status from your phone.

## Project Structure

```
lib/
├── main.dart
└── ...   # TODO: describe your folders (screens, services, models, widgets)
```

## Roadmap

- [ ] `TODO`
- [ ] `TODO`

## Contributing

Contributions are welcome. Fork the repo, create a feature branch, and open a pull request.

## License

`TODO: choose a license (e.g. MIT)`

## Author

**Abet**: [@abetkalinggaw](https://github.com/abetkalinggaw)

## Acknowledgements

- [obs-websocket](https://github.com/obsproject/obs-websocket)
- [OBS Studio](https://obsproject.com/)
