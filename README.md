# Foredeck

Hands-free crew intercom for docking and anchoring, with a shared anchor view.
Built for iPhone using SwiftUI, Multipeer Connectivity, AVAudioEngine, MapKit,
and Core Location.

Crew can talk over the boat's Wi-Fi or connect directly phone to phone. The
anchor view shares a drop point, swing circle, rode length, and alarm radius.
An optional Signal K connection supplies boat position and instrument data.

## Features

- Open microphone with voice-activity detection, or push-to-talk.
- Crew stations, speaking indicators, per-peer mute and volume controls.
- Boat pairing using a QR code or typed invitation code.
- Shared anchor and docking targets, distances, and position track.
- Anchor alarm, selectable distance/depth units, and a red-on-black night mode.
- Optional Signal K GPS, depth, apparent wind, and speed readings.

## Build

Requires Xcode with the iOS 17 SDK or newer. Open `Foredeck.xcodeproj` to use the
checked-in project. The pure Swift core also supports macOS 14 or newer.

For installation on your own iPhone:

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Set your own unique bundle identifier and Apple development team ID there.
3. Open the project, select your device, and build. Configure automatic signing
   in Xcode if needed for your development account.

`Config/Build.xcconfig` provides generic defaults and optionally includes the
ignored local file. Personal signing settings, credentials, provisioning
profiles, and private keys must not be committed. A fresh clone can build for
the Simulator without personal signing configuration.

The installed App Store app has its own signing identity. Maintainers should
retain that identity in their local configuration when archiving updates.

The project can optionally be regenerated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
```

Both the checked-in project and `project.yml` use the same configuration files.

## Tests and device verification

Run the pure Swift core tests:

```sh
swift test --package-path ForedeckCore
```

These cover packet and wire formats, audio codecs, voice-activity detection,
jitter buffering, geographic calculations, units, boat keys, and shared anchor
state. Simulator builds can validate compilation and UI, but do not establish
real-world radio connectivity, microphone quality, background operation, or
alarm reliability.

For device checks, use two physical iPhones:

1. Create a boat on one phone and pair the other using the QR code or boat code.
2. Join the crew session and check simultaneous two-way audio, mute, volume,
   open microphone, and push-to-talk. Repeat with screens locked.
3. Check direct peer connectivity without a boat router.
4. Confirm anchor and docking changes propagate between phones, and test the
   configured alarm and background behavior.
5. Test in realistic docking, anchoring, and wind conditions before relying on
   the app during a maneuver. Headsets generally improve speech in wind.

## Architecture

- `Foredeck/`: SwiftUI views, app model, audio engine, transport, location,
  optional Signal K client, and alarm handling.
- `ForedeckCore/`: pure Swift package for audio packets/codecs, jitter buffering,
  voice detection, geographic calculations, transport messages, and shared state.
- `Config/`: public build defaults and an example local signing configuration.
- `icon-mockups/`: original branding explorations; see the artwork license.

Voice packets use unreliable transport so late audio does not block newer
frames. Open microphone audio is gated by voice activity. Shared anchor state
uses per-field last-writer-wins registers ordered by Lamport clocks, rather than
requiring a permanent host phone.

Multipeer Connectivity limits sessions to eight devices. Pairing codes are
intended to keep nearby unintended crew out, not to defend against an active
attacker on the same network. Location, background operation, and alarm behavior
depend on permissions, device state, and connectivity.

## Privacy and security

Microphone access supports voice communication; local network access supports
crew discovery. Location access supports position and anchor features. Camera
access is used for QR pairing. The boat code is stored in the device Keychain.
Signal K is optional; without it the app uses Core Location.

See [SECURITY.md](SECURITY.md) for private vulnerability reporting. Keep real
crew invitations, location recordings, signing files, and credentials out of
issues, screenshots, and commits.

## License

Source code and documentation are licensed under [MIT](LICENSE). App icons and
branding artwork have separate terms in [ASSETS-LICENSE.md](ASSETS-LICENSE.md).
Use your own branding when distributing a fork.
