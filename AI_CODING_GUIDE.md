# AI Coding Guide — Eduverse (edtech) Project

> **Purpose**: Give this file to any AI (including me) before asking them to add a feature or implement an API. It explains the project's architecture, patterns, and conventions so the AI can code correctly from the start.
>
> **Also read**: [`project_performance_planner.md`](project_performance_planner.md) — performance optimization guide, API integration patterns, and anti-patterns to avoid.

---

## 17. Ad-Supported Video Playback Architecture (YouTube-Style)

### 17.1 Overview

Eduverse supports **YouTube-style ad-supported video playback**. Ads are **not** from a third-party SDK (AdMob, etc.) — the backend provides both the main video URL and ad video URLs in a single API response. The app orchestrates the playback timeline: pre-roll ad → main video → optional mid-roll ads → end.

```
API Response
  │
  ├── videoUrl         →  Main lesson/content video
  ├── title / duration
  └── ads[]            →  List of ad placements
       ├── type: "pre_roll"       (plays before main video)
       ├── type: "mid_roll"       (plays at atTimestamp)
       ├── adUrl                  (the ad video file)
       ├── skipAfterSeconds       (when the skip button appears)
       └── durationSeconds        (total ad length)
```

### 17.2 Backend Contract (Expected API Shape)

The backend endpoint for fetching a lesson video should return:

```json
{
  "success": true,
  "statusCode": 200,
  "data": {
    "videoUrl": "https://cdn.eduverse.com/videos/algebra-101-lesson1.mp4",
    "title": "Introduction to Algebra",
    "duration": 600,
    "thumbnail": "https://cdn.eduverse.com/thumbnails/algebra-101-lesson1.jpg",

    "ads": [
      {
        "id": "ad_pre_001",
        "type": "pre_roll",
        "adUrl": "https://cdn.eduverse.com/ads/sponsor-30s.mp4",
        "skipAfterSeconds": 5,
        "durationSeconds": 30
      },
      {
        "id": "ad_mid_001",
        "type": "mid_roll",
        "atTimestamp": 120,
        "adUrl": "https://cdn.eduverse.com/ads/course-promo-20s.mp4",
        "skipAfterSeconds": 5,
        "durationSeconds": 20
      }
    ]
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `videoUrl` | string | Yes | Direct URL to the main video file (MP4, HLS, etc.) |
| `title` | string | Yes | Display title for the video player |
| `duration` | number | No | Total video duration in seconds (for progress bar) |
| `thumbnail` | string | No | Thumbnail image URL for the video card/placeholder |
| `ads` | array | No | List of ad placements. Omit/empty array → no ads |
| `ads[].id` | string | Yes | Unique ad identifier (for tracking/skip persistance) |
| `ads[].type` | string | Yes | `"pre_roll"` or `"mid_roll"` |
| `ads[].adUrl` | string | Yes | URL to the ad video file |
| `ads[].skipAfterSeconds` | number | Yes | Seconds after which the "Skip" button appears (YouTube: 5s) |
| `ads[].durationSeconds` | number | Yes | Total length of the ad in seconds |
| `ads[].atTimestamp` | number | Only for mid_roll | When during the main video this ad triggers (in seconds) |

### 17.3 Ad Playback Flow (YouTube-Style)

```
User taps video thumbnail
        │
        ▼
  VideoWithAdsProvider.loadVideo(videoId)
        │  Fetches videoUrl + ads[] from API
        ▼
  ┌─────────────────────────────────────────┐
  │         PRE-ROLL AD PHASE               │
  │                                         │
  │  ▶ Ad video starts playing              │
  │  ┌─────────────────┐                    │
  │  │ Countdown: 5...4...3...2...1         │  ← skipAfterSeconds timer
  │  │ [Skip Ad] button appears             │  ← after timer expires
  │  └─────────────────┘                    │
  │                                         │
  │  User taps "Skip Ad"  OR  ad finishes   │
  └─────────────────────────────────────────┘
        │
        ▼
  ┌─────────────────────────────────────────┐
  │         MAIN VIDEO PHASE                │
  │                                         │
  │  ▶ Main video starts/resumes            │
  │  ◉ Normal playback controls             │
  │  ⏱ Provider tracks current position     │
  └─────────────────────────────────────────┘
        │
        ▼  (when position reaches mid_roll's atTimestamp)
        │
  ┌─────────────────────────────────────────┐
  │         MID-ROLL AD PHASE               │
  │                                         │
  │  ▶ Main video paused                    │
  │  ▶ Ad video plays (same skip flow)      │
  │  ┌─────────────────┐                    │
  │  │ Countdown: 5...4...3...2...1         │
  │  │ [Skip Ad] button appears             │
  │  └─────────────────┘                    │
  │                                         │
  │  User taps "Skip"  OR  ad finishes      │
  └─────────────────────────────────────────┘
        │
        ▼
  ┌─────────────────────────────────────────┐
  │   MAIN VIDEO RESUMES FROM PAUSE         │
  │                                         │
  │  ...multiple mid-rolls possible...      │
  │                                         │
  │  When main video ends → show end screen │
  └─────────────────────────────────────────┘
```

### 17.4 Provider State Machine

The [`VideoWithAdsProvider`](#) manages a strict state machine:

```
                  ┌──────────┐
                  │   IDLE   │
                  └────┬─────┘
                       │ loadVideo()
                       ▼
                  ┌──────────┐
                  │ LOADING  │  ← Fetch video+ad data from API
                  └────┬─────┘
                       │ data loaded
                       ▼
            ┌─────────────────────┐
            │ AD_PLAYING (pre)    │  ← hasAds && pre_roll exists
            └──────────┬──────────┘
                       │ ad skipped/finished
                       ▼
            ┌─────────────────────┐
            │  VIDEO_PLAYING      │  ← Main video playing
            └──────────┬──────────┘
                       │ mid_roll ad triggered (atTimestamp reached)
                       ▼
            ┌─────────────────────┐
            │ AD_PLAYING (mid)    │  ← Mid-roll ad
            └──────────┬──────────┘
                       │ ad skipped/finished
                       ▼
            ┌─────────────────────┐
            │  VIDEO_PLAYING      │  ← Resume
            └──────────┬──────────┘
                       │ (repeat for each mid_roll)
                       │ video ends
                       ▼
                  ┌──────────┐
                  │ FINISHED │
                  └──────────┘
```

| State | Description |
|-------|-------------|
| `VideoPlayerState.idle` | Initial state, no video loaded |
| `VideoPlayerState.loading` | Fetching video+ad data from the backend |
| `VideoPlayerState.adPlaying` | An ad is currently playing (pre-roll or mid-roll). Provider tracks `currentAdIndex` and `adType` |
| `VideoPlayerState.videoPlaying` | Main content video is playing. Provider tracks `videoPosition` to check for mid-roll triggers |
| `VideoPlayerState.finished` | Video has ended (optionally show end screen) |

### 17.5 Skip Mechanism (YouTube-Style Countdown)

When an ad starts playing:

1. A timer begins counting down from `skipAfterSeconds`
2. During the countdown, the UI shows: **"Skip ad in X"** (dimmed, non-tappable)
3. When the timer reaches 0, a **"Skip Ad"** button appears (tappable, highlighted)
4. If the user taps "Skip" → ad stops → main video resumes
5. If the ad plays to completion (reaches `durationSeconds`) → automatically transition to main video

```dart
// Conceptual skip-timer logic inside VideoWithAdsProvider:
Timer? _skipTimer;
int _skipCountdown = 0;

void _startAdSkipTimer(int skipAfterSeconds) {
  _skipCountdown = skipAfterSeconds;
  _skipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _skipCountdown--;
    notifyListeners();
    if (_skipCountdown <= 0) {
      timer.cancel();
      _canSkipAd = true;
      notifyListeners();
    }
  });
}

void skipAd() {
  _skipTimer?.cancel();
  _transitionToNextPhase(); // → video or next ad
}
```

### 17.6 Data Model Updates Required

#### New: `AdEntity` (domain) / `AdModel` (data)

```dart
class AdEntity {
  final String id;
  final String type;          // "pre_roll" | "mid_roll"
  final String adUrl;         // Ad video URL
  final int skipAfterSeconds; // When skip button appears
  final int durationSeconds;  // Total ad length
  final int? atTimestamp;     // For mid_roll: when to trigger (seconds into main video)

  const AdEntity({
    required this.id,
    required this.type,
    required this.adUrl,
    required this.skipAfterSeconds,
    required this.durationSeconds,
    this.atTimestamp,
  });
}
```

#### New: `VideoWithAdsEntity` (domain)

```dart
class VideoWithAdsEntity {
  final String videoUrl;
  final String title;
  final int duration;           // seconds
  final String? thumbnail;
  final List<AdEntity> ads;     // empty list = no ads

  bool get hasPreRoll => ads.any((a) => a.type == 'pre_roll');
  List<AdEntity> get midRollAds => ads.where((a) => a.type == 'mid_roll').toList();
}
```

#### Updated: `LessonEntity` — add video + ad fields

```dart
class LessonEntity {
  final String title;
  final String duration;          // Display duration string (e.g. "18:20")
  final bool isLocked;
  final String? videoUrl;         // NEW: URL to the lesson video
  final String? thumbnailUrl;     // NEW: Thumbnail image URL
  final List<AdEntity>? ads;      // NEW: Ad placements (null = backend decides none)

  const LessonEntity({
    required this.title,
    required this.duration,
    this.isLocked = true,
    this.videoUrl,
    this.thumbnailUrl,
    this.ads,
  });
}
```

#### Updated: `ProfileVideo` — optionally support ads

```dart
class ProfileVideo {
  final String image;    // Video URL or thumbnail URL (kept as-is)
  final String title;
  final List<AdEntity>? ads;  // NEW: optional ad placements

  const ProfileVideo({
    required this.image,
    required this.title,
    this.ads,
  });
}
```

### 17.7 Provider: `VideoWithAdsProvider`

```dart
class VideoWithAdsProvider extends ChangeNotifier {
  // ── Dependencies ──
  final GetVideoWithAdsUseCase getVideoWithAdsUseCase;

  // ── State ──
  VideoPlayerState _state = VideoPlayerState.idle;
  VideoPlayerState get state => _state;

  VideoWithAdsEntity? _videoData;
  VideoWithAdsEntity? get videoData => _videoData;

  int _currentAdIndex = 0;
  bool _canSkipAd = false;
  int _skipCountdown = 0;
  Duration _videoPausePosition = Duration.zero;

  // ── Main public method ──
  Future<void> loadVideo(String videoId) async {
    _state = VideoPlayerState.loading;
    notifyListeners();

    final result = await getVideoWithAdsUseCase(VideoWithAdsParams(videoId: videoId));
    result.fold(
      (failure) {
        _state = VideoPlayerState.error;
        _errorMessage = failure.message;
        ToastService.showError(failure.message);
        notifyListeners();
      },
      (data) {
        _videoData = data;
        if (data.hasPreRoll) {
          _currentAdIndex = 0;
          _state = VideoPlayerState.adPlaying;
          _startAdSkipTimer(data.ads.first.skipAfterSeconds);
        } else {
          _state = VideoPlayerState.videoPlaying;
        }
        notifyListeners();
      },
    );
  }

  void onAdFinished() { /* transition to video or next ad */ }
  void onVideoPositionChanged(Duration position) { /* check mid_roll triggers */ }
  void skipAd() { /* cancel timer, transition */ }
  void dispose() { _skipTimer?.cancel(); super.dispose(); }
}

enum VideoPlayerState { idle, loading, adPlaying, videoPlaying, finished, error }
```

### 17.8 UI: `VideoWithAdsPlayerScreen`

This screen replaces the existing `VideoPlayerScreen` for ad-supported content. It uses a **single `VideoPlayerController`** and swaps the source URL between ad video and main video.

```dart
class VideoWithAdsPlayerScreen extends StatefulWidget {
  final String videoId;   // ID to fetch video+ad data from backend
  // ...
}

// Key UI elements:
// 1. Stack with VideoPlayer (plays both ad and main video via controller swap)
// 2. Ad overlay (shows during adPlaying state):
//    - Semi-transparent bottom bar
//    - "Skip ad in X" countdown (non-tappable)
//    - "Skip Ad" button (tappable, appears after timer)
// 3. Normal video controls overlay (during videoPlaying state):
//    - Same as existing VideoPlayerScreen (top bar, center play/pause, bottom progress)
// 4. Graceful handling for no-ads case:
//    - If ads list is empty, behaves exactly like the current VideoPlayerScreen
```

**Ad overlay widget** (shown on top of the video during `AD_PLAYING` state):

```
┌──────────────────────────────┐
│                              │
│        AD IS PLAYING         │  ← Video of the ad
│                              │
│                              │
│                              │
│                              │
├──────────────────────────────┤
│  Ad • 0:15 / 0:30            │  ← Small label
│  ┌──────────────────────┐    │
│  │  Skip ad in 3...     │    │  ← Countdown (before skip available)
│  │  [Skip Ad]           │    │  ← Button (after timer, tappable)
│  └──────────────────────┘    │
└──────────────────────────────┘
```

### 17.9 Integration Points

| Integration | What Changes |
|-------------|-------------|
| **Course Details → Video** | `LessonRowTile.onTap` navigates to `VideoWithAdsPlayerScreen(videoId: lesson.id)` instead of just highlighting |
| **Enrolled Course → Video** | Same integration — `LessonRowTile` in enrolled mode navigates to player with videoId |
| **Profile Videos** | `VideosHorizontalListView` → on tap navigates to `VideoWithAdsPlayerScreen` instead of inline player. Or: keep inline player for short profile videos and use full-screen player for course lessons |
| **Hub → Ad Account** | The existing static "Ad Account" menu tile can be wired to a stats/analytics page showing ad performance |

### 17.10 Single VideoPlayerController Pattern (Swapping Sources)

The key technical challenge is swapping the video source without disposing the controller. There are two approaches:

#### Approach A: Single Controller with `_controller.pause()` + source swap
- Initialize controller with ad URL
- When ad ends → dispose controller → create new controller with main video URL
- **Pros**: Clean separation, no overlap
- **Cons**: Brief loading state between transitions, loses position tracking

#### Approach B: Two controllers with visibility toggle
- Maintain two `VideoPlayerController` instances (ad + main)
- Only one is visible at a time via `Opacity` / `IndexedStack`
- **Pros**: No loading between transitions, main video continues buffering during ad
- **Cons**: Memory overhead (two controllers), sync complexity

**Recommended: Approach A** (simpler, matches the app's existing pattern, lower memory footprint). The loading gap is acceptable (similar to YouTube's brief "Video will play after ad" transition).

```dart
void _playAd(AdEntity ad) {
  _adController?.dispose();
  _adController = VideoPlayerController.networkUrl(Uri.parse(ad.adUrl));
  _adController!.initialize().then((_) {
    _adController!.play();
    _startAdSkipTimer(ad.skipAfterSeconds);
    notifyListeners();
  });
}

void _transitionToMainVideo() {
  _adController?.dispose();
  _adController = null;

  _mainController?.dispose();
  _mainController = VideoPlayerController.networkUrl(
    Uri.parse(_videoData!.videoUrl),
  );
  if (_videoPausePosition > Duration.zero) {
    _mainController!.seekTo(_videoPausePosition);
  }
  _mainController!.initialize().then((_) {
    _mainController!.play();
    _state = VideoPlayerState.videoPlaying;
    notifyListeners();
  });
}
```

### 17.11 Mid-Roll Trigger Mechanism

During `VIDEO_PLAYING` state, a periodic listener checks the current position against the mid-roll schedule:

```dart
Timer? _positionTracker;

void _startPositionTracker() {
  _positionTracker = Timer.periodic(const Duration(seconds: 1), (_) {
    final pos = _mainController?.value.position ?? Duration.zero;
    final posSeconds = pos.inSeconds;

    for (final ad in _videoData!.midRollAds) {
      if (ad.atTimestamp != null &&
          posSeconds >= ad.atTimestamp! &&
          !_triggeredAdIds.contains(ad.id)) {
        _triggerAd(ad);
        break;
      }
    }
  });
}
```

Uses a `Set<String> _triggeredAdIds` to ensure each mid-roll ad fires only once per viewing session.

### 17.12 Error Handling & Edge Cases

| Scenario | Behavior |
|----------|----------|
| **Ad fails to load** | Skip the ad, go directly to main video. Show a brief snackbar: "Ad skipped" |
| **Main video fails to load** | Show error state with retry button (existing pattern) |
| **No ads in response** | Play main video directly (no ad phase) — behaves like current `VideoPlayerScreen` |
| **Skip timer reaches 0** | Show "Skip Ad" button |
| **User taps skip before timer** | Ignore (button is hidden) |
| **Multiple mid-roll ads at same timestamp** | Play them sequentially (order in the ads array) |
| **Video seek** | If user seeks past a mid-roll timestamp, the mid-roll is NOT retroactively triggered (only fires on forward playback crossing the timestamp) |
| **App goes to background during ad** | Pause video + timer. Resume on foreground |
| **Slow network** | Loading spinner overlay during transition between ad and main video |

### 17.13 Directory Structure (New `media_kit` Video Feature)

  lib/features/video_player/              # NEW: Shared video player feature
├── data/
│   ├── datasources/
│   │   └── video_remote_data_source.dart   # GET /videos/{id} with ads
│   ├── models/
│   │   ├── video_with_ads_model.dart       # fromJson → VideoWithAdsEntity
│   │   └── ad_model.dart                   # fromJson → AdEntity
│   └── repositories/
│       └── video_repository_impl.dart     # VideoRepositoryImpl
├── domain/
│   ├── entities/
│   │   ├── video_with_ads_entity.dart     # VideoWithAdsEntity
│   │   └── ad_entity.dart                 # AdEntity
│   ├── repositories/
│   │   └── video_repository.dart          # abstract interface
│   └── usecases/
│       └── get_video_with_ads_usecase.dart # GetVideoWithAdsUseCase
└── presentation/
    ├── providers/
    │   └── video_with_ads_provider.dart   # VideoWithAdsProvider (state machine)
    ├── pages/
    │   └── video_with_ads_player_screen.dart  # Full-screen player with ad overlay
    └── widgets/
        ├── ad_overlay.dart               # Skip timer + skip button overlay
        └── ad_countdown_timer.dart        # Reusable countdown timer widget
```

### 17.14 Implementation Order (Recommended)

| Step | What | Files |
|------|------|-------|
| 1 | Create `AdEntity` + `VideoWithAdsEntity` domain entities | `ad_entity.dart`, `video_with_ads_entity.dart` |
| 2 | Add `videoUrl`, `thumbnailUrl`, `ads` to `LessonEntity` | `lesson_entity.dart` |
| 3 | Create `AdModel` + `VideoWithAdsModel` with `fromJson` | `ad_model.dart`, `video_with_ads_model.dart` |
| 4 | Create `VideoRemoteDataSource` (GET endpoint) + `VideoRepository` (abstract) + `VideoRepositoryImpl` | Video data source + repository |
| 5 | Create `GetVideoWithAdsUseCase` | `get_video_with_ads_usecase.dart` |
| 6 | Create `VideoWithAdsProvider` (state machine with skip timer + mid-roll tracking) | `video_with_ads_provider.dart` |
| 7 | Create `AdOverlay` widget (countdown timer + skip button) | `ad_overlay.dart` |
| 8 | Create `VideoWithAdsPlayerScreen` (single controller, source swapping) | `video_with_ads_player_screen.dart` |
| 9 | Wire DI in `provider_setup.dart` | Data source → Repository → Use Case → Provider |
| 10 | Integrate `LessonRowTile.onTap` → navigate to `VideoWithAdsPlayerScreen` | `lesson_row_tile.dart`, `course_details_page.dart`, `enrolled_course_page.dart` |
| 11 | (Optional) Wire profile `VideosHorizontalListView` → full-screen ad player | `video_list_section.dart` |
| 12 | Test: pre-roll, mid-roll, skip, no-ads, error states | — |

### 17.15 Key Design Decisions Summary

