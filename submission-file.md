# Submission Guide

## Link to GitHub Repository

Flutter Application Name - WanderJoy

GitHub Repository - https://github.com/Jiangyue123456/wanderjoy_flutter

## Introduction to Application

WanderJoy is a Flutter mobile application designed for playful, AI-assisted city exploration. The app helps users describe what kind of experience they want, receive personalized place recommendations, build a route, navigate between points of interest, meet compatible travel companions, and save memories from the trip.

The project was developed from background research into Komoot, Polarsteps, Atlas Obscura, and Couchsurfing, as well as a user questionnaire about travel planning, social travel needs, and memory recording. These findings shaped the app around three main flows: Explore Mode, Social Mode, and Memory Mode.

Explore Mode uses conversational AI input to understand the user's interests and preferred travel intensity, then recommends real places and generates a route. Social Mode supports safer travel companion matching through shared interests, travel intensity, distance, profile information, safety score, meeting setup, and NFC-style offline confirmation. Memory Mode allows users to save a route together with photos, written notes, visited locations, timestamps, and companion context.

The prototype uses Flutter and Dart for the mobile interface, Firebase for authentication and profile storage, OpenAI APIs for AI interaction and voice transcription, Google Maps services for place discovery and routing, and a Fly.io MCP server for map-related tool access.

## How to Run the Application

This project is a Flutter mobile application. It can be run locally on an Android emulator, a connected Android device, or Chrome for web testing.

### 1. Clone the Repository

```bash
git clone https://github.com/Jiangyue123456/wanderjoy_flutter.git
cd wanderjoy_flutter
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Add API Keys Securely

The app uses OpenAI and Google Maps services. For security reasons, real API keys are not committed to GitHub. I will send the required assessment testing keys to the module teacher by email. Please check the email provided with this submission.

When running the project, replace the placeholder values below with the private keys received by email:

```bash
flutter run \
  --dart-define=OPENAI_API_KEY=YOUR_OPENAI_API_KEY_FROM_EMAIL \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY_FROM_EMAIL
```

### 4. Run on Android

Start an Android emulator or connect an Android device, then run:

```bash
flutter run
```

If API-powered Explore features are being tested, use the `--dart-define` command shown above.

### 5. Run on Web for Quick Testing

```bash
flutter run -d chrome \
  --dart-define=OPENAI_API_KEY=YOUR_OPENAI_API_KEY_FROM_EMAIL \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY_FROM_EMAIL
```

### 6. Basic App Testing Flow

1. Open the app and sign in with Google if required. If Google sign-in does not work in the local testing environment, a Preview Mode is provided so the demo can still be viewed.
2. Open the Me tab to view or edit profile information used for personalization and matching.
3. Go to Explore Mode and enter a travel request by text or voice, such as an interest in art, food, culture, or nature.
4. Review the AI-recommended places, adjust the list if needed, and generate a route.
5. Start the trip navigation flow. The Open Map button launches the route in Google Maps, while photos or written notes can be saved inside WanderJoy as memories.
6. Go to Social Mode to view compatible nearby explorers, review profile and safety information, send a request, set a meeting point and time, complete the NFC-style meeting confirmation, and start a shared Explore flow.
7. Open Memory Mode to review saved trips with route context, photos, notes, timestamps, and companion information.

## Bibliography

1. Flutter. (2026). *Flutter documentation*. Available at: https://docs.flutter.dev/ (Accessed: 5 May 2026).

2. Firebase. (2026). *Firebase documentation*. Available at: https://firebase.google.com/docs (Accessed: 5 May 2026).

3. Google Maps Platform. (2026). *Google Maps Platform documentation*. Available at: https://developers.google.com/maps/documentation (Accessed: 5 May 2026).

4. OpenAI. (2026). *OpenAI API documentation*. Available at: https://platform.openai.com/docs (Accessed: 5 May 2026).

5. Model Context Protocol. (2026). *Model Context Protocol documentation*. Available at: https://modelcontextprotocol.io/ (Accessed: 5 May 2026).

6. Fly.io. (2026). *Fly.io documentation*. Available at: https://fly.io/docs/ (Accessed: 5 May 2026).

7. pub.dev. (2026). *Flutter package repository*. Available at: https://pub.dev/ (Accessed: 5 May 2026).

8. Komoot. (2026). *Komoot*. Available at: https://www.komoot.com/ (Accessed: 5 May 2026).

9. Polarsteps. (2026). *Polarsteps*. Available at: https://www.polarsteps.com/ (Accessed: 5 May 2026).

10. Atlas Obscura. (2026). *Atlas Obscura*. Available at: https://www.atlasobscura.com/ (Accessed: 5 May 2026).

11. Couchsurfing. (2026). *Couchsurfing*. Available at: https://www.couchsurfing.com/ (Accessed: 5 May 2026).

## Declaration of Authorship

I, Jiangyue Pei, confirm that the work presented in this assessment is my own. Where information has been derived from other sources, I confirm that this has been indicated in the work.

Digitally signed: Jiangyue Pei

Assessment date: 5 May 2026
