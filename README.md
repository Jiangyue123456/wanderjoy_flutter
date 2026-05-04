# WanderJoy Flutter

WanderJoy is a Flutter mobile app for playful, AI-assisted city exploration. It helps users describe what they want to do, discover real places, build a route, start navigation, meet compatible travel companions, and save route memories with photos.

## Background Research

Before building WanderJoy, I conducted desktop competitor research on four travel and exploration products: Komoot, Polarsteps, Atlas Obscura, and Couchsurfing. These references helped shape the app's direction around route planning, travel memory recording, unique place discovery, and social travel connection.

WanderJoy differs by combining AI-personalized place discovery, live route planning, social companion matching, and memory capture into one continuous travel flow instead of treating them as separate features.

![Background research overview](assets/readme/background_research.png)

## User Research

I also conducted a Wenjuanxing questionnaire survey with 100 valid responses to understand users' travel planning habits, pain points, social travel needs, and interest in adaptive route recommendations. The results showed strong demand for personalized place discovery, route planning based on physical state, travel memory recording, and safer companion matching.

![User research summary](assets/readme/user_research_summary.png)

## User Personas

Based on the survey insights, I created Lily as a target persona to represent new arrivals who want to understand a city, discover interest-based places, and build meaningful social connections through travel.

![User persona Lily](assets/readme/user_persona_lily.png)

## Design Process

The design process started with competitor research and user survey insights, then translated these findings into a target persona, design implications, and key user flows. WanderJoy was shaped around two main scenarios: AI-assisted personal exploration and safer social exploration. The prototype turns these needs into practical screens for profile setup, AI chat, place recommendation, route confirmation, companion matching, NFC meeting confirmation, shared exploration, and memory saving.

## Storyboard / User Journey

The user journey shows WanderJoy's three main flows: Explore Mode for personal AI-assisted exploration, Social Mode for safely meeting a compatible companion, and Memory for saving the route, photos, notes, locations, time points, and social companion context after a trip.

![Storyboard user journey](assets/readme/storyboard_user_journey_v2.png)

## App Screenshots / Prototype Screens

The screenshots below show the working Flutter prototype through the four main tabs: Explore, Social, Memory, and Me.

### Explore Tab

Explore Mode supports AI-assisted place discovery, route confirmation, trip navigation, and memory capture during the journey.

<table>
  <tr>
    <td><img src="assets/readme/screenshots/explore/1.png" width="220" alt="Explore screen 1"></td>
    <td><img src="assets/readme/screenshots/explore/2.png" width="220" alt="Explore screen 2"></td>
    <td><img src="assets/readme/screenshots/explore/3.png" width="220" alt="Explore screen 3"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/explore/4.png" width="220" alt="Explore screen 4"></td>
    <td><img src="assets/readme/screenshots/explore/5.png" width="220" alt="Explore screen 5"></td>
    <td><img src="assets/readme/screenshots/explore/6.png" width="220" alt="Explore screen 6"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/explore/7.png" width="220" alt="Explore screen 7"></td>
    <td><img src="assets/readme/screenshots/explore/8.png" width="220" alt="Explore screen 8"></td>
    <td><img src="assets/readme/screenshots/explore/9.png" width="220" alt="Explore screen 9"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/explore/10.png" width="220" alt="Explore screen 10"></td>
    <td><img src="assets/readme/screenshots/explore/11.png" width="220" alt="Explore screen 11"></td>
    <td><img src="assets/readme/screenshots/explore/12.png" width="220" alt="Explore screen 12"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/explore/13.png" width="220" alt="Explore screen 13"></td>
    <td><img src="assets/readme/screenshots/explore/14.png" width="220" alt="Explore screen 14"></td>
    <td></td>
  </tr>
</table>

### Social Tab

Social Mode helps users find compatible nearby explorers, review profile and safety signals, send a join request, choose a meeting point and time, confirm the offline meeting with NFC, and start a shared Explore flow.

<table>
  <tr>
    <td><img src="assets/readme/screenshots/social/1.png" width="220" alt="Social screen 1"></td>
    <td><img src="assets/readme/screenshots/social/2.png" width="220" alt="Social screen 2"></td>
    <td><img src="assets/readme/screenshots/social/3.png" width="220" alt="Social screen 3"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/social/4.png" width="220" alt="Social screen 4"></td>
    <td><img src="assets/readme/screenshots/social/5.png" width="220" alt="Social screen 5"></td>
    <td><img src="assets/readme/screenshots/social/6.png" width="220" alt="Social screen 6"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/social/7.png" width="220" alt="Social screen 7"></td>
    <td></td>
    <td></td>
  </tr>