| Decision | Rationale |
|----------|-----------|
| **No third-party ad SDK** | Backend provides ad video URLs directly. No AdMob, no VAST parsing, no complex ad networks. Simpler, cheaper, full control. |
| **Single `VideoPlayerController` (swap source)** | Avoids memory overhead of dual controllers. Loading gap between transitions is acceptable (matches YouTube pattern). |
| **Provider state machine** | Clear, testable states. Prevents invalid transitions (e.g., skip during IDLE). |
| **Skip timer in provider (not widget)** | Timer survives widget rebuilds. Provider can manage skip state independently of UI. |
| **Mid-roll triggered by position tracker** | `Timer.periodic(1s)` checks against `_triggeredAdIds` set. Efficient, no position-polling on every frame. |
| **Backend controls everything** | Ad count, timing, skip duration, and URLs all come from the API. No hardcoded ad logic in the app. |
| **Profile videos can also have ads** | `ProfileVideo.ads` is optional (nullable). Backend decides which profile videos get ads. |

### 17.16 Migration from Current `VideoPlayerScreen`

The existing [`VideoPlayerScreen`](lib/features/profile/student/presentation/widgets/video_player_screen.dart) is a simple player with no ad support. Migration path:

1. Keep `VideoPlayerScreen` as-is for cases that never need ads (e.g., profile videos if backend doesn't serve ads for them)
2. Create `VideoWithAdsPlayerScreen` for course lesson videos
3. If profile videos also get ads, migrate profile's `VideosHorizontalListView` to use the new player
4. The new screen shares the same visual style (black background, gradient bars, white text) — visual consistency is maintained

---


Eduverse is a Flutter EdTech app (package name: `edtech`) using **Feature-First Clean Architecture** with **Provider** for state management.

### Tech Stack. Dart SDK `^3.11.1`.

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart |
| Architecture | Feature-First Clean Architecture |
| State Management | Provider (`ChangeNotifierProvider` + `ProxyProvider`) |
| Functional Errors | `dartz` (`Either<Failure, Type>`) |
| Networking | `http` package + `AuthHttpClient` (401 interceptor wrapper with whitelist-based bypass) |
| Secure Storage | `flutter_secure_storage` |
| Persistent Storage | `shared_preferences` |
| Logging | `logger` (PrettyPrinter) |
| Messages (SnackBars) | `ToastService` (uses floating `SnackBar` via global `scaffoldMessengerKey` — no more `fluttertoast`) |
| Fonts | `google_fonts` (Urbanist, w500 body / w700 title) |
| Auth | `google_sign_in` |
| SVG Rendering | `flutter_svg` |
| Video Playback | `media_kit` + `media_kit_video` (mpv/FFmpeg native decoders) |
| URL Launching | `url_launcher` | Social link URL launching via `LaunchMode.externalApplication` |
| Image Picker | `image_picker` |
| Image Cropper | `image_cropper` |
| Dotted Border | `dotted_border` |
| Image Caching | `cached_network_image` — replaces all raw `NetworkImage`/`Image.network` across the app |
| Theme Colors | `Theme.of(context).colorScheme` via `cs` shorthand; global `InputDecorationTheme` in [`app_theme.dart`](lib/global/core/theme/app_theme.dart); scaffold bg: `#FCFCFD` (light), input fill: `Colors.white` (light) / `#1F2937` (dark), border: `#EFEFF0` |
| Dark Mode | [`ThemeProvider`](lib/global/core/theme/theme_provider.dart) — `ChangeNotifier` that persists to `SharedPreferences`, wired via `Consumer` in `main.dart` setting `themeMode` on `MaterialApp` |

### 9 Focused Providers (Refactored from Monolith)

| Provider | File | Responsibilities |
|----------|------|-----------------|
| `ThemeProvider` | [`theme_provider.dart`](lib/global/core/theme/theme_provider.dart) | Dark mode toggle with `SharedPreferences` persistence; exposes `themeMode` / `isDarkMode`; registered first in `_uiProviders`; consumed via `Consumer<ThemeProvider>` in `main.dart` to set `themeMode` on `MaterialApp` |
| `AuthProvider` | [`auth_provider.dart`](lib/features/auth/presentation/providers/auth_provider.dart) | Login, register, logout, Google sign-in, token refresh, password visibility |
| `EmailVerificationProvider` | [`email_verification_provider.dart`](lib/features/auth/presentation/providers/email_verification_provider.dart) | Verify email, resend code, 30s cooldown timer |
| `PasswordResetProvider` | [`password_reset_provider.dart`](lib/features/auth/presentation/providers/password_reset_provider.dart) | Forgot password, verify reset OTP, reset password, 30s timer |
| `StudentProfileProvider` | [`student_profile_provider.dart`](lib/features/profile/student/presentation/providers/student_profile_provider.dart) | Fetch student profile from `profile/me` endpoint; exposes `clearProfile()` for logout state reset; videos come from API directly (no dummy injection) |
| `MentorProfileProvider` | [`mentor_profile_provider.dart`](lib/features/profile/mentor/presentation/providers/mentor_profile_provider.dart) | Fetch mentor profile from `profile/me` endpoint (shared endpoint with student); exposes `refreshProfile()` for edit-then-sync and `clearProfile()` for logout; videos come from API directly (no dummy injection) |
| `EditProfileProvider` | [`edit_profile_provider.dart`](lib/features/profile/student/presentation/providers/edit_profile_provider.dart) | Update profile fields (name, username, bio, social links, etc.) via `profile/update` endpoint (PUT) |
| `EditProfilePage` | [`profile_editing_page.dart`](lib/features/profile/edit/presentation/profile_editing_page.dart) | Reads profile data from **both** `StudentProfileProvider` and `MentorProfileProvider` (fallback chain) to pre-fill form fields — works regardless of which profile page navigated to it |
| `AvatarUploadProvider` | [`avatar_upload_provider.dart`](lib/features/profile/avatar/presentation/providers/avatar_upload_provider.dart) | Complete 5-step avatar upload flow: `pickImage()` (full phone quality, no downsampling) → [`CustomCropScreen`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) (interactive crop with dotted_border guide, 1:1 square, 1024×1024, quality 95) → `uploadAvatarFromFile()` → get presigned S3 URL → streamed S3 upload (64KB chunks) → confirm; try-catch wrapping around pick/crop prevents OOM crashes; **re-entry guard** (`_isCropping` flag) prevents native Android `IllegalStateException: Reply already submitted` caused by double-tap; configurable upload timeout (120s); `onUploadSuccess` callback pattern for syncing updated avatar URL back to profile providers |
| `CoverUploadProvider` | [`cover_upload_provider.dart`](lib/features/profile/avatar/presentation/providers/cover_upload_provider.dart) | Complete 5-step cover photo upload flow: `pickImage()` (full phone quality, no downsampling) → [`CustomCropScreen`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) (interactive crop with dotted_border guide, 16:9, 1920×1080, quality 92) → `uploadCoverFromFile()` → get presigned S3 URL → streamed S3 upload (64KB chunks) → confirm; try-catch wrapping for crash prevention; **re-entry guard** (`_isCropping` flag) prevents native Android crash; configurable upload timeout (120s); `onUploadSuccess` callback for syncing updated cover URL back to profile providers |

---

## 2. Directory Structure

```
lib/
├── features/                         # Feature-based modules
│   ├── auth/                         # Login, Register, Password Recovery
│   │   ├── data/
│   │   │   ├── datasources/          # AuthRemoteDataSource + AuthEndpoints
│   │   │   ├── mappers/              # registerParamsToJson(), updateProfileParamsToJson()
│   │   │   ├── models/               # UserModel (fromJson → UserEntity)
│   │   │   ├── repositories/         # AuthRepositoryImpl
│   │   │   └── services/             # GoogleSignInService (wraps google_sign_in SDK)
│   │   ├── domain/
│   │   │   ├── entities/             # UserEntity (Equatable)
│   │   │   ├── repositories/         # AuthRepository (abstract)
│   │   │   └── usecases/             # 11 use cases (Login, Register, GoogleSignIn, etc.)
│   │   └── presentation/
│   │       ├── pages/                # login, register, verification, etc.
│   │       ├── providers/            # AuthProvider, EmailVerificationProvider, PasswordResetProvider
│   │       └── widgets/              # CustomTextField (AuthButton & AppBackButton moved to global)
│   ├── hub/                          # Hub/Settings tab (index 3 in MainNavShell)
│   │   └── presentation/
│   │       └── pages/                # hub_page.dart (StatefulWidget, fetches profile on init)
│   ├── social/                       # Social feed tab (index 0 in MainNavShell)
│   │   └── presentation/
│   │       └── pages/                # social_page.dart
│   ├── courses/                      # Courses tab + course details
│   │   └── presentation/
│   │       ├── pages/                # courses_page.dart, course_details_page.dart, enrolled_course_page.dart
│   │       └── widgets/              # course_expandable_container.dart, lesson_row_tile.dart, etc.
│   ├── home/                         # MainNavShell + bottom nav hosting
│   ├── splash/                       # Splash page (auto-login via token refresh)
│   ├── profile/
│   │   ├── avatar/                   # Shared avatar & cover upload feature (used by both student & mentor)
│   │   │   ├── data/
│   │   │   │   ├── datasources/      # AvatarRemoteDataSource (profile/avatar/upload-url, profile/avatar/confirm, profile/cover/upload-url, profile/cover/confirm)
│   │   │   │   ├── models/           # AvatarUploadUrlModel (uploadUrl + fileUrl)
│   │   │   │   └── repositories/     # AvatarRepositoryImpl
│   │   │   ├── domain/
│   │   │   │   ├── repositories/     # AvatarRepository (abstract — includes cover methods: getCoverUploadUrl, confirmCoverUpload)
│   │   │   │   └── usecases/         # GetAvatarUploadUrlUseCase, ConfirmAvatarUploadUseCase, GetCoverUploadUrlUseCase, ConfirmCoverUploadUseCase
│   │   │   └── presentation/
│   │   │       ├── pages/            # FullScreenImageViewer (pinch-to-zoom image viewer)
│   │   │       ├── providers/        # AvatarUploadProvider, CoverUploadProvider (pick → CustomCropScreen → presigned URL → S3 upload → confirm)
│   │   │   └── widgets/          # AvatarOptionsBottomSheet, CustomCropScreen (interactive crop with dotted_border overlay guide),
│   │   │                             # CoverRepositionScreen (Facebook-style cover reposition)
│   │   ├── student/                  # Student profile feature
│   │   │   ├── data/
│   │   │   │   ├── datasources/      # StudentRemoteDataSource (profile/me, profile/update)
│   │   │   │   ├── models/           # UserProfileModel (parses nested API data.profile)
│   │   │   │   └── repositories/     # StudentRepositoryImpl, MockStudentRepositoryImpl
│   │   │   ├── domain/
│   │   │   │   ├── entities/         # UserProfileEntity, ProfileVideo, ProfileCourse
│   │   │   │   ├── repositories/     # StudentRepository (abstract)
│   │   │   │   └── usecases/         # GetProfileUseCase, UpdateProfileUseCase
│   │   │   └── presentation/
│   │   │       ├── pages/            # student_profile_page.dart (StudentProfilePage)
│   │   │       ├── providers/        # StudentProfileProvider, EditProfileProvider
│   │   │   └── widgets/          # ProfileHeaderCard, SkillBadgesRow, SocialLinksRow,
│   │   │                             # VideosHorizontalListView, CompletedCoursesVerticalListView,
│   │   │                             # SectionHeader, ProfileAppBar, VideoPlayerScreen
│   │   ├── edit/                     # Profile editing feature (uses student domain)
│   │   │   └── presentation/
│   │   │       └── pages/            # profile_editing_page.dart (EditProfilePage)
│   │   │   └── widgets/              # social_link_form_blocK_ui.dart (SocialLinksFormBlockUi)
│   │   └── mentor/                   # Mentor profile feature (mirrors student structure, shares `profile/me` endpoint)
│   │       ├── data/
│   │       │   ├── datasources/      # MentorRemoteDataSource (profile/me via AuthHttpClient)
│   │       │   └── repositories/     # MentorRepositoryImpl
│   │       ├── domain/
│   │       │   ├── repositories/     # MentorRepository (abstract)
│   │       │   └── usecases/         # GetMentorProfileUseCase
│   │       └── presentation/
│   │           ├── pages/            # mentor_profile_page.dart (MentorProfilePage)
│   │           ├── providers/        # MentorProfileProvider
│   │           └── widgets/          # MentorHeroBanner, MentorIdentityHeader, MentorMetricsBar
└── global/
    └── core/
        ├── config/                   # AppConfig (baseUrl, googleClientId, requestTimeout)
        ├── constants/                # TextColor, Images, etc.
        ├── data/                     # Shared base classes
        │   ├── base_remote_data_source.dart  # BaseRemoteDataSource with post()/get()/put()/extractData()
        │   └── base_repository.dart          # BaseRepository mixin with safeCall<T>()
        ├── di/                       # ProviderSetup (centralized DI)
        ├── error/                    # Failure (Equatable), ServerFailure, ValidationFailure, CacheFailure
        ├── routes/                   # AppRoutes (named routes + onGenerateRoute)
        ├── services/                 # AppLogger, ToastService, SecureStorage, AppPreferences, TokenService, AuthHttpClient
        ├── theme/                    # AppTheme (light + dark), ThemeProvider (dark mode persistence)
        ├── widgets/                  # Shared global widgets: AuthButton, AppBackButton, DashedBorder, SvgImage
        └── usecase/                  # UseCase<Type, Params> abstract + NoParams
```

---

## 3. Data Flow (How a Request Travels)

```
UI (Page)                 e.g. LoginPage
  ↓  calls method on
Provider (ChangeNotifier) e.g. AuthProvider.login(email, password)
  ↓  calls
UseCase (validates input) e.g. LoginUseCase.call(LoginParams)
  ↓  calls
Repository Interface     e.g. AuthRepository.login(email, password)
  ↓  implemented by
Repository Implementation e.g. AuthRepositoryImpl (with BaseRepository mixin → safeCall<T>())
  ↓  calls
Remote Data Source        e.g. AuthRemoteDataSourceImpl (extends BaseRemoteDataSource → post())
  ↓  uses
http.Client
  ↓
API → JSON Response
  ↓  returns
Either<Failure, Model>    Data Source returns typed model
  ↓  returned to
Either<Failure, Entity>   Repository returns domain entity
  ↓  back to
Provider → notifyListeners() → UI rebuilds
```

---

## 4. Coding Patterns & Conventions

### 4.1 Creating a New Feature

1. Create folder structure: `lib/features/[feature]/data/`, `domain/`, `presentation/`
2. **Domain first**:
   - Entity (plain Dart class, extend `Equatable` if needed)
   - Repository interface (abstract class, methods return `Either<Failure, ...>`)
   - Use Cases (one per operation, `implements UseCase<Type, Params>`)
3. **Data second**:
   - **Model** (extends Entity if serialization needed, adds `fromJson`/`toJson`)
   - **Mapper** (if use case receives typed Params, create a mapper to convert Params → JSON for API)
   - **Service** (wrap SDK/platform dependencies — e.g. `GoogleSignInService`, `TokenService` — so presentation never imports them directly)
   - **Remote Data Source** (extends [`BaseRemoteDataSource`](lib/global/core/data/base_remote_data_source.dart) → use `post()`/`get()`/`put()` helpers)
   - **Repository Implementation** (implements interface, uses [`BaseRepository`](lib/global/core/data/base_repository.dart) mixin → `safeCall<T>()`)
4. **Presentation last**:
   - Provider (extends `ChangeNotifier`, injects UseCases + any services via constructor)
   - Pages (UI)
   - Widgets (reusable components)
5. **Register DI** in [`provider_setup.dart`](lib/global/core/di/provider_setup.dart):
   - External dependencies → `Provider<T>` (e.g. `http.Client`, `TokenService`, `GoogleSignInService`)
   - Data Sources → `ProxyProvider` (or `ProxyProvider2` for multi-dependency)
   - Repositories → `ProxyProvider`
   - Use Cases → `ProxyProvider`
   - UI Providers → `ChangeNotifierProvider` with `Provider.of<>()` inside `create:`

### 4.2 Use Case Pattern — `implements` (NOT `extends`)

Every use case **implements** `UseCase<ReturnType, ParamsType>` (the actual base class uses `implements`, not `extends`). Validate inputs before calling the repository.

```dart
// ── Actual pattern from LoginUseCase ──
class LoginParams {
  final String email;
  final String password;
  LoginParams({required this.email, required this.password});
}

class LoginUseCase implements UseCase<UserEntity, LoginParams> {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(LoginParams params) async {
    // Input validation — return Left(ValidationFailure) for bad input
    if (params.email.isEmpty) {
      return Left(ValidationFailure('Email is required'));
    }
    if (params.password.isEmpty) {
      return Left(ValidationFailure('Password is required'));
    }
    if (params.password.length < 6) {
      return Left(ValidationFailure('Password must be at least 6 characters'));
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(params.email)) {
      return Left(ValidationFailure('Invalid email format'));
    }
    // Delegate to repository (returns Either<Failure, Entity> already)
    return await repository.login(params.email, params.password);
  }
}
```

### 4.3 Shared Base Classes

All remote data sources extend [`BaseRemoteDataSource`](lib/global/core/data/base_remote_data_source.dart) which provides public `post()`, `get()`, `put()`, and `extractData()` methods. This avoids duplicating HTTP logic across features.

#### BaseRemoteDataSource (public helpers)

```dart
class BaseRemoteDataSource {
  final http.Client client;
  BaseRemoteDataSource({required this.client});

  Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
  };

  // TimeoutException is caught before the generic `catch` and thrown
  // as ServerFailure('timeout') — ToastService._getFriendlyMessage()
  // translates "timeout" → "The server is taking too long to respond.
  // Please try again later."
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? extraHeaders,
  }) async { ... }

  Future<Map<String, dynamic>> post(...) async { ... }
  Future<Map<String, dynamic>> put(...) async { ... }

  /// Parses the common `{ success, data, message, errors }` envelope.
  /// Throws [ServerFailure] when `success` is not `true` — including
  /// for endpoints like `change-password` that return
  /// `{"success":false, "message":"Incorrect password"}`.
  Map<String, dynamic> extractData(Map<String, dynamic> responseBody) {
    if (responseBody['success'] == true) {
      return responseBody['data'] as Map<String, dynamic>? ?? {};
    }
    final message = responseBody['message']?.toString() ?? 'Request failed';
    if (responseBody['errors'] != null) {
      final errors = responseBody['errors'] as Map<String, dynamic>;
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          throw ServerFailure(value.first.toString());
        }
      }
    }
    throw ServerFailure(message);
  }
```

> **CRITICAL**: Every data source method (including `forgotPassword()`, `verifyResetOtp()`, `resetPassword()`) **must** call `extractData()` on the raw response. Without it, `success:false` responses (e.g. "Email not found") would silently succeed because the HTTP status is 200. The `extractData()` call converts these into `ServerFailure` which propagates through `BaseRepository.safeCall()` → provider → error toast.

#### Bearer Token via AuthHttpClient (Automatic, Transparent)

Bearer token injection is now handled **transparently** by [`AuthHttpClient`](lib/global/core/services/auth_http_client.dart) — a custom `http.Client` wrapper registered in DI. **All data sources, including `AuthRemoteDataSourceImpl`, receive the `AuthHttpClient`-wrapped client** (previously `AuthRemoteDataSourceImpl` got the raw client; this was changed so authenticated auth endpoints like `auth/change-password` get the Bearer token). Data sources no longer need to import `TokenService` or manually add `Authorization` headers.

The [`StudentRemoteDataSource`](lib/features/profile/student/data/datasources/student_remote_data_source.dart) is simplified — it only takes `http.Client`:

```dart
class StudentRemoteDataSource extends BaseRemoteDataSource {
  StudentRemoteDataSource({required http.Client client})
    : super(client: client);

  Future<UserProfileModel> getProfile() async {
    final response = await get('profile/me');
    final data = extractData(response);
    return UserProfileModel.fromJson(data);
  }

  Future<UserProfileModel> updateProfile(
    Map<String, dynamic> profileData,
  ) async {
    final response = await put('profile/update', body: profileData);
    final data = extractData(response);
    return UserProfileModel.fromJson(data);
  }
}
```

**How it works**: `AuthHttpClient` attaches the Bearer token to every outgoing request (except auth endpoints), intercepts 401 responses, automatically refreshes the token, and retries the request. This keeps data sources purely focused on data mapping, not authentication plumbing.

> **Auth endpoints** (`auth/login`, `auth/register`, `auth/refresh`, etc.) are detected by [`_isAuthEndpoint()`](lib/global/core/services/auth_http_client.dart:35) and passed through directly to the raw inner client — no token attachment and no 401 interception.

The `extractData()` method from `BaseRemoteDataSource` parses the response envelope:
- Checks `response['success'] == true && response['data'] != null`
- Returns `response['data']` — the raw nested JSON
- The model's `fromJson` then extracts `data.profile` sub-object, `data.social_platforms`, `data.videos`, `data.courses`

### 4.4 Abstract Data Source Interface

The data source interface (`AuthRemoteDataSource`) declares all method signatures. The implementation (`AuthRemoteDataSourceImpl`) implements them. The same pattern applies to all data sources (Student, Mentor, Avatar).

```dart
abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(Map<String, dynamic> userData);   // raw JSON from mapper
  Future<UserModel> verifyEmail(String email, String code);
  Future<String> resendEmailVerification(String email);
  Future<Map<String, String>> refreshToken(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<void> forgotPassword(String email);
  Future<void> verifyResetOtp(String email, String code);
  Future<void> resetPassword(String email, String code, String newPassword);
  Future<UserModel> signInWithGoogle(String idToken, String role);
}
```

### 4.5 Repository — `BaseRepository` mixin with `safeCall<T>()`

All repository implementations use the [`BaseRepository`](lib/global/core/data/base_repository.dart) mixin which provides a public `safeCall<T>()` method. **Crucially, this is a public method (not `_safeCall`) because Dart's `_` prefix makes methods file-scoped, not class-private** — a mixin's private methods cannot be used by classes in other files that apply the mixin.

```dart
mixin BaseRepository {
  Future<Either<Failure, T>> safeCall<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on Failure catch (e) {          // ← catches typed failures first
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

Every repository method is a one-liner:
```dart
class AuthRepositoryImpl with BaseRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) =>
      safeCall(() => remoteDataSource.login(email, password));
}
```

### 4.6 Model Pattern — Extending Entity

Models extend the domain entity and add `fromJson`/`toJson` serialization. [`UserModel`](lib/features/auth/data/models/user_model.dart) handles two API response formats (login vs register):

```dart
class UserModel extends UserEntity {
  const UserModel({
    required String id,
    required String email,
    required String firstName,
    required String lastName,
    String? token,
    String? refreshToken,
    String? phone,
    String? avatarUrl,
    String? city,
    int? role,
    bool? emailVerified,
    bool? phoneVerified,
  }) : super(/* ... */);

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    String? token,
    String? refreshToken,
  }) {
    // id: login uses `id` (int), register uses `_id` (string)
    final rawId = json['_id'] ?? json['id']?.toString() ?? '';
    return UserModel(
      id: rawId.toString(),
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      // role: login returns String ("STUDENT"), register may return int
      role: json['role'] is int ? json['role'] : null,
      emailVerified: json['email_verified'],
      phoneVerified: json['phone_verified'],
      // ...
    );
  }
}
```

**Note**: `UserModel` does NOT have a `toEntity()` method because models already extend entities — they ARE entities.

### 4.7 Provider Pattern

```dart
class MyFeatureProvider extends ChangeNotifier {
  final SomeUseCase someUseCase;
  MyFeatureProvider({required this.someUseCase});

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> doSomething(SomeParams params) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await someUseCase(params);
    result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        ToastService.showError(failure.message);
        notifyListeners();
      },
      (data) {
        _isLoading = false;
        ToastService.showSuccess('Operation successful');
        notifyListeners();
      },
    );
  }
}
```

**Important**: All user-facing messages (success/error/info) are handled centrally by `ToastService` which now shows floating `SnackBar`s via the global `scaffoldMessengerKey` (set in `main.dart`). Messages are fired from **providers** (which have no `BuildContext` — the global key handles it). Pages only handle navigation after provider methods complete.

See [§4.17](#417-global-snackbar-system-formerly-fluttertoast) for details.

### 4.8 DI Registration Pattern

In [`provider_setup.dart`](lib/global/core/di/provider_setup.dart), dependencies are registered in 4 tiers:

**Tier 1 — External Dependencies** (`Provider<T>`): No dependencies on other providers.
```dart
// 1. Raw HTTP client — for AuthHttpClient to wrap
Provider<http.Client>(create: (_) => http.Client()),

