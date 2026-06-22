# Voicenotes

A UIKit iOS app to record, visualize, list, and play back voice recordings.

## Features

- Record audio with a live waveform animation
- List of saved recordings with title, duration, and date
- Playback with play/pause and a scrubbable waveform
- Rename and delete recordings

## Tech stack

- UIKit (built in code, no storyboard)
- AVAudioRecorder for recording + metering
- AVAudioPlayer for playback
- CAShapeLayer for waveform rendering
- Local JSON storage for recording metadata

## Setup

1. Clone the repo and open in Xcode
2. Build and run (`Cmd + R`)
3. Allow microphone access when prompted