</table>

### Memory Tab

Memory Mode stores route memories with map context, photos, text notes, visited stops, and social companion information.

<table>
  <tr>
    <td><img src="assets/readme/screenshots/memory/1.png" width="220" alt="Memory screen 1"></td>
    <td><img src="assets/readme/screenshots/memory/2.png" width="220" alt="Memory screen 2"></td>
    <td><img src="assets/readme/screenshots/memory/3.png" width="220" alt="Memory screen 3"></td>
  </tr>
  <tr>
    <td><img src="assets/readme/screenshots/memory/4.png" width="220" alt="Memory screen 4"></td>
    <td></td>
    <td></td>
  </tr>
</table>

### Me Tab

The profile tab contains the user's identity, interests, preferred travel intensity, bio, and safety rating used for personalization and matching.

<table>
  <tr>
    <td><img src="assets/readme/screenshots/me/1.png" width="220" alt="Profile screen 1"></td>
    <td><img src="assets/readme/screenshots/me/2.png" width="220" alt="Profile screen 2"></td>
    <td></td>
  </tr>
</table>

## Core Features

- Google sign-in with Firebase Authentication
- AI-assisted Explore Mode with text and voice input
- OpenAI-powered voice transcription
- Real-place recommendations using OpenAI Responses API with Google Maps MCP
- Manual Google Maps place search and place detail loading
- Route planning with Google Directions API, OpenAI route planning fallback, and local estimated routing
- Live location updates, distance estimates, navigation cues, and Google Maps launch links
- Social Mode with local travel-companion matching
- Shared Explore flow that reuses the Explore route planner for two users
- Profile editing with Firestore persistence
- Route memory capture with photos, notes, map snapshots, and companion context

## Project Structure

```text
wanderjoy_flutter/
|-- lib/                         # Main Flutter application source code.
|   |-- main.dart                # App entry point; initializes Firebase and starts WanderJoyApp.
|   |-- app/                     # Root app setup, shell navigation, and authentication flow.
|   |   |-- wanderjoy_app.dart   # Creates MaterialApp, applies theme, and loads AuthGate.
|   |   |-- app_shell.dart       # Main signed-in shell with Explore, Social, Memory, and Me tabs.
|   |   `-- auth/                # Google/Firebase sign-in and preview-mode screens.
|   |       |-- auth_gate.dart   # Routes users to LoginScreen or AppShell based on auth state.
|   |       |-- auth_service.dart # Handles Google sign-in, Firebase auth, sign-out, and preview mode.
|   |       `-- login_screen.dart # Login UI with Google sign-in and preview access.
|   |-- core/                    # Shared app foundation code.
|   |   `-- theme/               # Global visual design tokens and Material theme.
|   |       |-- app_colors.dart   # Central color palette.
|   |       |-- app_spacing.dart  # Shared spacing constants.
|   |       `-- app_theme.dart    # Material 3 theme and text styles.
|   |-- features/                # Main product features.
|   |   |-- explore/             # AI place recommendation, route planning, maps, voice, and memories.
|   |   |-- social/              # Local companion matching, request flow, NFC-style launch, shared Explore.
|   |   |-- memory/              # Saved trip memories, route snapshots, companion history, photo views.
|   |   `-- me/                  # Profile editing, Firestore profile storage, avatar selection, sign-out.
|   `-- shared/                  # Reusable app-wide data, models, and UI widgets.
|       |-- data/                # Mock users, places, and sample memories for the prototype.
|       |-- models/              # Core data models such as Poi, UserProfile, and MemoryEntry.
|       `-- widgets/             # Shared UI components like cards, buttons, header, and bottom nav.
|-- test/                        # Flutter tests.
|-- android/                     # Android platform project.
|-- ios/                         # iOS platform project.
|-- web/                         # Web platform project.
|-- linux/                       # Linux desktop platform project.
|-- macos/                       # macOS desktop platform project.
|-- windows/                     # Windows desktop platform project.
|-- pubspec.yaml                 # Flutter package metadata, dependencies, and asset configuration.
`-- README.md                    # Project documentation.
```

## Application Flow

1. `main.dart` initializes Flutter and Firebase, then starts `WanderJoyApp`.
2. `WanderJoyApp` sets the Material theme and loads the authentication gate.
3. `AuthGate` decides whether the user should see the login screen or the main app shell.
4. `AppShell` provides the four main tabs: Explore, Social, Memory, and Me.

## Technical Implementation

### 1. Technology Stack