Provider<TokenService>(create: (_) => TokenService()),

// 2. Auth-wrapped HTTP client (401 interceptor + Bearer token injection)
//    Uses whitelist (_noAuthPaths) to skip auth for public endpoints
//    (login, register, forgot-password, etc.)
ProxyProvider2<http.Client, TokenService, AuthHttpClient>(
  update: (_, rawClient, tokenService, __) =>
      AuthHttpClient(inner: rawClient, tokenService: tokenService),
),

Provider<GoogleSignInService>(create: (_) => GoogleSignInService()),
```

**Tier 2 — Data Sources** (`ProxyProvider`): Depend on external deps. **All data sources, including `AuthRemoteDataSourceImpl`, receive `AuthHttpClient`** — the override is registered first, then all data sources consume `http.Client` which now resolves to `AuthHttpClient`. Public auth endpoints (login, register, etc.) are whitelisted in `AuthHttpClient._noAuthPaths` and bypass token injection; authenticated endpoints like `auth/change-password` and `auth/logout` get the Bearer token automatically.
```dart
// Override: http.Client → AuthHttpClient for ALL data sources
// (registered first so AuthRemoteDataSource also benefits)
ProxyProvider<AuthHttpClient, http.Client>(
  update: (_, authClient, __) => authClient,
),

// Auth data source — receives AuthHttpClient (whitelist skips public
// auth endpoints, Bearer token injected for authenticated ones)
ProxyProvider<http.Client, AuthRemoteDataSource>(
  update: (_, client, __) => AuthRemoteDataSourceImpl(client: client),
),

// Student data source — receives AuthHttpClient (wrapped with 401 interception)
ProxyProvider<http.Client, StudentRemoteDataSource>(
  update: (_, client, __) => StudentRemoteDataSource(client: client),
),
```

**Tier 3 — Repositories** / **Use Cases** (`ProxyProvider`): Depend on data sources.
```dart
ProxyProvider<AuthRemoteDataSource, AuthRepository>(
  update: (_, remoteDataSource, __) =>
      AuthRepositoryImpl(remoteDataSource: remoteDataSource),
),
ProxyProvider<AuthRepository, LoginUseCase>(
  update: (_, repository, __) => LoginUseCase(repository),
),
```

**Tier 4 — UI Providers** (`ChangeNotifierProvider`): Depend on use cases + services. The first entry is always `ThemeProvider` (no deps), followed by feature providers:

```dart
// 1. ThemeProvider — no dependencies, registered first for global availability
ChangeNotifierProvider(create: (_) => ThemeProvider()),

// 2. Feature providers — depend on use cases via Provider.of<>(context, listen: false)
ChangeNotifierProvider(
  create: (context) => AuthProvider(
    loginUseCase: Provider.of<LoginUseCase>(context, listen: false),
    googleSignInService: Provider.of<GoogleSignInService>(context, listen: false),
    tokenService: Provider.of<TokenService>(context, listen: false),
    // ...
  ),
),
```

### 4.9 Consumer Optimization Pattern

Use `Consumer<T>` for widgets that depend on provider state to avoid full-page rebuilds:

```dart
// ✅ GOOD: Only the password field and login button rebuild on state change
Widget build(BuildContext context) {
  return Column(
    children: [
      // Email field — does NOT depend on provider state
      CustomTextField(label: "Email", /* ... */),
      const SizedBox(height: 20),
      // Password field — depends on isPasswordObscure
      Consumer<AuthProvider>(
        builder: (context, authProvider, _) => CustomTextField(
          label: "PasswordField(
          isObscure: authProvider.isPasswordObscure,
          onToggle: () => authProvider.togglePasswordVisibility(),
        ),
      ),
      const SizedBox(height: 12),
      // Login button — depends on isLoginLoading
      Consumer<AuthProvider>(
        builder: (context, authProvider, _) => AuthButton(
          isLoading: authProvider.isLoginLoading,
          onPressed: onLoginPressed,
        ),
      ),
    ],
  );
}
```

Example from the actual codebase: [`login_page.dart`](lib/features/auth/presentation/pages/login_page.dart) wraps the password field (depends on `isPasswordObscure`) and login button (depends on `isLoginLoading`) in separate `Consumer<AuthProvider>` widgets.

#### Dual-Provider Watch in HubPage

The [`HubPage`](lib/features/hub/presentation/pages/hub_page.dart) reads profile data from **both** `StudentProfileProvider` and `MentorProfileProvider` using `context.watch` at the top of `build()`. Since HubPage lives in `MainNavShell`'s `IndexedStack`, it stays alive and watches both providers for changes:

```dart
final profile = context.watch<StudentProfileProvider>().profile ??
    context.watch<MentorProfileProvider>().profile;
```

**Role-aware fetching**: The initial fetch uses `AuthProvider.getUserRole()` to decide which provider to call — `MentorProfileProvider` for MENTOR, `StudentProfileProvider` for STUDENT. This prevents fetching a mentor's data into the student provider (and vice versa).

**Re-fetch on re-login**: After logout → re-login, `initState` does NOT re-run (IndexedStack). A check in `build()` schedules a `_fetchProfile()` callback via `addPostFrameCallback` when `profile == null && !_fetchTriggered`.

This means the entire HubPage rebuilds when either provider updates. For a page this small, the overhead is acceptable — the alternative (wrapping only the header in `Consumer`) adds complexity without measurable benefit. When the page grows, consider scoping the watch to just `_HubHeader`.

### 4.10 Edit-Then-Sync Pattern — Syncing Provider State After Edits

When an edit page saves data via a dedicated edit provider (e.g. `EditProfileProvider`), the **cached profile in the read-only provider (e.g. `StudentProfileProvider`) must be refreshed** so subsequent re-entry of the edit page shows the latest data — including removed items.

```dart
// In the edit page, after save succeeds:
await provider.updateProfile(params);

if (provider.isSuccess && mounted) {
  // Sync the updated profile back to the cached provider
  if (provider.updatedProfile != null) {
    context
        .read<StudentProfileProvider>()
        .refreshProfile(provider.updatedProfile!);
  }
  Navigator.maybePop(context);
}
```

The cached provider exposes a simple public method for this:

```dart
void refreshProfile(UserProfileEntity updatedProfile) {
  _profile = updatedProfile;
  notifyListeners();
}
```

**Why this matters**: Without this sync, the old cache persists. Reopening the edit page calls `_initControllers()` which reads from the stale `StudentProfileProvider.profile`, showing social links that were already removed.

### 4.10.1 Dual-Provider Fallback — Pre-filling Edit Form From Either Profile Page

The [`EditProfilePage`](lib/features/profile/edit/presentation/profile_editing_page.dart:47) pre-fills form fields by reading the cached profile on init. Since the edit page can be navigated to from **both** [`StudentProfilePage`](lib/features/profile/student/presentation/pages/student_profile_page.dart) and [`MentorProfilePage`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart), the pre-fill logic must fall back to [`MentorProfileProvider`](lib/features/profile/mentor/presentation/providers/mentor_profile_provider.dart) when [`StudentProfileProvider`](lib/features/profile/student/presentation/providers/student_profile_provider.dart) has no data cached:

```dart
// profile_editing_page.dart — _initControllers()
final profile =
    context.read<StudentProfileProvider>().profile ??
    context.read<MentorProfileProvider>().profile;
```

This ensures that when a mentor user navigates to the edit page, their profile data is pre-filled even though `StudentProfileProvider` was never activated for their session. The same fallback applies to `socialPlatforms` used by the [`SocialLinksFormBlockUi`](lib/features/profile/edit/widgets/social_link_form_block_ui.dart):

```dart
socialPlatforms:
    (context.read<StudentProfileProvider>().profile?.socialPlatforms ??
        context.read<MentorProfileProvider>().profile?.socialPlatforms) ??
    <String>[],
```

> **Why not a single provider?** Both `StudentProfileProvider` and `MentorProfileProvider` fetch from the same `profile/me` endpoint but are separate `ChangeNotifier`s with independent lifecycle. Using a fallback chain instead of merging them avoids breaking the existing feature-first separation and keeps each provider focused on its own profile page's needs.

### 4.11 Auth Interceptor Pattern — `AuthHttpClient` (Whitelist-Based)

[`AuthHttpClient`](lib/global/core/services/auth_http_client.dart) is a custom `http.Client` implementation that wraps a raw inner client with automatic Bearer token injection, 401 interception, token refresh, and request retry. It uses a **whitelist** (`_noAuthPaths`) to determine which endpoints bypass token injection — this is more precise than the old blanket `auth/` prefix check, ensuring endpoints like `auth/change-password` and `auth/logout` correctly receive the Bearer token.

```dart
class AuthHttpClient implements http.Client {
  final http.Client _inner;
  final TokenService _tokenService;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pending = [];

  AuthHttpClient({
    required http.Client inner,
    required TokenService tokenService,
  }) : _inner = inner, _tokenService = tokenService;

