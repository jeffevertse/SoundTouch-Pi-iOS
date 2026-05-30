# SoundTouch Pi — iOS App

Native SwiftUI iOS companion app for the [SoundTouch-Pi](https://github.com/jeffevertse/SoundTouch-Pi) controller.

Talks directly to the Pi's REST API at `http://soundtouch-pi.local:5000`.

## Features

- **Now Playing** — live station name, artist/track, playing indicator via SSE
- **Transport controls** — play/pause, skip, power, mute
- **Volume & bass** sliders with debounced API calls
- **6 presets** — tap to play, long-press to edit (name, stream URL, icon)
- **Sync to device buttons** — writes presets into the speaker's 6 physical hardware slots
- **WiFi management** — scan networks, connect, setup hotspot
- **System** — reboot Pi (two-tap confirmation)

## Requirements

- iOS 17+
- Xcode 16+
- SoundTouch-Pi running on a Raspberry Pi on the same local network

## Setup

1. Clone this repo
2. Open `SoundTouch Pi.xcodeproj` in Xcode
3. Set your signing team (project settings → Signing & Capabilities)
4. Connect your iPhone and press ⌘R

## Architecture

```
Networking/
  APIClient.swift      URLSession wrapper for all Pi REST endpoints
  SSEClient.swift      Server-Sent Events streaming for real-time updates
  Models.swift         Codable structs

ViewModels/
  PlayerViewModel.swift  @MainActor ObservableObject, owns API + SSE

Views/
  ContentView.swift      Root scrollable layout
  NowPlayingCard.swift   Station + status dot
  TransportBar.swift     Circular control buttons
  VolumeRow.swift        Debounced slider
  BassRow.swift          Debounced slider (hidden if unsupported)
  PresetsSection.swift   2-col grid + sync button + sources
  PresetEditSheet.swift  Bottom sheet for editing a preset
  SettingsSection.swift  WiFi + system controls
  WifiScanView.swift     Network list sheet
```