- Frontend framework: Flutter and Dart.
- AI APIs: OpenAI Responses API for place recommendation and route planning, plus OpenAI Audio Transcription API for voice input.
- Agent workflow: a custom Explore Agent built with developer prompts, structured JSON schema outputs, retry prompts, and Google Maps MCP tool access.
- MCP integration: Google Maps MCP server connected through OpenAI tool calling and deployed at `https://wanderjoyflutter.fly.dev/mcp` on Fly.io.
- Google APIs: Google Places Details API, Google Place Photos API, Google Directions API, Google Maps JavaScript map inside WebView, Google Maps launch URLs, and Google sign-in.
- Firebase: Firebase Authentication and Cloud Firestore.
- Device features: location permission/current location, audio recording, image picking, local file storage, and external map launching.

### 2. Authentication

- Main folder: `lib/app/auth/`
- Google sign-in is handled through `google_sign_in`.
- Firebase Authentication stores the signed-in user session.
- Firestore stores profile data used by Explore Mode and Social Mode.

### 3. Explore Mode

- Main folder: `lib/features/explore/`
- Main flow: `input -> customize -> route -> trip navigation -> taking pictures and writing notes`
- Users can type a request or record voice input with `record`.
- `VoiceTranscriptionService` sends recorded audio to OpenAI Audio Transcription and places the transcript back into the chat input.
- `ExploreAgentService` sends the user's request, interests, bio, travel intensity, current location, and optional social trip context to the OpenAI Responses API.
- The Explore Agent uses developer/system-style prompts and strict JSON schemas so OpenAI returns structured place and route data instead of free text.
- Real place discovery uses the Fly.io Google Maps MCP server through OpenAI tool calling.
- Google Places Details and Photos enrich each POI with ratings, opening status, photos, reviews, and Google Maps links.
- Users can keep, remove, search, or manually add places before confirming the route.
- Route generation uses Google Directions API first, then falls back to AI route planning through MCP or local estimated routing.
- Route display uses a Google Maps WebView when an API key is available, with a custom estimated map fallback.
- Navigation uses `geolocator` for live location, distance estimates, route cues, and Google Maps launch links.

### 4. Social Mode

- Main folder: `lib/features/social/`
- Main flow: `nearby -> profile -> request -> setup -> nfc -> sharedExplore`
- Social Mode is implemented in the Flutter frontend and does not require a backend.
- Local mock users are ranked by shared interests, travel intensity, safety rating, bio keywords, and distance.
- After a match, users can send a join request, choose a meeting time, and confirm the offline meeting with an NFC-style interaction.
- The shared trip then reuses Explore Mode by passing an `ExploreTripContext` into `ExploreScreen`.

### 5. Memory Mode

- Main folder: `lib/features/memory/`
- Route memories are stored through `MemoryRepository`.
- Each memory can include photos, notes, route points, visited stops, timestamps, and companion context.
- `ValueNotifier<List<MemoryEntry>>` updates the Memory screen immediately when a new memory is saved.
- Saved route maps are rebuilt with Google Maps inside WebView, including route lines, numbered stops, and photo pins.
- Memory Mode displays both personal Explore trips and Social trips with companion information.

### 6. Me / Profile Mode

- Main folder: `lib/features/me/`
- Users can edit avatar, display name, age, interests, preferred travel intensity, safety rating, and bio.
- Profile data is saved in Firestore under `profiles/{uid}`.
- Profile information is reused by Explore Mode for personalized recommendations and by Social Mode for matching.

### 7. Shared Data Models

- Main file: `lib/shared/models/app_models.dart`
- Key models: `UserProfile`, `Poi`, `ExploreTripContext`, `MemoryEntry`, and `MemoryRouteSnapshot`

These models connect the app's main features: Explore creates routes, Social passes companion context into Explore, Explore saves route memories, and Memory displays the saved trips.

### 8. External Services and Configuration

Full functionality uses these configuration values:

```text
OPENAI_API_KEY
OPENAI_MODEL
OPENAI_TRANSCRIBE_MODEL
GOOGLE_MAPS_API_KEY
```

Firebase must also be configured for Google sign-in, authentication state, Firestore profile storage, and saved user data. The OpenAI requests use the configured MCP server URL to access Google Maps tools through the Fly.io server.

### 9. Main Dependencies

- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Authentication: `google_sign_in`
- AI and network requests: `http`, OpenAI API
- Voice input: `record`
- Maps and location: `google_maps_flutter`, `geolocator`, `url_launcher`, `webview_flutter`
- Media and local files: `image_picker`, `path_provider`