  /// Public auth endpoints that do NOT require a Bearer token.
  static const _noAuthPaths = <String>{
    'auth/login',
    'auth/register',
    'auth/forgot-password',
    'auth/verify-reset-otp',
    'auth/reset-password',
    'auth/google',
    'auth/verify-email',
    'auth/resend-email-verification',
  };
```

#### Key Behaviors

| Behavior | Implementation |
|----------|---------------|
| **Whitelist bypass** | [`_isNoAuthEndpoint()`](lib/global/core/services/auth_http_client.dart:60) strips the base URL path and checks if the relative path is in `_noAuthPaths`. If yes, the request passes through directly to `_inner` — no token, no 401 handling. |
| **Automatic Bearer token** | Before every non-whitelisted request, [`send()`](lib/global/core/services/auth_http_client.dart:68) reads the access token from `TokenService` and attaches `Authorization: Bearer <token>`. |
| **401 interception** | If the response status is 401 and the endpoint is NOT whitelisted, [`_refreshToken()`](lib/global/core/services/auth_http_client.dart:120) is called — reads the refresh token from storage, calls `auth/refresh`, saves the new token pair, and retries the original request once. |
| **Concurrency coalescing** | If multiple requests hit 401 simultaneously, only the first triggers a refresh. Subsequent 401s queue via `Completer<bool>` and are resolved when the refresh completes. |
| **Force logout on refresh failure** | If the refresh API itself fails (non-200 or invalid response), tokens are cleared via `_tokenService.clearTokens()` and a `SessionExpiredFailure` is thrown — forcing the UI to navigate to login. |

#### Core Send Flow

```
request.send()  →  isNoAuthEndpoint?  →  YES → _inner.send() (skip)
                                        →  NO  → attach Bearer token → _inner.send()
                                                  ↓
                                            status 200? → return response
                                                  ↓ (401)
                                            isNoAuth? → YES → return response (don't retry public endpoints)
                                                  ↓ (NO)
                                            isRefreshing? → NO → _refreshToken()
                                                             ↓
                                                      success? → YES → retry request with new token
                                                                ↓ (NO)
                                                    clearTokens() + throw SessionExpiredFailure()
```

#### DI Setup

`AuthHttpClient` is registered in [`provider_setup.dart`](lib/global/core/di/provider_setup.dart) using a **single-client strategy** (all data sources, including `AuthRemoteDataSourceImpl`, receive the wrapped client):

1. **Raw `http.Client`** — registered first via `Provider<http.Client>`.
2. **`AuthHttpClient`** — wraps the raw client via `ProxyProvider2<http.Client, TokenService, AuthHttpClient>`.
3. **Override alias** — `ProxyProvider<AuthHttpClient, http.Client>` maps `AuthHttpClient → http.Client` **first in `_dataSources`**, so **every** data source (including `AuthRemoteDataSourceImpl`) receives the wrapped client. The whitelist ensures public auth endpoints still bypass token injection.

> **Important**: `AuthHttpClient` uses `implements http.Client` (not `extends`) because `http.Client` only provides factory constructors, making subclassing impossible.

### 4.12 Role-Based Routing Pattern

The app supports two user roles (`STUDENT` / `MENTOR`) and navigates to the correct profile page based on the role.

**Architecture**:

1. **Role persistence** — The user's role is stored as a `"STUDENT"` or `"MENTOR"` string in `flutter_secure_storage` via [`SecureStorage.saveUserRole()`](lib/global/core/services/secure_storage.dart) / [`SecureStorage.getUserRole()`](lib/global/core/services/secure_storage.dart).
2. **Role mapping** — The login API returns `role` as a String (`"STUDENT"` or `"MENTOR"`). [`UserModel.fromJson()`](lib/features/auth/data/models/user_model.dart:359) maps it to `int` (0 = STUDENT, 1 = MENTOR). [`UserEntity`](lib/features/auth/domain/entities/user_entity.dart) exposes `isMentor` / `isStudent` getters.
3. **Proxy layer** — [`TokenService`](lib/global/core/services/token_service.dart) exposes `saveUserRole()`, `getUserRole()`, and `clearUserRole()` as convenience methods (delegating to `SecureStorage`), so providers never import `SecureStorage` directly.
4. **Saving on auth success** — [`AuthProvider._saveUserRole()`](lib/features/auth/presentation/providers/auth_provider.dart) saves the role immediately after login, register, or Google sign-in completes successfully. [`AuthProvider.logout()`](lib/features/auth/presentation/providers/auth_provider.dart:261) calls `tokenService.clearUserRole()`.
5. **Navigation helper** — [`AppRoutes.navigateToProfile()`](lib/global/core/routes/app_routes.dart) is a static helper that pushes `/profile` for `"STUDENT"` or `/mentor-profile` for `"MENTOR"`:

```dart
static Future<void> navigateToProfile(BuildContext context, String role) {
  final route = role == 'MENTOR' ? mentorProfilePage : profilePage;
  return Navigator.pushNamed(context, route);
}
```

6. **Routing decision** — After login/splash, the app navigates to `AppRoutes.home` (`MainNavShell`). The HubPage inside it reads the user's role and navigates to the correct profile:

```dart
// In hub_page.dart — Profile Details tap:
onTap: () => AppRoutes.navigateToProfile(
  context,
  profile?.role ?? 'STUDENT',
),
```

**`AuthProvider.getUserRole()` fallback logic**:
```dart
Future<String> getUserRole() async {
  if (_user != null) {
    return _user!.isMentor ? 'MENTOR' : 'STUDENT';
  }
  final storedRole = await tokenService.getUserRole();
  return storedRole ?? 'STUDENT';  // default to STUDENT
}
```

### 4.13 Avatar Upload Flow Pattern (5-Step Orchestration with Bottom Sheet Options)

The avatar upload feature follows a **5-step flow** (previously 4-step) that involves image cropping, our API, and direct S3 upload. The user first sees a bottom sheet with Facebook / View / Upload options before the upload flow begins. It is implemented as a **shared feature** under [`lib/features/profile/avatar/`](lib/features/profile/avatar/) used by both [`StudentProfilePage`](lib/features/profile/student/presentation/pages/student_profile_page.dart) and [`MentorProfilePage`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart).

#### Flow Diagram

```
User taps avatar         StudentProfilePage / MentorProfilePage
        │
        ▼
showAvatarOptionsBottomSheet()
  ┌─────────────────────────────┐
  │  ☰ Facebook Profile         │  (only for avatars, not covers)
  │    → _openFacebookProfile() │
  ├─────────────────────────────┤
  │  🖼 View Profile Photo      │  (only if currentImageUrl is set)
  │    → FullScreenImageViewer  │
  ├─────────────────────────────┤
  │  📤 Upload Photo            │
  │    → AvatarUploadProvider   │
  └─────────────────────────────┘
        │  User selects "Upload"
        ▼
  AvatarUploadProvider.pickImage()
        │  (full phone quality, no downsampling)
  1.    ▼
  ImagePicker.pickImage(source: ImageSource.gallery)
        │  if cancelled → _isCropping reset, return null
        ▼
  Navigator.push → CustomCropScreen
        │  Full-screen crop UI with:
        │  • InteractiveViewer (pinch-zoom, pan)
        │  • DottedBorder overlay guide (circular or rectangular)
        │  • Dim cutout via ClipPath (reverse-difference)
        │  • Rule-of-thirds grid (GridPainter)
        │  • Manual dart:ui crop only (native ImageCropper skipped
        │    — crashes on Android 16 / API 36)
  2.    ▼
  CroppedFile returned to page
        │
  uploadAvatarFromFile(croppedFile)
        │  (resets _isCropping = false, sets _isLoading = true)
  3.    ▼
  GetAvatarUploadUrlUseCase(filename, contentType)
        │  POST profile/avatar/upload-url
        ▼
  Returns {uploadUrl, fileUrl}
        │
  4.    ▼
  _streamUpload(url, bytes, contentType)
        │  HTTP PUT via StreamedRequest (chunked, 64KB chunks)
        │  _uploadProgress updated per chunk → notifyListeners()
        │  Progress overlay shown on avatar: spinner + "%" text
        │  if non-200 → show error, return
        ▼
  5.  ConfirmAvatarUploadUseCase(fileUrl)
        │  PUT profile/avatar/confirm
        ▼
  onUploadSuccess?.call(fileUrl)  →  profile.copyWith(avatarUrl: fileUrl)
                                    →  refreshProfile(updatedProfile)
                                    →  UI rebuilds with new avatar
```

#### Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| **Shared avatar feature** | Both student and mentor pages need avatar upload. Placing it in `lib/features/profile/avatar/` avoids duplicating the data source, repository, use cases, and provider. |
| **`onUploadSuccess` callback** | The `AvatarUploadProvider` doesn't know which profile provider is active. The callback pattern lets each page wire its own profile refresh: `StudentProfileProvider.refreshProfile()` or `MentorProfileProvider.refreshProfile()`. |
| **`Map<String, dynamic>` return from getUploadUrl** | The presigned URL response is a simple `{uploadUrl, fileUrl}` key-value pair that doesn't map to a meaningful domain concept — returning a raw map avoids an unnecessary domain entity. |
| **`ImagePicker` in provider** | Using `ImagePicker` directly in the provider (with default constructor fallback) avoids registering it in DI, keeping the dependency simple. |
| **Separate `AvatarUploadProvider` + `CoverUploadProvider`** | Avatar (1:1 square, 1024×1024, quality 95) and cover (16:9, 1920×1080, quality 92) have different crop specs, endpoint paths, and success messages. Two providers keep each focused and avoid a complex monolithic upload provider. |
| **`_inferContentType()` mapping** | Maps file extensions to MIME types: `.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, `.webp` → `image/webp`, `.gif` → `image/gif`, `.bmp` → `image/bmp`. Defaults to `image/jpeg` for unknown extensions. |
| **Streamed S3 upload with progress** | Step 4 uses [`_streamUpload()`](lib/features/profile/avatar/presentation/providers/avatar_upload_provider.dart) — a chunked `StreamedRequest` (64KB chunks) that updates `_uploadProgress` (0.0→1.0) after each chunk and calls `notifyListeners()`. Increased from 8KB → 64KB for faster uploads. Configurable `uploadTimeout` (default 120s) prevents hanging on slow networks. Enables real-time progress UI via `Consumer<AvatarUploadProvider>` reading `uploadProgress` / `isUploading`. |
| **Custom crop UI via [`CustomCropScreen`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) + `dotted_border`** | The crop step uses a full-screen custom widget built with `image_picker` (capped at 4096px), `image_cropper` (type only for `CroppedFile`), and `dotted_border` (guide overlay). The screen features an `InteractiveViewer` for pinch-zoom/pan, a dimmed cutout overlay (circular for avatar, rectangular for cover) drawn via `ClipPath` + `Path.combine(PathOperation.reverseDifference)`, a `DottedBorder` guide, and a rule-of-thirds `GridPainter`. The native `ImageCropper.cropImage()` is **intentionally skipped** because it crashes on Android 16 (API 36). The crop uses purely `dart:ui` — `PictureRecorder` + `drawImageRect` + `toByteData(format: ui.ImageByteFormat.png)`. Same pattern in `CoverRepositionScreen`. |
| **OOM-safe image picking (4096px cap)** | `pickImage()` on both providers calls `_imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 4096, maxHeight: 4096)` — capped at 4096px on the longest side to prevent `OutOfMemoryError` when `instantiateImageCodec` loads the image into `dart:ui` on low-end devices (e.g., TECNO KN8). 4096px still provides excellent quality for profile avatars and cover photos. |
| **Bottom sheet options pattern** | [`showAvatarOptionsBottomSheet()`](lib/features/profile/avatar/presentation/widgets/avatar_options_bottom_sheet.dart) is a reusable function showing Facebook / View / Upload options. The Facebook option is only shown for avatars (`isAvatar: true`). The View option is only shown when `currentImageUrl` is non-null. The return value is an `AvatarOption` enum consumed by the page via a switch statement. |
| **Camera overlay on both avatar displays** | Both [`ProfileHeaderCard`](lib/features/profile/student/presentation/widgets/profile_header_card.dart) (student) and [`MentorHeroBanner`](lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart) (mentor) show a camera icon overlay on the avatar, providing a visual hint that the avatar is tappable. `MentorHeroBanner` also uses `filterQuality: FilterQuality.high` on the cover `DecorationImage` for sharper rendering. |

#### edit-then-sync for Avatar Upload

After avatar upload completes, the cached profile provider must be updated so the UI reflects the new avatar immediately — following the same pattern from [§4.10](#410-edit-then-sync-pattern--syncing-provider-state-after-edits):

```dart
// In profile_page.dart initState → addPostFrameCallback:
context.read<AvatarUploadProvider>().onUploadSuccess = (newAvatarUrl) {
  final currentProfile = context.read<StudentProfileProvider>().profile;
  if (currentProfile != null) {
    final updatedProfile = currentProfile.copyWith(avatarUrl: newAvatarUrl);
    context.read<StudentProfileProvider>().refreshProfile(updatedProfile);
  }
};
```

The same pattern applies to [`MentorProfilePage`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart) using `MentorProfileProvider` instead.

#### Avatar Remote Data Source

```dart
class AvatarRemoteDataSource extends BaseRemoteDataSource {
  AvatarRemoteDataSource({required http.Client client}) : super(client: client);

  Future<AvatarUploadUrlModel> getUploadUrl(String filename, String contentType) async {
    final response = await post('profile/avatar/upload-url', body: {
      'filename': filename,
      'contentType': contentType,
    });
    final data = extractData(response);
    return AvatarUploadUrlModel.fromJson(data);
  }

  Future<void> confirmUpload(String fileUrl) async {
    final response = await put('profile/avatar/confirm', body: {
      'fileUrl': fileUrl,
    });
    extractData(response);
  }
}
```

#### AvatarUploadUrlModel

```dart
class AvatarUploadUrlModel {
  final String uploadUrl;   // presigned S3 URL for direct PUT
  final String fileUrl;     // permanent S3 object path for confirm endpoint
  const AvatarUploadUrlModel({required this.uploadUrl, required this.fileUrl});
  factory AvatarUploadUrlModel.fromJson(Map<String, dynamic> json) => AvatarUploadUrlModel(
    uploadUrl: json['uploadUrl']?.toString() ?? '',
    fileUrl: json['fileUrl']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {'uploadUrl': uploadUrl, 'fileUrl': fileUrl};
}
```

#### AvatarUploadProvider (Core Methods)

```dart
/// Upload progress from 0.0 to 1.0 during the S3 upload phase.
double _uploadProgress = 0.0;
double get uploadProgress => _uploadProgress;

/// Whether currently in the S3 upload phase (bytes being sent to S3).
bool get isUploading => _isLoading && _uploadProgress > 0.0;

/// Re-entry guard to prevent double-crop or double-upload submissions.
bool _isCropping = false;

/// Pick an image at full phone camera quality (no downsampling).
Future<XFile?> pickImage() async {
  if (_isCropping || _isLoading) {
    ToastService.showInfo('Upload already in progress');
    return null;
  }
  _isCropping = true;
  notifyListeners();
  try {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      // No maxWidth/maxHeight/imageQuality — use full camera resolution.
    );
    if (pickedFile == null) {
      _isCropping = false;
      notifyListeners();
    }
    return pickedFile;
  } catch (e) {
    _isCropping = false;
    notifyListeners();
    ToastService.showError('Failed to pick image: $e');
    return null;
  }
}

/// Upload a pre-cropped file to S3 and confirm with the backend.
Future<void> uploadAvatarFromFile(XFile file) async {
  _isCropping = false;  // Reset re-entry guard before setting loading state.
  _isLoading = true;
  _errorMessage = null;
  _uploadedAvatarUrl = null;
  _uploadProgress = 0.0;
  notifyListeners();

  try {
    final bytes = await file.readAsBytes();
    final filename = file.name;
    final contentType = _inferContentType(filename);

    // Step 1: Get presigned URL
    final uploadResult = await getAvatarUploadUrlUseCase(
      GetAvatarUploadUrlParams(filename: filename, contentType: contentType),
    );

    await uploadResult.fold((failure) async {
      _isLoading = false;
      _errorMessage = failure.message;
      ToastService.showError(failure.message);
      notifyListeners();
    }, (data) async {
      final uploadUrl = data['uploadUrl'] as String;
      final fileUrl = data['fileUrl'] as String;

      // Step 2: Stream upload to S3 with progress tracking
      try {
        await _streamUpload(
          url: uploadUrl,
          bytes: bytes,
          contentType: contentType,
        );
      } catch (e) {
        _isLoading = false;
        _uploadProgress = 0.0;
        _errorMessage = 'Failed to upload image to storage';
        ToastService.showError('Failed to upload image to storage');
        notifyListeners();
        return;
      }

      // Step 3: Confirm upload
      final confirmResult = await confirmAvatarUploadUseCase(
        ConfirmAvatarUploadParams(fileUrl: fileUrl),
      );
      confirmResult.fold((failure) {
        _isLoading = false;
        _uploadProgress = 0.0;
        _errorMessage = failure.message;
        ToastService.showError(failure.message);
        notifyListeners();
      }, (_) {
        _isLoading = false;
        _uploadProgress = 0.0;
        _uploadedAvatarUrl = fileUrl;
        onUploadSuccess?.call(fileUrl);
        ToastService.showSuccess('Avatar updated successfully');
        notifyListeners();
      });
    });
  } catch (e) {
    _isLoading = false;
    _uploadProgress = 0.0;
    _errorMessage = e.toString();
    ToastService.showError('Failed to upload avatar: $e');
    notifyListeners();
  }
}

/// Streams [bytes] to [url] via chunked HTTP PUT, reporting progress.
Future<void> _streamUpload({
  required String url,
  required List<int> bytes,
  required String contentType,
}) async {
  final totalBytes = bytes.length;
  const chunkSize = 65536;  // 64 KB chunks for faster large-file uploads.
  final request = http.StreamedRequest('PUT', Uri.parse(url));
  request.headers['Content-Type'] = contentType;
  request.contentLength = totalBytes;
  final responseFuture = request.send();

  int offset = 0;
  while (offset < totalBytes) {
    final end = (offset + chunkSize).clamp(0, totalBytes);
    request.sink.add(bytes.sublist(offset, end));
    offset = end;
    _uploadProgress = offset / totalBytes;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 8));
  }
  await request.sink.close();

  final streamedResponse = await responseFuture;
  if (streamedResponse.statusCode != 200) {
    throw HttpException(
      'S3 upload failed with status ${streamedResponse.statusCode}',
      uri: Uri.parse(url),
    );
  }
}
```

### 4.14 Pull-to-Refresh Pattern

Both [`StudentProfilePage`](lib/features/profile/student/presentation/pages/student_profile_page.dart) and [`MentorProfilePage`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart) wrap their content in a `RefreshIndicator` to allow pull-to-refresh:

```dart
RefreshIndicator(
  color: const Color(0xFF2563EB),
  onRefresh: () => context.read<StudentProfileProvider>().fetchProfile(),
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(/* ... */),
  ),
),
```

Key details:
- Uses `AlwaysScrollableScrollPhysics` (not `BouncingScrollPhysics`) so the scroll physics allow overscroll even when content is smaller than the viewport — critical for pull-to-refresh to work on sparsely populated profiles.
- `MentorProfilePage` uses `MentorProfileProvider.fetchProfile()` similarly.
- The page wraps content in `Scaffold → RefreshIndicator → SingleChildScrollView / ListView`.

### 4.15 Video Data Flow — API-Driven with Fallback Thumbnail

The `videos` field in the profile API response contains entries with `image` (URL) and `title`. The [`VideosHorizontalListView`](lib/features/profile/student/presentation/widgets/video_list_section.dart) in both student and mentor profiles uses the `image` URL directly from the API — no dummy injection.

A static `_isVideoUrl()` helper detects whether the URL is a playable video:

```dart
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv');
}
```

- If the URL is a recognized video format → card shows an inline `VideoPlayerController` with play/pause and full-screen controls when tapped
- If the URL is an image (e.g. picsum.photos placeholder from the API) → card shows the image as a thumbnail with a play icon overlay, and tapping does nothing (the video player is not activated)

This means when the backend later supplies actual `.mp4` (or other video format) URLs, the player will activate automatically with no code changes.

### 4.16 Upload Progress UI Pattern

During the S3 upload phase (step 3 of the 4-step flow), both [`ProfileHeaderCard`](lib/features/profile/student/presentation/widgets/profile_header_card.dart) and [`MentorHeroBanner`](lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart) show a real-time progress overlay:

```dart
Consumer<AvatarUploadProvider>(
  builder: (context, uploadProvider, _) {
    final isUploading = uploadProvider.isUploading;
    final progress = uploadProvider.uploadProgress;
    return GestureDetector(
      onTap: isUploading ? null : onAvatarTap,   // block interaction during upload
      child: Stack(
        children: [
          // Normal avatar content (CircleAvatar, camera icon, etc.)
          // ...
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      Text('${(progress * 100).toInt()}%'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  },
),
```

Key details:
- `isUploading` (getter: `_isLoading && _uploadProgress > 0.0`) distinguishes the S3 phase from the API-call phases (steps 2, 4) — only the S3 phase shows progress.
- Taps are blocked via `onTap: isUploading ? null : onAvatarTap` to prevent re-triggering upload while one is in progress.
- The same pattern applies to `Consumer<CoverUploadProvider>` in `MentorHeroBanner` for cover photo progress (with larger overlay covering the 195px banner).
- **Native crash prevention**: Both providers use a `_isCropping` re-entry guard in `pickImage()` — set to `true` before the picker opens, reset to `false` in all exit paths (success/cancel/error). The guard is checked at the top of `pickImage()` to silently reject double-taps. Additionally, `uploadAvatarFromFile()` / `uploadCoverFromFile()` reset `_isCropping = false` before setting `_isLoading = true`, preventing the native Android `IllegalStateException: Reply already submitted` when transitioning from the custom crop screen to the upload pipeline. The native `ImageCropperDelegate.java` has also been patched with a try-catch around `pendingResult.success(null)` as a last-resort defense (re-apply after `flutter pub upgrade`).
- The `_streamUpload()` method in both providers uses 64KB chunks with `Future.delayed(8ms)` to yield to the event loop, enabling smooth UI updates while keeping uploads fast.

### 4.17 ThemeProvider Pattern (Dark Mode Persistence)

[`ThemeProvider`](lib/global/core/theme/theme_provider.dart) is a `ChangeNotifier` that persists the user's dark mode preference to `SharedPreferences`. It is the **first** provider registered in `_uiProviders` so it's available to all downstream widgets.

```dart
// theme_provider.dart (simplified)
class ThemeProvider extends ChangeNotifier {
  static const String _keyDarkMode = 'dark_mode';
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() { _loadTheme(); }

  Future<void> _loadTheme() async { /* read from SharedPreferences */ }
  Future<void> toggleTheme() async { /* flip + persist + notify */ }
}
```

**Wiring in main.dart** (the `MaterialApp` is wrapped in `Consumer<ThemeProvider>`):

```dart
Consumer<ThemeProvider>(
  builder: (context, themeProvider, _) => MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: themeProvider.themeMode,
  ),
)
```

**Usage in HubPage** — the Dark Mode toggle reads `isDarkMode` from the provider and calls `toggleTheme()` on change. The `_ToggleRowTile` widget supports both **controlled** (with `value` + `onChanged`) and **uncontrolled** (local `setState`) modes:

```dart
_ToggleRowTile(
  icon: Icons.dark_mode_outlined,
  label: 'Dark Mode',
  value: context.watch<ThemeProvider>().isDarkMode,
  onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
  cs: cs,
  isDark: isDark,
),
```

When `onChanged` is non-null, the tile is controlled — it reads `value` externally and calls `onChanged` on toggle. When `onChanged` is null (e.g., Notification, Email toggles), it uses local `setState` for internal state.

---

---

Registered in [`provider_setup.dart`](lib/global/core/di/provider_setup.dart) following the 4-tier pattern:

```dart
// Data Sources
ProxyProvider<http.Client, AvatarRemoteDataSource>(
  update: (_, client, __) => AvatarRemoteDataSource(client: client),
),

// Repositories
ProxyProvider<AvatarRemoteDataSource, AvatarRepository>(
  update: (_, remoteDataSource, __) =>
      AvatarRepositoryImpl(remoteDataSource: remoteDataSource),
),

// Use Cases
ProxyProvider<AvatarRepository, GetAvatarUploadUrlUseCase>(
  update: (_, repository, __) => GetAvatarUploadUrlUseCase(repository),
),
ProxyProvider<AvatarRepository, ConfirmAvatarUploadUseCase>(
  update: (_, repository, __) => ConfirmAvatarUploadUseCase(repository),
),

// UI Provider
ChangeNotifierProvider(
  create: (context) => AvatarUploadProvider(
    getAvatarUploadUrlUseCase: Provider.of<GetAvatarUploadUrlUseCase>(context, listen: false),
    confirmAvatarUploadUseCase: Provider.of<ConfirmAvatarUploadUseCase>(context, listen: false),
  ),
),
```

#### Widget Integration — Bottom Sheet → Upload Flow

Both profile pages now **show a bottom sheet** instead of calling upload directly:

- [`StudentProfilePage`](lib/features/profile/student/presentation/pages/student_profile_page.dart) — `onAvatarTap` calls `_showAvatarOptions(context, profile)` which triggers [`showAvatarOptionsBottomSheet()`](lib/features/profile/avatar/presentation/widgets/avatar_options_bottom_sheet.dart) with `isAvatar: true`. Options: Facebook (opens profile URL) / View (full-screen viewer) / Upload (crop+upload flow).
- [`MentorProfilePage`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart) — `onAvatarTap` calls `_showAvatarOptions()` for avatar, `onCoverTap` calls `_showCoverOptions()` for covers (with `isAvatar: false` hiding the Facebook option).

The avatar display widgets remain unchanged:
- [`ProfileHeaderCard`](lib/features/profile/student/presentation/widgets/profile_header_card.dart) — accepts `final VoidCallback? onAvatarTap;` wraps the avatar `Stack` in `GestureDetector(onTap: onAvatarTap)`
- [`MentorHeroBanner`](lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart) — accepts `final VoidCallback? onAvatarTap;` and `final VoidCallback? onCoverTap;` wraps camera icons in `GestureDetector`

```dart
// In StudentProfilePage (StatefulWidget):
ProfileHeaderCard(
  student: profile,
  onAvatarTap: () => _showAvatarOptions(context, profile),
);
```
```dart
// In MentorProfilePage (via _MentorProfileBody):
MentorHeroBanner(
  coverUrl: profile.coverUrl,
  avatarUrl: profile.avatarUrl,
  onAvatarTap: () => _showAvatarOptions(context, profile),
  onCoverTap: () => _showCoverOptions(context, profile),
  onEdit: () => Navigator.pushNamed(context, AppRoutes.editProfilePage),
);
```

---

### 4.18 Logout Clear Pattern — Preventing Stale Provider State Across Logins

Providers registered at the app level (in `provider_setup.dart`) **persist across logins** because they sit above the Navigator in the widget tree. When user A (STUDENT) logs out and user B (MENTOR) logs in, cached providers like `StudentProfileProvider` still hold user A's profile, causing stale data leaks (wrong name/avatar in HubPage).

**The fix**: Clear all cached provider state on logout, then re-fetch on the next login.

#### Step 1: Expose `clearProfile()` on cached-data providers

```dart
// In StudentProfileProvider / MentorProfileProvider:
void clearProfile() {
  _profile = null;
  _errorMessage = null;
  _isLoading = false;
  notifyListeners();
}
```

Both [`StudentProfileProvider`](lib/features/profile/student/presentation/providers/student_profile_provider.dart) and [`MentorProfileProvider`](lib/features/profile/mentor/presentation/providers/mentor_profile_provider.dart) expose this method.

#### Step 2: Clear on logout (in HubPage)

```dart
// In HubPage's logout handler — before calling AuthProvider.logout():
context.read<StudentProfileProvider>().clearProfile();
context.read<MentorProfileProvider>().clearProfile();
_fetchTriggered = false;           // allow re-fetch on next login

await context.read<AuthProvider>().logout();
// ... navigate to login
```

#### Step 3: Role-aware re-fetch on next login

Because HubPage lives in an `IndexedStack`, `initState` does NOT re-run after logout → re-login. A re-fetch trigger is added in `build()`:

```dart
@override
Widget build(BuildContext context) {
  final profile = context.watch<StudentProfileProvider>().profile ??
      context.watch<MentorProfileProvider>().profile;

  if (profile == null && !_fetchTriggered) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchProfile());
  }
  // ...
}
```

Where `_fetchProfile()` uses `AuthProvider.getUserRole()` to decide which provider to call:

```dart
Future<void> _fetchProfile() async {
  if (_fetchTriggered) return;
  _fetchTriggered = true;

  final role = await context.read<AuthProvider>().getUserRole();
  if (role == 'MENTOR') {
    context.read<MentorProfileProvider>().fetchProfile();
  } else {
    context.read<StudentProfileProvider>().fetchProfile();
  }
}
```

Previously it always fetched into `StudentProfileProvider` — correct for STUDENT but wrong for MENTOR (data would go into the wrong provider, and the fallback chain would show stale student data).

### 4.19 OTP Code Input Box Pattern

Both [`VerificationPage`](lib/features/auth/presentation/pages/verification_page.dart) and [`ResetVerificationPage`](lib/features/auth/presentation/pages/reset_verification_page.dart) use six individual `TextField` widgets for OTP entry. Each field has a **visible border** using `OutlineInputBorder`:

```dart
class _OtpBox extends StatelessWidget {
  // ...

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputFill = Theme.of(context).inputDecorationTheme.fillColor;
    return SizedBox(
      width: 44,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: onChanged,
        decoration: InputDecoration(
          counterText: "",
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: inputFill,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEFEFF0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
```

Key details:
- 6 individual boxes arranged in a `Row` with auto-advancing focus (on entering a digit, focus moves to the next box)
- A `-` separator between boxes 2 and 3 (`index == 2`)
- Theme-aware fill color from `InputDecorationTheme`
- `1` character max per box (`maxLength: 1`)
- `counterText: ""` hides the built-in character counter

---

## 5. Auth Endpoints Reference

All endpoints are defined as constants in [`auth_endpoints.dart`](lib/features/auth/data/datasources/auth_endpoints.dart):

| Constant | Path | Description |
|----------|------|
| `AuthEndpoints.login` | `auth/login` |
| `AuthEndpoints.register` | `auth/register` |
| `AuthEndpoints.verifyEmail` | `auth/verify-email` |
| `AuthEndpoints.resendEmailVerification` | `auth/resend-email-verification` |
| `AuthEndpoints.refreshToken` | `auth/refresh` |
| `AuthEndpoints.logout` | `auth/logout` |
| `AuthEndpoints.forgotPassword` | `auth/forgot-password` |
| `AuthEndpoints.verifyResetOtp` | `auth/verify-reset-otp` |
| `AuthEndpoints.resetPassword` | `auth/reset-password` |
| `AuthEndpoints.googleAuth` | `auth/google` |
| `AuthEndpoints.changePassword` | `auth/change-password` |

**Base URL**: `http://108.181.195.154:3000/api/v1/` in [`AppConfig.baseUrl`](lib/global/core/config/app_config.dart)
**Timeout**: 30 seconds for all endpoints (`AppConfig.requestTimeout`)

### Profile Endpoints Reference

| Constant / Method | Path | Description |
|----------|------|-------------|
| `StudentRemoteDataSource.getProfile()` | `profile/me` | Fetch authenticated student's profile |
| `MentorRemoteDataSource.getProfile()` | `profile/me` | Fetch authenticated mentor's profile (same shared endpoint) |
| `StudentRemoteDataSource.updateProfile()` | `profile/update` | Update authenticated student's profile (name, username, profession, bio, social links, etc.) |
| `AvatarRemoteDataSource.getUploadUrl()` | `profile/avatar/upload-url` | Request presigned S3 upload URL — body: `{"filename": "profile.jpg", "contentType": "image/jpeg"}` → returns `{uploadUrl, fileUrl}` |
| `AvatarRemoteDataSource.confirmUpload()` | `profile/avatar/confirm` | Confirm avatar upload — PUT with body `{"fileUrl": "https://.../avatars/abc.jpg"}` → finalizes avatar on server |
| `AvatarRemoteDataSource.getCoverUploadUrl()` | `profile/cover/upload-url` | Request presigned S3 upload URL for cover photo — body: `{"filename": "cover.jpg", "contentType": "image/jpeg"}` → returns `{uploadUrl, fileUrl}` (reuses `AvatarUploadUrlModel`) |
| `AvatarRemoteDataSource.confirmCoverUpload()` | `profile/cover/confirm` | Confirm cover photo upload — PUT with body `{"fileUrl": "https://.../covers/abc.jpg"}` → finalizes cover on server |

**Note**: Profile endpoints are called in [`StudentRemoteDataSource`](lib/features/profile/student/data/datasources/student_remote_data_source.dart) / [`MentorRemoteDataSource`](lib/features/profile/mentor/data/datasources/mentor_remote_data_source.dart) which extend [`BaseRemoteDataSource`](lib/global/core/data/base_remote_data_source.dart). They use `get()` (for `profile/me`) and `put()` (for `profile/update`) with Bearer token auth handled transparently by [`AuthHttpClient`](lib/global/core/services/auth_http_client.dart) — the data sources never import `SecureStorage` or `TokenService` directly. Both student and mentor reuse the same [`UserProfileModel`](lib/features/profile/student/data/models/user_profile_model.dart) parsing.

#### Profile Update Request Body
The `profile/update` endpoint accepts a `PUT` request (via `BaseRemoteDataSource.put()`) with the following JSON body (all fields optional except at least one must be provided):

```json
{
  "name": "John Doe",
  "username": "john_doe",
  "profession": "Software Engineer",
  "dob": "2024-05-16",
  "bio": "I love building things with code",
  "country": "Bangladesh",
  "phone": "+8801712345678",
  "gender": "1",
  "socialLinks": [
    { "platform": "github", "url": "https://github.com/johndoe" },
    { "platform": "facebook", "url": "https://facebook.com/johndoe" }
  ]
```

**Note**: Each social link is now a `{platform, url}` object (not a bare string). In the entity layer, this is represented as `SocialLink(platform, url)`. The `UserProfileModel.fromJson()` parses `socialLinks` using `SocialLink.fromJson(e as Map<String, dynamic>)`. The `SocialLinksRow` widget accepts `List<SocialLink>` and launches each URL on tap via `url_launcher`. The `setState` pattern in the edit page also uses `SocialLink(platform, url)` to build the list of added links.
}
```

**Request body rules**:
- All top-level fields (`name`, `username`, `profession`, `dob`, `bio`, `country`, `phone`, `gender`) are optional — only provided fields are included in the payload
- `socialLinks` is an optional array of objects with `platform` (string) and `url` (string) keys
- `gender` values: `"1"` for Male, `"0"` for Female
- **API inconsistency**: The `profile/update` endpoint requires `gender` as a `String` (`"1"`/`"0"`), but the `auth/register` endpoint accepts `gender` as `int` (`1`/`0`). The edit page dropdown shows `"Male"`/`"Female"` to the user, then converts to string `"1"`/`"0"` on save. The register page sends the same labels as `int` via `"Male" → 1, "Female" → 0`. The `UserProfileEntity` stores gender as `int?` (API response), so init pre-fill converts `int → label`.
- `dob` format: `"YYYY-MM-DD"` string
- Empty optional fields are omitted from the payload entirely (not sent as empty strings)

#### Profile Update Response
The `profile/update` endpoint returns the **same response shape** as `profile/me` — the full updated profile under `data.profile`:

#### Profile API Response Shape
The `profile/me` endpoint returns a nested JSON structure:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "...",
  "data": {
    "profile": {
      "id": 1,
      "name": "...",
      "username": "...",
      "email": "...",
      "phone": "...",
      "dob": "...",
      "gender": 0,
      "role": "STUDENT",
      "avatarUrl": "...",
      "coverUrl": "...",
      "bio": "...",
      "profession": "...",
      "country": "...",
      "socialLinks": ["github", "linkedin", ...]
    },
    "social_platforms": ["github", "linkedin", "twitter", ...],
    "videos": [{ "image": "...", "title": "..." }],
    "courses": [{ "image": "...", "title": "...", "by": "...", "progress": "..." }]
  }
}
```

#### UserProfileEntity Properties
```dart
class UserProfileEntity {
  final int id;                        // int (not String)
  final String name;
  final String username;
  final String email;
  final String? phone;
  final DateTime? dob;
  final int? gender;
  final String role;                   // "STUDENT" (uppercase string)
  final String? avatarUrl;             // nullable
  final String? coverUrl;              // nullable
  final String? bio;                   // nullable
  final String? profession;            // nullable
  final String? country;               // nullable
  final List<SocialLink> socialLinks;  // from profile sub-object — `SocialLink` has `platform` + `url` strings
  final List<String> socialPlatforms;  // from top-level data

  int get videoCount => videos.length;  // computed
  int get courseCount => courses.length; // computed
}

/// A single social link entry with platform name and URL.
class SocialLink {
  final String platform;
  final String url;
  const SocialLink({required this.platform, required this.url});
  factory SocialLink.fromJson(Map<String, dynamic> json) => SocialLink(
    platform: json['platform']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {'platform': platform, 'url': url};
}

class ProfileVideo {
  final String image;
  final String title;
}

class ProfileCourse {
  final String image;
  final String title;
  final String by;
  final String progress;
}
```

**Key points**:
- Videos and courses are domain entities (`ProfileVideo`/`ProfileCourse`) in [`user_profile_entity.dart`](lib/features/profile/student/domain/entities/user_profile_entity.dart), not presentation-only data classes.
- `id` is `int` (API returns integer, not string).
- `avatarUrl`, `coverUrl`, `bio`, `profession`, `country`, `phone`, `dob`, `gender` are all nullable.
- **Role normalization**: The profile API returns `role` as `int` (`0`/`1`) or `String` (`"STUDENT"`/`"MENTOR"`). [`UserProfileModel.fromJson()`](lib/features/profile/student/data/models/user_profile_model.dart) uses a `normalizeRole()` helper to convert `0`/`"0"`/`"STUDENT"` → `"STUDENT"` and `1`/`"1"`/`"MENTOR"` → `"MENTOR"`. This ensures `AppRoutes.navigateToProfile(context, 'MENTOR')` works correctly regardless of what the API returns.
- `socialPlatforms` comes from the top-level `data` array.
- `socialLinks` comes from the `profile` sub-object. Each entry is a `SocialLink` domain entity (`{platform, url}`), not a bare string. `SocialLink` has `fromJson()`/`toJson()` serialization.
- `SocialLinksRow` now accepts `List<SocialLink> socialLinks` instead of `List<String> platforms`. Tapping an icon launches the URL via `url_launcher` (`LaunchMode.externalApplication`).
- Video `image` field comes directly from the API. The [`VideosHorizontalListView`](lib/features/profile/student/presentation/widgets/video_list_section.dart) uses an `_isVideoUrl()` helper to detect whether the URL is a playable video (`.mp4`, `.mov`, `.webm`, `.avi`, `.mkv`) — if yes, the card shows an inline `VideoPlayer`; if no, it shows the `image` as a thumbnail with a play icon overlay. When the backend later supplies actual video URLs, the player will work automatically.

#### Avatar Upload Endpoint — `profile/avatar/upload-url`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `profile/avatar/upload-url` | Bearer token (via AuthHttpClient) | Request a presigned S3 URL for direct avatar image upload |

**Request Body**:
```json
{
  "filename": "profile.jpg",
  "contentType": "image/jpeg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | string | Yes | Original filename with extension (used by server to derive S3 key) |
| `contentType` | string | Yes | MIME type of the image (e.g. `image/jpeg`, `image/png`, `image/webp`) |

**201 Success Response** (endpoint returns HTTP 201 on success):
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Upload URL generated",
  "data": {
    "uploadUrl": "https://eduverse-uploads.s3.ap-south-1.amazonaws.com/avatars/abc123.jpg?X-Amz-Algorithm=...",
    "key": "avatars/abc123.jpg",
    "fileUrl": "https://d3ptrmo399jwse.cloudfront.net/avatars/abc123.jpg"
  },
  "errors": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `uploadUrl` | string | Presigned S3 URL (PUT) — used to upload the raw image bytes directly |
| `key` | string | S3 object key (informational, not consumed by the client) |
| `fileUrl` | string | Permanent CDN URL — passed to the `confirm` endpoint after upload succeeds, and used as the new `avatarUrl` in the profile |

**401 Response**: Returns `401 Unauthorized` if Bearer token is missing or expired. AuthHttpClient handles this automatically with token refresh and retry.

---

#### Avatar Upload Endpoint — `profile/avatar/confirm`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `PUT` | `profile/avatar/confirm` | Bearer token (via AuthHttpClient) | Confirm that avatar bytes have been uploaded to S3 and finalize on server |

**Request Body**:
```json
{
  "fileUrl": "https://eduverse-uploads.s3.ap-south-1.amazonaws.com/avatars/abc123.jpg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fileUrl` | string | Yes | The `fileUrl` returned from the `upload-url` endpoint after successful S3 PUT |

**200 Success Response**:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Avatar updated successfully",
  "data": {}
}
```

#### Complete Avatar Upload Flow (5-Step with Custom Crop Screen)

```
1. PICK IMAGE      → AvatarUploadProvider.pickImage()
                     → ImagePicker.pickImage(source: ImageSource.gallery,
                       maxWidth: 4096, maxHeight: 4096) (OOM-safe cap)
2. CROP IMAGE      → CustomCropScreen (Navigator.push)
                     • InteractiveViewer (pinch-zoom + pan)
                     • DottedBorder circular guide (CircularDottedBorderOptions)
                     • Dim cutout overlay (ClipPath + CircleCutoutClipper)
                     • Rule-of-thirds grid (GridPainter)
                     • Manual dart:ui crop (PictureRecorder + drawImageRect)
                       — native ImageCropper skipped (crashes on Android 16)
                     → Returns CroppedFile
3. GET PRESIGNED URL → POST profile/avatar/upload-url {filename, contentType}
                        → returns {uploadUrl, fileUrl}
4. UPLOAD TO S3      → _streamUpload() via StreamedRequest (64KB chunks)
                        → _uploadProgress updated per chunk → notifyListeners()
                        → Progress overlay: dark container + spinner + "%" text
5. CONFIRM            → PUT profile/avatar/confirm {fileUrl}
                        → server finalizes avatarUrl on user profile
```

The flow is orchestrated by the page: `provider.pickImage()` → `Navigator.push(CustomCropScreen(...))` → `provider.uploadAvatarFromFile(croppedFile)`. The crop step uses a 1:1 circular guide for avatars and purely manual `dart:ui` crop — the native `ImageCropper.cropImage()` is intentionally skipped because it crashes on Android 16 (API 36).

**Crash prevention**: `pickImage()` caps at 4096px to prevent OOM when `instantiateImageCodec` loads the image. Both `pickImage()` and `uploadAvatarFromFile()` are guarded by the `_isCropping` re-entry flag. Error messages use user-friendly text (no `$e` leak) via `ToastService.showError()`.

---

#### Cover Photo Upload Endpoint — `profile/cover/upload-url`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `profile/cover/upload-url` | Bearer token (via AuthHttpClient) | Request a presigned S3 URL for direct cover photo image upload |

**Request Body**:
```json
{
  "filename": "cover.jpg",
  "contentType": "image/jpeg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | string | Yes | Original filename with extension (used by server to derive S3 key) |
| `contentType` | string | Yes | MIME type of the image (e.g. `image/jpeg`, `image/png`, `image/webp`) |

**201 Success Response**:
```json
{
  "success": true,
  "statusCode": 201,
  "message": "Upload URL generated",
  "data": {
    "uploadUrl": "https://eduverse-uploads.s3.ap-south-1.amazonaws.com/covers/abc123.jpg?X-Amz-Algorithm=...",
    "key": "covers/abc123.jpg",
    "fileUrl": "https://d3ptrmo399jwse.cloudfront.net/covers/abc123.jpg"
  },
  "errors": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `uploadUrl` | string | Presigned S3 URL (PUT) — used to upload the raw image bytes directly |
| `key` | string | S3 object key (informational, not consumed by the client) |
| `fileUrl` | string | Permanent CDN URL — passed to the `confirm` endpoint after upload succeeds, and used as the new `coverUrl` in the profile |

---

#### Cover Photo Upload Endpoint — `profile/cover/confirm`

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `PUT` | `profile/cover/confirm` | Bearer token (via AuthHttpClient) | Confirm that cover photo bytes have been uploaded to S3 and finalize on server |

**Request Body**:
```json
{
  "fileUrl": "https://eduverse-uploads.s3.ap-south-1.amazonaws.com/covers/abc123.jpg"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fileUrl` | string | Yes | The `fileUrl` returned from the `upload-url` endpoint after successful S3 PUT |

**200 Success Response**:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "Cover photo updated successfully",
  "data": {}
}
```

#### Complete Cover Photo Upload Flow (5-Step with Custom Crop Screen)

```
1. PICK IMAGE      → CoverUploadProvider.pickImage()
                     → ImagePicker.pickImage(source: ImageSource.gallery,
                       maxWidth: 4096, maxHeight: 4096) (OOM-safe cap)
2. CROP IMAGE      → CustomCropScreen (Navigator.push)
                     • InteractiveViewer (pinch-zoom + pan)
                     • DottedBorder rectangular guide (RoundedRectDottedBorderOptions)
                     • Dim cutout overlay (ClipPath + RectCutoutClipper)
                     • Rule-of-thirds grid (GridPainter)
                     • Manual dart:ui crop (PictureRecorder + drawImageRect)
                       — native ImageCropper skipped (crashes on Android 16)
                     → Returns CroppedFile
3. GET PRESIGNED URL → POST profile/cover/upload-url {filename, contentType}
                          → returns {uploadUrl, fileUrl}
4. UPLOAD TO S3      → _streamUpload() via StreamedRequest (64KB chunks)
                          → _uploadProgress updated per chunk → notifyListeners()
                          → Progress overlay: dark container + spinner + "%" text
5. CONFIRM            → PUT profile/cover/confirm {fileUrl}
                          → server finalizes coverUrl on user profile
```

The flow is orchestrated by the mentor page: `provider.pickImage()` → `Navigator.push(CustomCropScreen(isCircular: false, aspectRatio: 16:9, ...))` → `provider.uploadCoverFromFile(croppedFile)`. The crop step uses a 16:9 rectangular guide for covers — matching the 195px-tall cover banner in `MentorHeroBanner`. The cover's upload progress is visible via a `Consumer<CoverUploadProvider>` in [`MentorHeroBanner`](lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart) which renders a dark overlay with spinner and percentage during the S3 upload phase.

**Cover quality & sizing**: The cover is cropped at 1920×1080 (Full HD 16:9). `pickImage()` caps at 4096px to prevent OOM. Both `pickImage()` and `uploadCoverFromFile()` are guarded by the `_isCropping` re-entry flag.

---

## 6. Auth Lifecycle (Complete Flow)

### Registration Flow
1. **Form fields**: Full Name (auto-capitalized), Username, Email, Phone (optional), DOB (Calendar), Gender (Dropdown: Male/Female), Role (Student/Mentor)
2. **Phone field**: Truly optional — omitted from API payload entirely if empty (not sent as empty string or null)
3. **Auto-capitalization**: Name field automatically capitalizes first letter of each word, preserves user's casing for remaining letters (e.g., "jOhN" → "JOhN")
4. **Endpoint**: `POST /auth/register` via `RegisterUseCase → AuthRepository → AuthRemoteDataSource`
5. **JSON conversion**: `RegisterUseCase._paramsToJson()` converts `RegisterParams` to `Map<String, dynamic>` (domain-level helper)
6. **Email persistence**: After successful registration, email is saved to `SharedPreferences` via `AppPreferences.saveLastEmail()`
7. **Navigation**: On success → `VerificationPage`; On email-already-exists → field-level error with auto-focus + conditional "Log in" button

### Login Flow
1. **Email auto-fill** (expert implementation):
   - Checks `SharedPreferences` (persisted from registration)
   - Falls back to route arguments (for unverified login redirect or password reset flow)
   - Implemented in `_checkAutoFillEmail()` in [`LoginPage`](lib/features/auth/presentation/pages/login_page.dart)
2. **Endpoint**: `POST /auth/login` via `LoginUseCase`
3. **EMAIL_NOT_VERIFIED**: If 401, redirects to `VerificationPage` with email
4. **Success**: Saves tokens to `SecureStorage`, saves email to `AppPreferences`, navigates to home

### Email Verification Flow
1. **Endpoint**: `POST /auth/verify-email` (6-digit OTP)
2. **Resend**: `POST /auth/resend-email-verification` — 30s cooldown timer
3. **Honest timer**: Timer only starts AFTER successful API response (no optimistic UI)
4. **Auto-login**: After successful verification, receives tokens and saves to `SecureStorage`
5. **Success page**: Navigates to `PasswordSuccessPage` with dynamic content

### Password Reset Flow
1. **Forgot Password**: `POST /auth/forgot-password` → sends OTP to email
2. **Verify Reset OTP**: `POST /auth/verify-reset-otp` → validates code
3. **Reset Password**: `POST /auth/reset-password` → sets new password (email, code, newPassword)
4. All managed by `PasswordResetProvider` which stores transient state (`_resetEmail`, `_resetCode`)

### Google Sign-In
1. User taps "Login with Google"
2. Google Sign-In sheet appears → ID token retrieved
3. API call: `POST /auth/google` with body `{"idToken": "...", "role": "STUDENT"}`
4. Success → tokens saved, navigates to home
5. Default role: `STUDENT`, overridable via `signIn `signInWithGoogle(role: 'MENTOR')`

### Token Refresh & Auto-Login
1. `SplashPage` calls `AuthProvider.tryRefreshToken()` on startup
2. Reads refresh token from `SecureStorage`
3. Calls `POST /auth/refresh` via `RefreshTokenUseCase → AuthRepository.refreshToken()`
4. On success → saves new token pair, navigates to home
5. On failure → clears tokens, navigates to login

### Logout
1. Calls `POST /auth/logout` with refresh token (server-side invalidation)
2. Always clears local tokens regardless of API success/failure
3. Clears user state, navigates to login

---

## 7. Key Implementation Details

### API Response Envelope
All auth endpoints follow:
```json
{
  "success": true,
  "statusCode": 200,
  "message": "...",
  "data": { ... },
  "errors": null
}
```

### UserEntity Properties
```dart
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? token;
  final String? refreshToken;
  final String? phone;
  final String? avatarUrl;
  final String? city;
  final int? role;
  final bool? emailVerified;
  final bool? phoneVerified;
  String get fullName => '$firstName $lastName'.trim();
}
```

### AppLogger API
```dart
// All STATIC methods — no instance needed
AppLogger.logRequest('POST', url, body: body);        // 🚀 API REQUEST
AppLogger.logResponse('POST', url, statusCode, body); // ✅ API RESPONSE
AppLogger.logError('POST', url, error);                // ❌ API ERROR
AppLogger.d(message);  // debug
AppLogger.i(message);  // info
AppLogger.e(message);  // error
```

### SecureStorage API
```dart
// Static methods
await SecureStorage.saveTokens(accessToken: ..., refreshToken: ...);
final token = await SecureStorage.getAccessToken();
final token = await SecureStorage.getRefreshToken();
await SecureStorage.clearTokens();
```

### AppPreferences API
```dart
// Requires SharedPreferences injected
AppPreferences(prefs);
await appPreferences.saveLastEmail(email);
final email = appPreferences.getLastEmail();
```

### Failure Classes
```dart
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  List<Object?> get props => [message];
}
class ServerFailure extends Failure { ... }
class CacheFailure extends Failure { ... }
class ValidationFailure extends Failure { ... }
class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure([String message = 'Session expired'])
    : super(message);
}
```

**`SessionExpiredFailure`** is thrown by [`AuthHttpClient`](lib/global/core/services/auth_http_client.dart) when the refresh token itself returns 401 (meaning the session is irrecoverably expired). It bubbles up through `BaseRepository.safeCall<T>()` as a typed `Failure` that providers can catch distinctly from a generic `ServerFailure`.

---

## 8. Route Map

| Route name | Path | Page |
|------------|------|------|
| `AppRoutes.splash` | `/` | `SplashPage` |
| `AppRoutes.login` | `/login` | `LoginPage` |
| `AppRoutes.register` | `/register` | `RegisterPage` |
| `AppRoutes.home` | `/home` | `HomePage` |
| `AppRoutes.forgotPassword` | `/forgot-password` | `ForgotPasswordPage` |
| `AppRoutes.verification` | `/verification` | `VerificationPage` (args: `{email}`) |
| `AppRoutes.resetVerification` | `/reset-verification` | `ResetVerificationPage` |
| `AppRoutes.passwordSuccess` | `/password-success` | `PasswordSuccessPage` |
| `AppRoutes.resetPassword` | `/reset-password` | `SetNewPasswordPage` |
| `AppRoutes.profilePage` | `/profile` | `StudentProfilePage` |
| `AppRoutes.mentorProfilePage` | `/mentor-profile` | `MentorProfilePage` |
| `AppRoutes.editProfilePage` | `/edit-profile` | `EditProfilePage` |
| `AppRoutes.fullScreenImage` | `/full-screen-image` | `FullScreenImageViewer` (args: `{imageUrl: String, heroTag: String?}`) |
| `AppRoutes.courseDetails` | `/course-details` | `CourseDetailsPage` |
| `AppRoutes.enrolledCourse` | `/enrolled-course` | `EnrolledCoursePage` |
| `AppRoutes.paymentSuccess` | `/payment-success` | `PaymentSuccessPage` |
| ~~`AppRoutes.uploadVidoePage`~~ ✅ `AppRoutes.uploadVideoPage` | `/upload-video-page` | `UploadVideoPage` |
| `AppRoutes.uploadCoursePage` | `/upload-course-page` | `UploadCoursePage` |
| `AppRoutes.passwordAndSecurity` | `/password-and-security` | `PasswordAndSecurityPage` |

**Role-based routing**: After login or splash auto-login, [`authProvider.getUserRole()`](lib/features/auth/presentation/providers/auth_provider.dart) determines which profile page to navigate to — `AppRoutes.mentorProfilePage` for MENTOR role, `AppRoutes.profilePage` for STUDENT role. See [§4.12](#412-role-based-routing-pattern).

Routing is configured in [`main.dart`](lib/main.dart) using `onGenerateRoute: AppRoutes.onGenerateRoute` with `initialRoute: AppRoutes.splash` — routing is fully active, not commented out.

---

## 9. Common Pitfalls to Avoid

| Pitfall | Why It's Wrong | Correct Approach |
|---------|---------------|------------------|
| `extends UseCase` instead of `implements` | The base class uses `implements` pattern | Use `class MyUseCase implements UseCase<Type, Params>` |
| Direct `Provider.of<T>(context)` in `build` | Rebuilds entire widget on any state change | Use `Consumer<T>` for state-dependent widgets |
| Instantiating DataSource in Provider | Violates Clean Architecture | Create a UseCase that goes through the Repository |
| No input validation in Use Case | Invalid data reaches the API | Validate all inputs at the top of `call()` |
| Hardcoding `baseUrl` or timeouts | Environment changes require hunting through files | Use `AppConfig.baseUrl` and `AppConfig.requestTimeout` |
| Not using `safeCall<T>()` in repository | Duplicated try-catch blocks | Every repository method is a one-liner using `safeCall` (from `BaseRepository` mixin) |
| Not using `post()`/`get()`/`put()`/`extractData()` in data source | Duplicated HTTP logic | Every data source extends `BaseRemoteDataSource` and uses these public helpers |
| Making `Failure` without `Equatable` | Cannot compare failures by value | `Failure` extends `Equatable` with `message` as props |
| Not syncing provider state after successful edit | After `EditProfileProvider` saves changes, `StudentProfileProvider._profile` still holds stale data; re-entering the edit page shows old social links that were removed | Call `StudentProfileProvider.refreshProfile(updatedProfile)` after save completes, before navigating back |
| Not using stable `ValueKey` for dynamic lists | `Dismissible` elements may not rebuild correctly when items are removed | Use `ValueKey` or `ObjectKey` that reflects the current length or content of the list in the parent `SocialLinksFormBlockUi` or the `Dismissible` itself |
| Sending empty `phone` field to API | Server may reject empty string for optional fields | Omit the `phone` key from payload entirely when empty |
| Starting timer before API response | Optimistic UI creates jarring timer reversal on failure | Start timer only AFTER successful API response (honest timer pattern) |
| Inline data models + widgets in `student_profile_page.dart` | Violates Clean Architecture separation of concerns — mixes domain models and presentation logic in one file | Extract inline data classes to `domain/entities/` and widgets to separate files under `presentation/widgets/` |
| `StatelessWidget` profile page that doesn't fetch data | Profile data is never loaded from the API; page shows empty or hardcoded state | Use `StatefulWidget` with `initState` → `addPostFrameCallback` → `provider.fetchProfile()` |
| Hardcoding profile mock data in the page itself | Mock data is not easily replaceable with real API data during integration | Keep mock data only as temporary lists in the page body, and rely on the Provider's data from the API |
| Not using stable `ValueKey` for dynamic lists | `Dismissible` elements may not rebuild correctly when items are removed | Use `ValueKey` or `ObjectKey` in the parent widget for the list to ensure correct state re-binding |
| Not handling 401 mid-session (raw `http.Client` without interceptor) | Expired tokens cause silent 401 failures — data sources manually handle Bearer tokens inconsistently, and there's no automatic refresh | Use `AuthHttpClient` (injected via DI) which automatically attaches Bearer tokens, intercepts 401s, refreshes the session, and retries the request; non-auth endpoints never handle tokens manually |
| Async persistence inside `result.fold()` callback | `dartz`'s `fold()` does NOT await async callbacks. If token/role writes to SecureStorage are inside `fold()`'s success callback as `async` lambdas, the writes are fire-and-forget. The caller navigates to the profile page before tokens are durably stored, so `AuthHttpClient.send()` reads `null` from SecureStorage and sends the request **without a Bearer token**, causing "OperationError" from the server. | **Never put `await`-dependent side effects inside `fold()` callbacks.** Extract the sync result assignment (`_user = user`) inside `fold()`, then move all async persistence (`await _saveTokens()`, `await _saveUserRole()`) **after** `fold()` returns. Guard with `if (_user != null && _errorMessage == null)` to only persist on success. |
| Edit form fields not pre-filled when navigating from mentor profile page | [`EditProfilePage`](lib/features/profile/edit/presentation/profile_editing_page.dart:47) reads exclusively from `StudentProfileProvider` to pre-fill fields. When a mentor user navigates to the edit page (where `MentorProfileProvider` has data but `StudentProfileProvider` is `null`), all form fields appear empty. | Use a fallback chain: `context.read<StudentProfileProvider>().profile ?? context.read<MentorProfileProvider>().profile` — this reads from whichever provider has the data without requiring a single merged provider. |
| Sending `int` for `gender` to the `profile/update` endpoint | The register endpoint accepts `int` (`1`/`0`), but the update endpoint expects `String` (`"1"`/`"0"`). Sending `int` causes `"gender must be a string"` error. | Always send `String` `"1"`/`"0"` to `profile/update` via `UpdateProfileParams.gender` (which is `String?`). The edit page converts the dropdown's `"Male"`/`"Female"` labels to string `"1"`/`"0"` on save. The register page is unaffected — its endpoint accepts `int`. |
| Missing `extractData()` in data source method | Without `extractData()`, `success:false` responses (HTTP 200 with `{"success":false,"message":"Email not found"}`) silently succeed instead of throwing `ServerFailure`. The repository returns `Right(data)` and the user sees no error. | **Every** data source method that calls `post()`/`get()`/`put()` **must** chain `.then(extractData)` or assign the raw response and pass it to `extractData()`. |
| `AuthRemoteDataSourceImpl` registered **before** the `AuthHttpClient` override in DI | If `AuthRemoteDataSourceImpl` is registered before `ProxyProvider<AuthHttpClient, http.Client>`, it receives the **raw** `http.Client` — no Bearer token injection for authenticated auth endpoints like `auth/change-password` and `auth/logout`. The API returns 401 "Unauthorized". | Register the `http.Client → AuthHttpClient` override **first** in `_dataSources`, then register `AuthRemoteDataSourceImpl`. The whitelist in `AuthHttpClient._noAuthPaths` ensures public endpoints (login, register, etc.) still bypass token injection. |
| Not catching `TimeoutException` before generic `catch` in `BaseRemoteDataSource` | `client.post().timeout()` throws `TimeoutException` when the server doesn't respond within 30s. If caught by a generic `catch(e) { throw ServerFailure('Connection Error: ...') }`, the user sees "check your internet" instead of the more accurate "server is taking too long". | `BaseRemoteDataSource` catches `TimeoutException` **first** via `if (e is TimeoutException) throw ServerFailure('timeout')`. `ToastService._getFriendlyMessage()` translates "timeout" → "The server is taking too long to respond. Please try again later." |
| Blank `NetworkImage` in dark mode / offline | Raw `NetworkImage`/`Image.network` has no caching layer. On slow connections or when offline, images show blank space. Also, no built-in retry mechanism. | Use `CachedNetworkImage` / `CachedNetworkImageProvider` from the `cached_network_image` package — provides disk caching, placeholder, error widget, and retry. All image widgets across the app have been migrated. |
| Sending empty/optional fields incorrectly to `auth/reset-password` | The reset-password endpoint (`POST /auth/reset-password`) expects body `{email, code, newPassword}`. Using the wrong key name (e.g. `'password'` instead of `'newPassword'`) causes a 400 error. | Always check the exact key names in the API contract. The reset-password endpoint uses `'newPassword'` (not `'password'`). |

---

## 10. Step-by-Step: Adding a New API Endpoint (Change Password Example)

This section shows how a new endpoint is added following existing patterns, using the actual `POST /auth/change-password` implementation as a reference.

### Architecture Decision

Change-password is an **authenticated auth endpoint**. Unlike login/register (public), it needs:
- Bearer token injection
- Separate UI page (not inside an existing auth page)

The implementation places the **use case + provider** in the **hub** feature (which owns the Password & Security page), while the **data source + repository** live in the **auth** feature (which owns the auth endpoint interfaces).

```
PasswordAndSecurityPage (hub/presentation/pages)
  → ChangePasswordProvider (hub/presentation/providers)
    → ChangePasswordUseCase (hub/domain/usecases)
      → AuthRepository.changePassword() (auth/domain/repositories)
        → AuthRemoteDataSource.changePassword() (auth/data/datasources)
```

### Step 1: Add endpoint constant ([`AuthEndpoints`](lib/features/auth/data/datasources/auth_endpoints.dart))
```dart
static const String changePassword = 'auth/change-password';
```

### Step 2: Register in `_noAuthPaths` whitelist?
**No** — `auth/change-password` is intentionally **not** in `_noAuthPaths`. The whitelist is only for endpoints that don't need a token (login, register, forgot-password, etc.). `AuthHttpClient` will automatically inject the Bearer token and handle 401s.

### Step 3: Add to data source interface + implementation ([`AuthRemoteDataSource`](lib/features/auth/data/datasources/auth_remote_data_source.dart))
```dart
// Abstract interface
Future<void> changePassword(String currentPassword, String newPassword);

// Implementation (extends BaseRemoteDataSource → post() + extractData())
@override
Future<void> changePassword(String currentPassword, String newPassword) async {
  final response = await post(
    AuthEndpoints.changePassword,
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );
  extractData(response);
}
```

### Step 4: Add to repository interface ([`AuthRepository`](lib/features/auth/domain/repositories/auth_repository.dart))
```dart
Future<Either<Failure, void>> changePassword(
  String currentPassword,
  String newPassword,
);
```

### Step 5: Implement in [`AuthRepositoryImpl`](lib/features/auth/data/repositories/auth_repository_impl.dart)
```dart
@override
Future<Either<Failure, void>> changePassword(
  String currentPassword,
  String newPassword,
) =>
    safeCall(() => remoteDataSource.changePassword(currentPassword, newPassword));
```

### Step 6: Create Use Case in [`lib/features/hub/domain/usecases/`](lib/features/hub/domain/usecases/change_password_usecase.dart)
```dart
class ChangePasswordParams {
  final String currentPassword;
  final String newPassword;
  ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });
}

