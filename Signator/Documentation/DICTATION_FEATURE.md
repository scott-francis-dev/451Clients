# Voice Dictation Feature for Persona Creation

## Overview

The Persona Creation form now includes voice dictation support for text fields. Users can tap a microphone button next to text fields to dictate their information instead of typing.

## Features

- **Microphone Button**: Each supported text field now has a blue microphone icon on the right side
- **Real-time Transcription**: Speech is converted to text in real-time as you speak
- **Visual Feedback**: The microphone turns red while recording
- **Auto-stop**: Recording automatically stops when you finish speaking or tap the mic button again

## Supported Fields

Voice dictation has been added to the following fields:

### Basic Information
- ✅ Persona Name
- ✅ Publishing House (for public personas)
- ✅ One-Time Signing Name

### Private Information
- ✅ Given Name
- ✅ Aliases
- ✅ Street Address
- ✅ City
- ✅ State/Region
- ✅ Country
- ✅ Public Affiliations
- ✅ Social Media Links

### Fields Without Dictation
- ❌ Email addresses (typed only)
- ❌ Social Security Number (typed only - for security)
- ❌ Zip Code (typed only)
- ❌ Custom domains and handles (typed only - technical format required)

## Required Info.plist Permissions

To enable voice dictation, add these keys to your `Info.plist` file:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Signator needs access to your microphone to enable voice dictation for filling out persona information.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Signator uses speech recognition to convert your voice to text when filling out forms.</string>
```

### Complete Info.plist Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Other keys here -->
    
    <!-- Microphone Permission -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Signator needs access to your microphone to enable voice dictation for filling out persona information.</string>
    
    <!-- Speech Recognition Permission -->
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Signator uses speech recognition to convert your voice to text when filling out forms.</string>
    
    <!-- Existing ATS Exception -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>localhost</key>
            <dict>
                <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

## Usage

1. **Tap the microphone icon** next to any supported field
2. **Grant permissions** if prompted (first time only)
   - The app will request microphone access
   - The app will request speech recognition access
3. **Start speaking** - The microphone icon turns red while recording
4. **Watch text appear** - Your speech is transcribed in real-time
5. **Tap again to stop** - Or let it auto-stop when you pause

## Permission Handling

### First Time Use
When you first tap a microphone button, iOS will:
1. Ask for Speech Recognition permission
2. Ask for Microphone permission

### Denied Permissions
If you previously denied permissions:
- The microphone button will be disabled (grayed out)
- Tapping it shows an alert with a link to Settings
- You can grant permissions in: Settings → Signator → Microphone/Speech Recognition

### Privacy
- All speech recognition is processed **on-device** using Apple's Speech framework
- No audio is sent to external servers
- Transcriptions are only used to fill the form fields
- No voice data is stored

## Technical Implementation

### Component: `DictationTextField`

A custom SwiftUI view that wraps a standard `TextField` with an integrated microphone button.

**Key Features:**
- Uses `SFSpeechRecognizer` for on-device speech recognition
- Configurable placeholder, keyboard type, and autocapitalization
- Automatic permission requests
- Real-time transcription updates

**Parameters:**
```swift
DictationTextField(
    placeholder: "Field Name",
    text: $bindingVariable,
    prompt: Text("Optional prompt"),
    keyboardType: .default,
    textContentType: nil,
    autocapitalization: .sentences,
    autocorrection: true
)
```

### Frameworks Used
- `Speech` - For speech recognition
- `AVFoundation` - For audio recording
- `SwiftUI` - For UI components

## Troubleshooting

### Microphone button is disabled
- Check Settings → Signator → Microphone
- Check Settings → Signator → Speech Recognition
- Ensure both permissions are enabled

### Transcription not working
- Ensure you have an internet connection for initial setup
- Check that your device supports speech recognition
- Verify the language is set to English (US)

### Poor transcription quality
- Speak clearly and at a moderate pace
- Reduce background noise
- Ensure microphone is not blocked
- Try typing if dictation continues to have issues

## Future Enhancements

Potential improvements for future versions:
- [ ] Support for multiple languages
- [ ] Offline speech recognition (iOS 13+)
- [ ] Custom vocabulary for legal/technical terms
- [ ] Voice commands (e.g., "next field", "submit")
- [ ] Dictation for longer text areas like notes

## Accessibility

Voice dictation improves accessibility by:
- ✅ Providing an alternative to typing for users with motor difficulties
- ✅ Reducing barriers for users with dyslexia or spelling challenges
- ✅ Enabling faster form completion for all users
- ✅ Supporting users who prefer voice input

---

**Note:** This feature requires iOS 13.0 or later and is only available on physical devices (not simulators).