class ChangePasswordUseCase implements UseCase<void, ChangePasswordParams> {
  final AuthRepository repository;
  ChangePasswordUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) async {
    if (params.currentPassword.isEmpty) {
      return Left(ValidationFailure('Current password is required'));
    }
    if (params.newPassword.isEmpty) {
      return Left(ValidationFailure('New password is required'));
    }
    if (params.newPassword.length < 6) {
      return Left(ValidationFailure('New password must be at least 6 characters'));
    }
    if (params.currentPassword == params.newPassword) {
      return Left(ValidationFailure('New password must differ from current password'));
    }
    return await repository.changePassword(params.currentPassword, params.newPassword);
  }
}
```

### Step 7: Create Provider in [`lib/features/hub/presentation/providers/`](lib/features/hub/presentation/providers/change_password_provider.dart)
```dart
class ChangePasswordProvider extends ChangeNotifier {
  final ChangePasswordUseCase changePasswordUseCase;
  ChangePasswordProvider({required this.changePasswordUseCase});

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _isSuccess = false;
  bool get isSuccess => _isSuccess;

  Future<void> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _isSuccess = false;
    _errorMessage = null;
    notifyListeners();

    final result = await changePasswordUseCase(
      ChangePasswordParams(currentPassword: currentPassword, newPassword: newPassword),
    );

    result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        ToastService.showError(failure.message);
        notifyListeners();
      },
      (_) {
        _isLoading = false;
        _isSuccess = true;
        ToastService.showSuccess('Password changed successfully');
        notifyListeners();
      },
    );
  }
}
```

### Step 8: Register in DI ([`provider_setup.dart`](lib/global/core/di/provider_setup.dart))
```dart
// In _useCases
ProxyProvider<AuthRepository, ChangePasswordUseCase>(
  update: (_, repo, __) => ChangePasswordUseCase(repo),
),

// In _uiProviders
ChangeNotifierProvider(
  create: (context) => ChangePasswordProvider(
    changePasswordUseCase: Provider.of<ChangePasswordUseCase>(context, listen: false),
  ),
),
```

### Step 9: Create UI Page ([`password_and_security_page.dart`](lib/features/hub/presentation/pages/password_and_security_page.dart))
- Uses `SafeArea` (no AppBar) with `AppBackButton` as first child
- Uses `CustomTextField` for inputs, `AuthButton` for submit
- Watches `ChangePasswordProvider.isLoading` for button state
- On `isSuccess == true`, pops the page via `Navigator.maybePop`
- No "Change Email" section — password only

### Step 10: Add route + wire menu tile
```dart
// In AppRoutes — add route
static const String passwordAndSecurity = '/password-and-security';

// In hub_page.dart — "Password & Security" menu tile navigates:
Navigator.pushNamed(context, AppRoutes.passwordAndSecurity);
```

---

## 11. Key Files Reference

| File | Purpose |
|------|---------|
| [`lib/global/core/config/app_config.dart`](lib/global/core/config/app_config.dart) | Centralized config: `baseUrl`, `googleClientId`, `requestTimeout` |
| [`lib/global/core/error/failures.dart`](lib/global/core/error/failures.dart) | `Failure` (Equatable), `ServerFailure`, `ValidationFailure`, `CacheFailure`, `SessionExpiredFailure` |
| [`lib/global/core/services/auth_http_client.dart`](lib/global/core/services/auth_http_client.dart) | `AuthHttpClient` — custom `http.Client` wrapper with automatic Bearer token injection, 401 interception, token refresh/retry, and force logout on refresh failure; bypasses auth endpoints |
| [`lib/global/core/di/provider_setup.dart`](lib/global/core/di/provider_setup.dart) | All DI registrations (use cases + providers); uses `ProxyProvider` for repos/use cases, `ChangeNotifierProvider` for UI providers; two-client strategy (raw `http.Client` for auth, `AuthHttpClient` alias for others) |
| [`lib/global/core/usecase/usecase.dart`](lib/global/core/usecase/usecase.dart) | Base `UseCase<Type, Params>` (use `implements`, NOT `extends`) |
| [`lib/global/core/services/logger_service.dart`](lib/global/core/services/logger_service.dart) | `AppLogger` — `logRequest()`, `logResponse()`, `logError()` |
| [`lib/global/core/services/toast_service.dart`](lib/global/core/services/toast_service.dart) | `ToastService` for user-facing notifications — uses floating `SnackBar` via global `scaffoldMessengerKey` (set in `main.dart`); provides `showSuccess()` (green), `showError()` (red, with `_getFriendlyMessage()` sanitizer), `showInfo()` (blue); replaces deprecated `fluttertoast` |
| [`lib/global/core/services/secure_storage.dart`](lib/global/core/services/secure_storage.dart) | Token persistence (static methods) |
| [`lib/global/core/services/app_preferences.dart`](lib/global/core/services/app_preferences.dart) | SharedPreferences wrapper for email caching |
| [`lib/global/core/theme/app_theme.dart`](lib/global/core/theme/app_theme.dart) | Light/dark theme with Urbanist font |
| [`lib/global/core/theme/theme_provider.dart`](lib/global/core/theme/theme_provider.dart) | `ThemeProvider` — dark mode toggle persisted to `SharedPreferences`; registered first in `_uiProviders` |
| [`lib/global/core/widgets/auth_button.dart`](lib/global/core/widgets/auth_button.dart) | Global solid-color button (`TextColor.appColor` / `0xFF134BBF`) with loading spinner; moved from auth feature to shared global |
| [`lib/global/core/widgets/app_back_button.dart`](lib/global/core/widgets/app_back_button.dart) | Global back button with `Icons.keyboard_arrow_left`, `#F5F5F5` light bg; moved from auth feature to shared global |
| [`lib/global/core/constants/text/text_color.dart`](lib/global/core/constants/text/text_color.dart) | `TextColor` constants: `primaryTextColor = 0xFF2D3748`, `appColor = 0xFF134BBF`, `subTextColor = 0xFF6B7280` |
| [`lib/global/core/routes/app_routes.dart`](lib/global/core/routes/app_routes.dart) | Named routes + onGenerateRoute; includes `AppRoutes.fullScreenImage` (`/full-screen-image`) extracting `imageUrl` (String) and `heroTag` (String?) from route args for `FullScreenImageViewer`; exposes `AppRoutes.navigateToProfile(context, role)` static helper for role-based profile navigation |
| [`lib/features/auth/data/datasources/auth_endpoints.dart`](lib/features/auth/data/datasources/auth_endpoints.dart) | All auth endpoint path constants |
| [`lib/features/auth/data/datasources/auth_remote_data_source.dart`](lib/features/auth/data/datasources/auth_remote_data_source.dart) | Reference data source extending `BaseRemoteDataSource` with `post()`/`get()`/`put()`/`extractData()` |
| [`lib/features/auth/data/repositories/auth_repository_impl.dart`](lib/features/auth/data/repositories/auth_repository_impl.dart) | Reference repository using `BaseRepository` mixin with `safeCall<T>()` |
| [`lib/features/auth/presentation/providers/auth_provider.dart`](lib/features/auth/presentation/providers/auth_provider.dart) | Reference provider (login, register, logout, Google, token refresh) |
| [`lib/features/auth/presentation/providers/email_verification_provider.dart`](lib/features/auth/presentation/providers/email_verification_provider.dart) | Focused single-responsibility provider with timer |
| [`lib/features/auth/presentation/providers/password_reset_provider.dart`](lib/features/auth/presentation/providers/password_reset_provider.dart) | Multi-step flow provider with transient state |
| [`lib/features/auth/presentation/pages/login_page.dart`](lib/features/auth/presentation/pages/login_page.dart) | Reference for `Consumer<T>` optimization + email auto-fill |
| [`lib/features/auth/domain/usecases/login_usecase.dart`](lib/features/auth/domain/usecases/login_usecase.dart) | Reference use case with `implements` pattern |
| [`lib/features/auth/domain/entities/user_entity.dart`](lib/features/auth/domain/entities/user_entity.dart) | Reference entity (Equatable) |
| [`lib/features/auth/data/models/user_model.dart`](lib/features/auth/data/models/user_model.dart) | Reference model (extends entity, fromJson) |
| [`lib/features/profile/student/domain/entities/user_profile_entity.dart`](lib/features/profile/student/domain/entities/user_profile_entity.dart) | `UserProfileEntity` with nested `SocialLink` (platform+url), `ProfileVideo`, `ProfileCourse` domain entities; `id` is `int`, nullable fields for phone/dob/gender/avatarUrl/coverUrl/bio/profession/country; `socialLinks` is `List<SocialLink>` (was `List<String>`) |
| [`lib/features/profile/student/data/datasources/student_remote_data_source.dart`](lib/features/profile/student/data/datasources/student_remote_data_source.dart) | Profile data source with `get()` (for `profile/me`) and `put()` (for `profile/update`) helpers; no manual token logic — Bearer auth is handled transparently by `AuthHttpClient` |
| [`lib/features/profile/student/data/models/user_profile_model.dart`](lib/features/profile/student/data/models/user_profile_model.dart) | Parses nested API response: `data.profile` sub-object + `data.social_platforms`/`data.videos`/`data.courses` arrays |
| [`lib/features/profile/student/data/repositories/student_repository_impl.dart`](lib/features/profile/student/data/repositories/student_repository_impl.dart) | Repository impl using `BaseRepository` mixin with `safeCall<T>()`; registered via `ProxyProvider` depending on `StudentRemoteDataSource` |
| [`lib/features/profile/student/domain/usecases/get_profile_usecase.dart`](lib/features/profile/student/domain/usecases/get_profile_usecase.dart) | Use case for `profile/me`; implements `UseCase<UserProfileEntity, NoParams>` |
| [`lib/features/profile/student/presentation/providers/student_profile_provider.dart`](lib/features/profile/student/presentation/providers/student_profile_provider.dart) | Reference provider for GET-only feature; exposes `profile` getter with `videos`/`courses`/`socialPlatforms` pass-throughs; provides `refreshProfile()` for edit-then-sync pattern |
| [`lib/features/profile/student/presentation/pages/student_profile_page.dart`](lib/features/profile/student/presentation/pages/student_profile_page.dart) | `StudentProfilePage` — StatefulWidget fetching data in `initState` via `addPostFrameCallback`; Consumer-driven loading/error/data states; wires provider data into widgets directly; wraps content in `RefreshIndicator` with `AlwaysScrollableScrollPhysics` for pull-to-refresh; avatar tap opens bottom sheet with Facebook/View/Upload options via `_showAvatarOptions()` using `showAvatarOptionsBottomSheet()` |
| [`lib/features/profile/student/presentation/widgets/profile_header_card.dart`](lib/features/profile/student/presentation/widgets/profile_header_card.dart) | Avatar (nullable `avatarUrl`), username, role, stats, and nullable bio with conditional rendering; wraps avatar in `Consumer<AvatarUploadProvider>` for upload progress overlay (spinner + percentage); blocks tap during upload |
| [`lib/features/profile/student/presentation/widgets/skill_badges_row.dart`](lib/features/profile/student/presentation/widgets/skill_badges_row.dart) | Horizontal skill badge chips |
| [`lib/features/profile/student/presentation/widgets/social_links_row.dart`](lib/features/profile/student/presentation/widgets/social_links_row.dart) | Accepts `List<SocialLink> socialLinks` parameter (was `List<String> platforms`); each `SocialLink` has `platform` (name) + `url`; maps platform names to icons via `_iconFor()`; tapping an icon launches the URL via `url_launcher` (`LaunchMode.externalApplication`); returns `SizedBox.shrink()` for empty list |
| [`lib/features/profile/student/presentation/widgets/video_list_section.dart`](lib/features/profile/student/presentation/widgets/video_list_section.dart) | Horizontal video cards; accepts `List<ProfileVideo>` domain entities directly (no separate presentation data class) |
| [`lib/features/profile/student/presentation/widgets/completed_courses_list.dart`](lib/features/profile/student/presentation/widgets/completed_courses_list.dart) | Vertical list of completed course items; accepts `List<ProfileCourse>` domain entities directly (no separate presentation data class) |
| [`lib/features/profile/edit/widgets/social_link_form_block_ui.dart`](lib/features/profile/edit/widgets/social_link_form_block_ui.dart) | Reusable social links form block used by `EditProfilePage`; accepts parallel `platformControllers`/`urlControllers` lists plus `onAdd`/`onRemove` callbacks; renders labeled header + dynamic rows + "Add a Social link +" button |
| [`lib/features/profile/student/presentation/widgets/section_header.dart`](lib/features/profile/student/presentation/widgets/section_header.dart) | Reusable section title with optional "See All" |
| [`lib/features/profile/student/presentation/widgets/profile_app_bar.dart`](lib/features/profile/student/presentation/widgets/profile_app_bar.dart) | Custom app bar with back + edit actions; shows dynamic name from `context.watch<StudentProfileProvider>().profile?.name` with 'Profile' fallback |
| [`lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart`](lib/features/profile/mentor/presentation/pages/mentor_profile_page.dart) | MentorProfilePage — StatefulWidget fetching data in `initState` via `addPostFrameCallback`; uses `MentorProfileProvider`; wires both `AvatarUploadProvider` (avatar upload) and `CoverUploadProvider` (cover photo upload) via `onUploadSuccess` callbacks; avatar tap opens bottom sheet via `_showAvatarOptions()`, cover tap opens bottom sheet via `_showCoverOptions()` using `showAvatarOptionsBottomSheet()` (with `isAvatar: true` / `isAvatar: false`); shares `UserProfileEntity`/`ProfileVideo`/`ProfileCourse` domain entities with student profile; UI with `MentorHeroBanner`, `MentorIdentityHeader`, `MentorMetricsBar`, then reuses `SkillBadgesRow`, `SocialLinksRow`, `VideoListSection`, `CompletedCoursesList` from student widgets; wraps content in `RefreshIndicator` with `AlwaysScrollableScrollPhysics` for pull-to-refresh |
| [`lib/features/profile/mentor/data/datasources/mentor_remote_data_source.dart`](lib/features/profile/mentor/data/datasources/mentor_remote_data_source.dart) | MentorRemoteDataSource — extends BaseRemoteDataSource, calls `get('profile/me')` and parses via `UserProfileModel.fromJson()` (shared model with student) |
| [`lib/features/profile/mentor/domain/repositories/mentor_repository.dart`](lib/features/profile/mentor/domain/repositories/mentor_repository.dart) | MentorRepository (abstract) — declares `getProfile()` returning `Either<Failure, UserProfileEntity>` |
| [`lib/features/profile/mentor/data/repositories/mentor_repository_impl.dart`](lib/features/profile/mentor/data/repositories/mentor_repository_impl.dart) | MentorRepositoryImpl with BaseRepository mixin — `safeCall()` wrapping `MentorRemoteDataSource.getProfile()` |
| [`lib/features/profile/mentor/domain/usecases/get_mentor_profile_usecase.dart`](lib/features/profile/mentor/domain/usecases/get_mentor_profile_usecase.dart) | GetMentorProfileUseCase — implements `UseCase<UserProfileEntity, NoParams>`; no validation needed (no params) |
| [`lib/features/profile/mentor/presentation/providers/mentor_profile_provider.dart`](lib/features/profile/mentor/presentation/providers/mentor_profile_provider.dart) | MentorProfileProvider — ChangeNotifier with `fetchProfile()`, exposes `profile` getter with pass-throughs for `videos`/`courses`/`socialLinks` |
| [`lib/features/hub/presentation/pages/hub_page.dart`](lib/features/hub/presentation/pages/hub_page.dart) | HubPage — `StatefulWidget` (tab index 3 in `MainNavShell`); role-aware profile fetch via `AuthProvider.getUserRole()` (MENTOR → `MentorProfileProvider`, else → `StudentProfileProvider`); clears both profile providers on logout and resets fetch flag; re-fetches on re-login via `build()` + `addPostFrameCallback` trigger; shows real-time greeting + name + avatar from profile data; wires Dark Mode toggle to `ThemeProvider`; Profile Details uses `AppRoutes.navigateToProfile(context, role)`; "Password & Security" navigates to `AppRoutes.passwordAndSecurity` |
| [`lib/features/hub/domain/usecases/change_password_usecase.dart`](lib/features/hub/domain/usecases/change_password_usecase.dart) | ChangePasswordUseCase — validates non-empty current/new password, min 6 chars, must differ; delegates to AuthRepository |
| [`lib/features/hub/presentation/providers/change_password_provider.dart`](lib/features/hub/presentation/providers/change_password_provider.dart) | ChangePasswordProvider — ChangeNotifier with `isLoading` and `isSuccess` states; shows error/success toasts |
| [`lib/features/hub/presentation/pages/password_and_security_page.dart`](lib/features/hub/presentation/pages/password_and_security_page.dart) | PasswordAndSecurityPage — SafeArea (no AppBar), AppBackButton, 3 CustomTextFields + AuthButton; on success shows toast + pops |
| [`project_performance_planner.md`](project_performance_planner.md) | Performance optimization guide — 7 P0 items, API integration patterns, widget optimization rules, anti-patterns. Read before implementing new features or connecting backend. |
| [`lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart`](lib/features/profile/mentor/presentation/widgets/mentor_hero_banner.dart) | MentorHeroBanner — gradient cover background with avatar overlay and edit icon; accepts `onCoverTap` (wraps cover Container in GestureDetector) and `onAvatarTap` callbacks; wraps cover in `Consumer<CoverUploadProvider>` and avatar in `Consumer<AvatarUploadProvider>` for upload progress overlays (dark overlay + spinner + percentage); blocks taps during upload; shares `Images` constants with student |
| [`lib/features/profile/mentor/presentation/widgets/mentor_identity_header.dart`](lib/features/profile/mentor/presentation/widgets/mentor_identity_header.dart) | MentorIdentityHeader — name, username, profession, bio, and stats row |
| [`lib/features/profile/mentor/presentation/widgets/mentor_metrics_bar.dart`](lib/features/profile/mentor/presentation/widgets/mentor_metrics_bar.dart) | MentorMetricsBar — video count with `video_icon.svg` and course count with `book_icon.svg` using SvgPicture.asset + ColorFilter |
| [`lib/global/core/services/secure_storage.dart`](lib/global/core/services/secure_storage.dart) | Token persistence + role persistence: `saveUserRole()`, `getUserRole()`, `clearUserRole()` methods added for role-based routing |
| [`lib/global/core/services/token_service.dart`](lib/global/core/services/token_service.dart) | Proxy methods for role persistence: `saveUserRole()`, `getUserRole()`, `clearUserRole()` (delegates to SecureStorage) |
| [`lib/features/auth/presentation/providers/auth_provider.dart`](lib/features/auth/presentation/providers/auth_provider.dart) | Reference provider — now includes `_saveUserRole()` and `getUserRole()` for role-based routing; saves role after login/register/google-sign-in; clears role on logout |
| [`lib/features/splash/presentation/screens/splash_page.dart`](lib/features/splash/presentation/screens/splash_page.dart) | SplashPage — role-based routing: reads role via `authProvider.getUserRole()` and navigates to mentor or student profile accordingly |
| [`lib/features/profile/student/domain/usecases/update_profile_usecase.dart`](lib/features/profile/student/domain/usecases/update_profile_usecase.dart) | Use case for `profile/update`; implements `UseCase<UserProfileEntity, UpdateProfileParams>` with nullable-field params class (`toJson()` omits nulls) and `SocialLinkParam`; validates non-empty name/username. **Gender is `String?`** — the update API expects `"1"`/`"0"` strings, not `int`. |
| [`lib/features/profile/student/presentation/providers/edit_profile_provider.dart`](lib/features/profile/student/presentation/providers/edit_profile_provider.dart) | Provider for profile editing; calls `UpdateProfileUseCase` with `UpdateProfileParams`, handles loading/error/success states, shows toasts, exposes `isSuccess` for navigation |
| [`lib/features/profile/edit/presentation/profile_editing_page.dart`](lib/features/profile/edit/presentation/profile_editing_page.dart) | Edit profile UI page with `Consumer<EditProfileProvider>` integration; gender dropdown (`GenderSelectModule`) shows `"Male"`/`"Female"`, saves as `String` `"1"`/`"0"` (update API constraint — see §5 gender inconsistency note); dynamic social link rows with add/remove via `_SocialLinkEntry` controllers; pre-fills from `StudentProfileProvider.profile` ↔ `MentorProfileProvider.profile` (fallback chain) in `didChangeDependencies`; loading spinner on save button; auto-navigates back on success |
| [`lib/features/profile/avatar/data/datasources/avatar_remote_data_source.dart`](lib/features/profile/avatar/data/datasources/avatar_remote_data_source.dart) | Shared avatar & cover data source — `getUploadUrl()`/`getCoverUploadUrl()` post to `profile/avatar/upload-url`/`profile/cover/upload-url`, `confirmUpload()`/`confirmCoverUpload()` put to `profile/avatar/confirm`/`profile/cover/confirm`; both reuse `AvatarUploadUrlModel.fromJson()` |
| [`lib/features/profile/avatar/presentation/widgets/avatar_options_bottom_sheet.dart`](lib/features/profile/avatar/presentation/widgets/avatar_options_bottom_sheet.dart) | `showAvatarOptionsBottomSheet()` — reusable bottom sheet with `AvatarOption.facebook`, `AvatarOption.view`, `AvatarOption.upload` options; Facebook shown only when `isAvatar == true`; View shown only when `currentImageUrl` is non-null; returns `Future<AvatarOption?>`; uses named params: `context`, `currentImageUrl`, `isAvatar` |
| [`lib/features/profile/avatar/presentation/pages/full_screen_image_viewer.dart`](lib/features/profile/avatar/presentation/pages/full_screen_image_viewer.dart) | `FullScreenImageViewer` — full-screen image viewer with `InteractiveViewer` (minScale: 1.0, maxScale: 4.0) for pinch-to-zoom; `Hero` widget support via `heroTag`; dark backdrop with close button; loading spinner with error fallback |
| [`lib/features/profile/avatar/data/models/avatar_upload_url_model.dart`](lib/features/profile/avatar/data/models/avatar_upload_url_model.dart) | Model for presigned URL response — `uploadUrl` (S3 PUT URL), `fileUrl` (permanent S3 object path); `fromJson`/`toJson` factories; reused for both avatar and cover upload endpoints |
| [`lib/features/profile/avatar/domain/repositories/avatar_repository.dart`](lib/features/profile/avatar/domain/repositories/avatar_repository.dart) | Abstract avatar repository — `getUploadUrl()`/`getCoverUploadUrl()` return `Either<Failure, Map<String, dynamic>>`, `confirmUpload()`/`confirmCoverUpload()` return `Either<Failure, void>` |
| [`lib/features/profile/avatar/data/repositories/avatar_repository_impl.dart`](lib/features/profile/avatar/data/repositories/avatar_repository_impl.dart) | AvatarRepositoryImpl with BaseRepository mixin — `safeCall()` wrapping `AvatarRemoteDataSource`; getUploadUrl/getCoverUploadUrl return model.toJson(), confirmUpload/confirmCoverUpload delegate directly |
| [`lib/features/profile/avatar/domain/usecases/get_avatar_upload_url_usecase.dart`](lib/features/profile/avatar/domain/usecases/get_avatar_upload_url_usecase.dart) | Use case for `profile/avatar/upload-url` — implements `UseCase<Map<String, dynamic>, GetAvatarUploadUrlParams>`; validates non-empty filename and contentType |
| [`lib/features/profile/avatar/domain/usecases/confirm_avatar_upload_usecase.dart`](lib/features/profile/avatar/domain/usecases/confirm_avatar_upload_usecase.dart) | Use case for `profile/avatar/confirm` — implements `UseCase<void, ConfirmAvatarUploadParams>`; validates non-empty fileUrl and valid URL format via `Uri.tryParse()` |
| [`lib/features/profile/avatar/domain/usecases/get_cover_upload_url_usecase.dart`](lib/features/profile/avatar/domain/usecases/get_cover_upload_url_usecase.dart) | Use case for `profile/cover/upload-url` — implements `UseCase<Map<String, dynamic>, GetCoverUploadUrlParams>`; validates non-empty filename and contentType |
| [`lib/features/profile/avatar/domain/usecases/confirm_cover_upload_usecase.dart`](lib/features/profile/avatar/domain/usecases/confirm_cover_upload_usecase.dart) | Use case for `profile/cover/confirm` — implements `UseCase<void, ConfirmCoverUploadParams>`; validates non-empty fileUrl and valid URL format via `Uri.tryParse()` |
| [`lib/features/profile/avatar/presentation/providers/avatar_upload_provider.dart`](lib/features/profile/avatar/presentation/providers/avatar_upload_provider.dart) | AvatarUploadProvider — orchestrates the 5-step avatar upload flow: `pickImage()` (full quality, no downsampling) → [`CustomCropScreen`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) (interactive crop, 1:1 square, 1024×1024, quality 95) → `uploadAvatarFromFile()` → get presigned URL → streamed S3 upload (64KB chunks, 120s timeout) → confirm; try-catch + re-entry guard (`_isCropping` flag) prevents native Android `IllegalStateException: Reply already submitted` from double-tap cropping; `onUploadSuccess` callback |
| [`lib/features/profile/avatar/presentation/providers/cover_upload_provider.dart`](lib/features/profile/avatar/presentation/providers/cover_upload_provider.dart) | CoverUploadProvider — orchestrates the 5-step cover photo upload flow: `pickImage()` (full quality, no downsampling) → [`CustomCropScreen`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) (interactive crop, 16:9, 1920×1080, quality 92) → `uploadCoverFromFile()` → get presigned URL → streamed S3 upload (64KB chunks, 120s timeout) → confirm; try-catch + re-entry guard (`_isCropping` flag) prevents native Android crash; `onUploadSuccess` callback |
| [`lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart`](lib/features/profile/avatar/presentation/widgets/custom_crop_screen.dart) | CustomCropScreen — full-screen interactive crop widget using `InteractiveViewer` (pinch-zoom/pan), `DottedBorder` overlay guide, dim cutout via `ClipPath` reverse-difference, rule-of-thirds grid; uses **manual `dart:ui` crop only** (native `ImageCropper` skipped — crashes on Android 16) using `PictureRecorder` + `drawImageRect` + `toByteData` |
| [`lib/features/profile/avatar/presentation/widgets/cover_reposition_screen.dart`](lib/features/profile/avatar/presentation/widgets/cover_reposition_screen.dart) | CoverRepositionScreen — Facebook-style cover reposition screen; shows image at exact banner aspect ratio (full width × bannerHeight) with vertical drag to adjust focal area; eliminates 16:9 guesswork for `BoxFit.cover` clipping |
| [`lib/features/profile/student/presentation/widgets/video_player_screen.dart`](lib/features/profile/student/presentation/widgets/video_player_screen.dart) | VideoPlayerScreen — full-screen video player using `media_kit` (mpv/FFmpeg native); play/pause, 10s skip, progress slider, auto-hide controls, title; opened when user taps full-screen button on inline player |
| [`lib/features/auth/presentation/widgets/custom_text_field.dart`](lib/features/auth/presentation/widgets/custom_text_field.dart) | Shared `CustomTextField` — wraps `TextFormField` with theme-aware decoration (border `#EFEFF0`, fill from `InputDecorationTheme`, label uses `cs.onSurface`); `AutovalidateMode.onUserInteraction` for format errors; special wrapper that skips "required" validators when field is empty (handled via toast on submit) |
| [`lib/global/core/widgets/auth_button.dart`](lib/global/core/widgets/auth_button.dart) | Shared `AuthButton` — `Ink`/`InkWell` with solid `TextColor.appColor` (`#134BBF`); loading spinner overlay; 30px border radius; replaces raw `ElevatedButton` across all auth pages |
| [`lib/features/auth/presentation/widgets/app_back_button.dart`](lib/features/auth/presentation/widgets/app_back_button.dart) | Shared `AppBackButton` — `CircleAvatar` with `#F5F5F5` bg (light) / dark surface (dark); `arrow_back_ios_new` icon; 15px border radius |
| [`lib/global/core/theme/app_theme.dart`](lib/global/core/theme/app_theme.dart) | Central theme definition — `scaffoldBackgroundColor: #FCFCFD` (light), `InputDecorationTheme` with `enabledBorder: #EFEFF0`, `fillColor: Colors.white` (light) / `#1F2937` (dark); dark theme scaffold: `#111827` |
---

## 12. SnackBar System & Message Patterns (Replaces fluttertoast)

### 12.1 Architecture

All user-facing messages use `ToastService` which now shows **floating `SnackBar`**s through the global `scaffoldMessengerKey` (not `fluttertoast`):

```
main.dart
  └── MaterialApp(scaffoldMessengerKey: ToastService.scaffoldMessengerKey)
         └── Provider calls ToastService.showError/Success/Info()
               └── scaffoldMessengerKey.currentState.showSnackBar(...)
```

### 12.2 ToastService API

### 12.3 Error Sanitization

### 12.4 Rules for Messages

### 12.5 Conversion History

All 50+ message calls across providers and pages were converted:
- `fluttertoast` → SnackBars via global key
- 6 raw `SnackBar` usages → `ToastService`
- All `'Failed to ...: $e'` patterns → user-friendly text
- All leaky technical messages sanitized

---

## 13. Theme System & Shared Widgets

### 13.1 Central Theme ([`app_theme.dart`](lib/global/core/theme/app_theme.dart))

The app defines light and dark themes centrally. All pages inherit these — no per-page `scaffoldBackgroundColor` overrides:

```dart
// Light theme
scaffoldBackgroundColor: const Color(0xFFFCFCFD),
InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  enabledBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: Color(0xFFEFEFF0), width: 1),
    borderRadius: BorderRadius.circular(15),
  ),
  // ...
)

// Dark theme
scaffoldBackgroundColor: const Color(0xFF111827),
InputDecorationTheme(
  fillColor: const Color(0xFF1F2937),
  // ...
)
```

### 13.2 Shared Color Tokens

| Token | Light | Dark | Used For |
|-------|-------|------|----------|
| `scaffoldBackgroundColor` | `#FCFCFD` | `#111827` | Page backgrounds |
| `inputDecorationTheme.fillColor` | `Colors.white` | `#1F2937` | Text field fills |
| `enabledBorder` | `#EFEFF0` | `#EFEFF0` | Field borders |
| Back button bg | `#F5F5F5` | `cs.surfaceContainerHighest` | AppBackButton circle |
| AuthButton background | `TextColor.appColor` (`#134BBF`) | Same | All primary CTA buttons (solid color, no gradient) |

### 13.3 Shared Widgets

| Widget | File | Purpose |
|--------|------|---------|
| [`CustomTextField`](lib/features/auth/presentation/widgets/custom_text_field.dart) | Replaces raw `TextFormField` in auth pages. Theme-aware, auto-validate format errors, skips "required" on empty (handled by submit handler). |
| [`AuthButton`](lib/global/core/widgets/auth_button.dart) | Global solid-color button (`TextColor.appColor` / `#134BBF`) with loading spinner. Replaces 5 raw `ElevatedButton`s in auth pages + profile edit Save button + hub password-and-security page. Moved from auth feature to global. |
| [`AppBackButton`](lib/global/core/widgets/app_back_button.dart) | Global back button: `CircleAvatar(bg: #F5F5F5/dark surface) + arrow_back_ios_new`. Used in all auth pages + password-and-security page. Moved from auth feature to global. |

### 13.4 CS (`colorScheme`) Shorthand

All pages use `final cs = Theme.of(context).colorScheme` to reference theme colors. No hardcoded colors aside from the shared tokens above:
- `cs.onSurface` — primary text color
- `cs.primary` — accent/links
- `cs.error` — error text
- `cs.surface` — dropdown/card bg
- `cs.outlineVariant` — subtle dividers

---

## 14. Validation & Form Patterns

### 14.1 Two-Tier Validation

| Tier | When | How | Style |
|------|------|-----|-------|
| **Format errors** | On user interaction | `AutovalidateMode.onUserInteraction` via `CustomTextField` | Field-level red text |
| **Required fields** | On submit only | Manual check before `formKey.validate()` | `ToastService.showError('X is required')` |

### 14.2 Implementation

```dart
// In submit handler — check required fields first
if (nameController.text.trim().isEmpty) {
  ToastService.showError('Full name is required');
  return;
}
// ... (check all required fields)

// Then validate format
if (formKey.currentState!.validate()) {
  await provider.register(...);
}
```

### 14.3 Validator Examples

| Field | Format Validator |
|-------|-----------------|
| Email | `RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')` + `"Please enter a valid email (e.g., name@example.com)"` |
| Phone (BD) | `RegExp(r'^01[3-9]\d{8}$')` + `"Enter a valid 11-digit Bangladeshi number"` |
| Password | Min 8 chars + "Add at least one uppercase letter" + "Add at least one number" |
| Name | `value.trim().split(' ').length < 2` + `"Please enter at least two names"` |

### 14.4 Key Rule

- `CustomTextField` uses `AutovalidateMode.onUserInteraction` internally
- When `isRequired: true`, the validator returns `null` for empty fields (no "required" message shown inline)
- "Required" messages are shown as **toasts** in the submit handler, not as field errors
- This keeps the UI clean: format errors appear as the user types, but "required" only appears on premature submit

---

## 15. Quick Checklist for Any New Feature

Before writing code, verify:

- [ ] **Domain first?** Entity → Repository Interface → Use Cases
- [ ] **Data second?** Model → Data Source → Repository Implementation
- [ ] **Presentation last?** Provider → Pages → Widgets
- [ ] **DI registered?** Added to `provider_setup.dart` (ProxyProvider for use cases, ChangeNotifierProvider for providers)
- [ ] **Input validation?** All use cases validate params before calling repository
- [ ] **Consumer optimized?** State-dependent widgets use `Consumer<T>`
- [ ] **AppConfig used?** No hardcoded URLs or timeouts
- [ ] **Helpers used?** `post()`/`put()`/`extractData()` from `BaseRemoteDataSource`, `safeCall<T>()` from `BaseRepository` mixin
- [ ] **Equatable?** `Failure` extends `Equatable`
- [ ] **Messages centralized?** Provider handles all messages via `ToastService` (not raw SnackBars or fluttertoast)
- [ ] **`implements UseCase`** (not `extends UseCase`)
- [ ] **Theme-aware?** Uses `cs.*` colors, no hardcoded colors except shared tokens (`#EFEFF0`, `#F5F5F5`, `#FCFCFD`)
- [ ] **Shared widgets used?** `CustomTextField` for inputs, `AuthButton` for solid primary CTA buttons, `AppBackButton` for back navigation
- [ ] **OOM-safe?** Image picking capped at `maxWidth: 4096, maxHeight: 4096`
- [ ] **No native ImageCropper?** Only manual `dart:ui` crop — `ImageCropper.cropImage()` crashes on Android 16
- [ ] **`extractData()` called?** Every data source method that calls `post()`/`get()`/`put()` passes the result to `extractData()`
- [ ] **DI order correct?** `http.Client → AuthHttpClient` override registered **before** `AuthRemoteDataSourceImpl`
- [ ] **TimeoutException handled?** `BaseRemoteDataSource.get()/post()/put()` catches `TimeoutException` and throws `ServerFailure('timeout')`
- [ ] **Image caching used?** Use `CachedNetworkImage` / `CachedNetworkImageProvider` instead of raw `NetworkImage` / `Image.network`
- [ ] **API key names match contract?** Check exact JSON key names in the API spec (e.g. `'newPassword'` not `'password'` for reset/change-password endpoints)

---

## 16. How to Use This File

1. **Give this file to the AI**: "Read `AI_CODING_GUIDE.md` to understand the project architecture and coding standards."
2. **Then give your task**: "Now add a Change Password feature following the patterns in the guide."
3. **The AI will**: Follow the step-by-step patterns, use the correct helpers, maintain Clean Architecture, use `implements UseCase` (not `extends`), and avoid common pitfalls.
4. **Prompt template**: See [`assets/prompts/prompt.txt`](assets/prompts/prompt.txt) for a reusable prompt template when requesting new features from an AI.

---

### Notifications Feature (`lib/features/notifications/`)

| Layer | Files | Purpose |
|-------|-------|---------|
| Presentation | `pages/notifications_page.dart` | In-app notification list with 7 hardcoded dummy items (read/unread states, time-ago timestamps). Shows `NotificationService.instance.showTestNotification()` test button at bottom |
| Service | `lib/global/core/services/notification_service.dart` | Singleton `NotificationService` using `flutter_local_notifications: ^18.0.0`. Channel: `test_notifications` (High importance). Small icon: `eduverse_logo` (white silhouette on `TextColor.appColor` circle). Style: `BigTextStyleInformation`. Android permission requested on init + before each `show()`. |

**Bell Icon Behavior** (top-right of CoursesPage):
- **Tap** → navigates to `/notifications` (in-app page)
- **Long press** → fires system tray notification via `showTestNotification()`

### Courses Feature — Current State (Partial Clean Architecture)

| Layer | Files | Purpose |
|-------|-------|---------|
| Domain | `entities/course_entity.dart`, `module_entity.dart`, `lesson_entity.dart`, `review_entity.dart` | Course domain entities |
| Domain | `repositories/courses_repository.dart` | Abstract repository (2 methods) |
| Domain | `usecases/get_course_details_usecase.dart`, `get_enrolled_course_usecase.dart` | Course use cases |
| Data | `datasources/courses_remote_data_source.dart` | Extends `BaseRemoteDataSource` — calls `courses/$id` and `courses/$id/enrolled` |
| Data | `models/course_model.dart` | `CourseModel` extends `CourseEntity` |
| Data | `repositories/courses_repository_impl.dart` | With `BaseRepository` mixin |
| Presentation | `providers/course_detail_provider.dart`, `enrolled_course_provider.dart` | **Currently use hardcoded mock data** — not calling API or use cases |
| Presentation | `pages/courses_page.dart`, `course_details_page.dart`, `enrolled_course_page.dart`, `upload_course_page.dart`, `upload_video_page.dart`, `manage_module_page.dart`, `payment_success_page.dart` | 7 pages |

**Key gap**: `CourseDetailProvider` and `EnrolledCourseProvider` return mock `CourseEntity` objects. The data source and repository are wired but the providers don't consume them yet. Backend endpoints exist (`courses/$id`, `courses/$id/enrolled`).

### Social Feature — UI Shell Only

- **Page**: `social_page.dart` — grid of 12 hardcoded sample user cards with search bar. No provider, no API integration. Implemented as a flat `SingleChildScrollView` with `ListView.builder`.

### Key Files Reference (Additions)

| File | Purpose |
|------|---------|
| [`lib/features/courses/presentation/pages/courses_page.dart`](lib/features/courses/presentation/pages/courses_page.dart) | Course listing page — search bar, horizontal category chips, course cards. Bell icon (top-right) navigates to `/notifications` on tap, fires system notification on long press |
| [`lib/features/courses/data/datasources/courses_remote_data_source.dart`](lib/features/courses/data/datasources/courses_remote_data_source.dart) | Courses remote data source — `getCourseDetails(id)`, `getEnrolledCourse(id)` |
| [`lib/features/notifications/presentation/pages/notifications_page.dart`](lib/features/notifications/presentation/pages/notifications_page.dart) | In-app notifications page with `__NotificationItem` model class (id, title, body, time, isRead), `_buildNotificationCard()` and `_buildTestButton()` widgets |
| [`lib/global/core/services/notification_service.dart`](lib/global/core/services/notification_service.dart) | `NotificationService` singleton — `init()`, `showTestNotification(title, body)`, `requestNotificationsPermission()` |

### Route Map (Additions)

| Route name | Path | Page |
|------------|------|------|
| `AppRoutes.notifications` | `/notifications` | `NotificationsPage` |
| `AppRoutes.manageModule` | `/manage-module` | `ManageModulePage` |
| `AppRoutes.adsManager` | `/ads-manager` | `AdsManagerPage` |
| `AppRoutes.adsCreate` | `/ads-create` | `AdsCreatePage` |

---

## 17. Notification Feature (WIP)

See [`project_performance_planner.md`](project_performance_planner.md) § "Notification Feature (WIP)" for full spec:

- Bell icon (CoursesPage): tap → `/notifications`, long press → system tray
- In-app page: hardcoded dummy data, no prefix icon, unread dot indicator
- System tray: `eduverse_logo` as small icon (left), `BigTextStyleInformation` body, `TextColor.appColor` tint
- Future: real Provider API, unread badge overlay, push notifications via FCM

---

*Last updated: 2026-06-01*
- Converted all messages from `fluttertoast` to `SnackBar` via global `scaffoldMessengerKey`; removed `fluttertoast` dependency
- Added `ToastService._getFriendlyMessage()` sanitizer for technical errors
- Cleaned up all `$e` leak messages across providers → user-friendly text
- Replaced all raw `SnackBar`/`ScaffoldMessenger.of(context)` calls → `ToastService`
- Fixed native `ImageCropper` crash on Android 16: manual `dart:ui` crop only (skips native)
- Capped `image_picker` calls at 4096px to prevent OOM on low-end devices
- Centralized theme in `app_theme.dart`: `scaffoldBackgroundColor: #FCFCFD` (light), `InputDecorationTheme` with `enabledBorder: #EFEFF0`, `fillColor: Colors.white` / `#1F2937` (dark)
- Added shared widgets: `CustomTextField` (auto-validate on interaction), `AuthButton` (solid `TextColor.appColor`), `AppBackButton` (consistent style)
- Replaced all hardcoded colors with `cs.*`, shared tokens (`#EFEFF0`, `#F5F5F5`, `#FCFCFD`), or theme `InputDecorationTheme`
- Validation: `AutovalidateMode.onUserInteraction` for format errors; "required" only on submit via toast
- Converted raw `ElevatedButton`s to `AuthButton` (solid `TextColor.appColor`) across all auth + profile edit pages
- Documented gender API inconsistency: `profile/update` expects `String` (`"1"`/`"0"`), `auth/register` expects `int` (`1`/`0`); added §5 request-body note and §9 pitfall
- Added `AppRoutes.navigateToProfile()` static helper for role-based profile navigation (§4.12)
- Added `clearProfile()` to `StudentProfileProvider` and `MentorProfileProvider` for logout state reset (§4.18)
- Rewrote HubPage `_fetchProfile()` to be role-aware (reads `AuthProvider.getUserRole()` → fetches correct provider) and re-runnable after logout (re-fetch trigger in `build()` for IndexedStack)
- Updated HubPage "Profile Details" to use `AppRoutes.navigateToProfile(context, profile?.role)` instead of hardcoded `/profile`
- Added visible `OutlineInputBorder` (12px radius, `#EFEFF0` stroke) to OTP code input fields in both `verification_page.dart` and `reset_verification_page.dart` (§4.19)
- **AuthHttpClient whitelist**: Changed from blanket `auth/` prefix bypass to explicit `_noAuthPaths` set — `auth/change-password` and `auth/logout` now receive Bearer token + 401 interception (§4.11)
- **DI order fix**: `AuthRemoteDataSourceImpl` now registered **after** the `http.Client → AuthHttpClient` override so it receives the wrapped client with Bearer token injection. Whitelist ensures public auth endpoints still bypass. (§4.8)
- **TimeoutException**: Added explicit `TimeoutException` catch in `BaseRemoteDataSource.get()/post()/put()` — throws `ServerFailure('timeout')` before generic catch
- **Role normalization**: `UserProfileModel.fromJson()` uses `normalizeRole()` to handle `int`/`String` `0`/`1` → `"STUDENT"`/`"MENTOR"` strings
- **cached_network_image**: Added package dependency; replaced all `NetworkImage`/`Image.network` across hub, courses, and profile widgets with `CachedNetworkImageProvider`/`CachedNetworkImage`
- **Change-password API**: Full implementation across auth data source/repository + hub use case/provider + DI wiring + `password_and_security_page.dart` integration (§10)
- **password_and_security_page**: Refactored with global widgets (`AppBackButton`, `CustomTextField`, `AuthButton`), SafeArea (no AppBar), no "Change Email" section, aligned padding with login page
- **Ad-supported video architecture**: Documented complete design for YouTube-style ad playback (§17) — backend-provided ad URLs, pre-roll/mid-roll, skip timer, single-controller source swap, provider state machine, `LessonEntity` updates, new `media_kit`-based video feature