Here's the finalized **`performance_planner.md`** — I'll present it here since we're in plan mode. Let me know when to write it.

---

```markdown
# Performance Planner — Background Upload, Notifications & Queue System

> **Last Updated**: 2026-06-15
> **Target Platforms**: Android (primary), iOS (secondary), Desktop (future)

---

## Overview

This document outlines the architecture and implementation plan for a robust background video upload system with real-time progress notifications (local + push), queue management, and resilient behavior across app lifecycle states (foreground, background, killed).

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                               │
│                                                                   │
│  ┌─────────────────┐  ┌────────────────────┐  ┌──────────────┐  │
│  │   UI Layer       │  │  Background Isolate │  │ Notification │  │
│  │ (Widgets)        │  │  (flutter_background│  │   Manager    │  │
│  │                  │  │   _service)         │  │              │  │
│  │QueueProgress     │  │                     │  │Local Notif   │  │
│  │DashboardWidget   │  │ Upload Loop         │  │Push Notif    │  │
│  │UploadZoneWidget  │  │ Retry Logic (3x)    │  │(FCM future)  │  │
│  │MainNavShell      │  │ Progress Callback   │  │              │  │
│  └────────┬─────────┘  └──────────┬──────────┘  └──────┬───────┘  │
│           │                       │                     │          │
│           └───────────┬───────────┘                     │          │
│                       │                                 │          │
│              ┌────────▼────────┐                        │          │
│              │  Upload Queue   │                        │          │
│              │   (SQLite)      │◄───────────────────────┘          │
│              │  upload_queue.db│                                   │
│              └────────┬────────┘                                   │
│                       │                                            │
│              ┌────────▼────────┐                                   │
│              │  S3 Upload      │                                   │
│              │  (64KB chunks)  │                                   │
│              └─────────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                        Server Side (Future)                        │
│                                                                     │
│  ┌──────────────┐     ┌──────────────┐     ┌───────────────────┐  │
│  │  API Server  │────▶│  FCM Push    │────▶│  Device           │  │
│  │  (Node.js)   │     │  Service     │     │  (Notification)   │  │
│  └──────────────┘     └──────────────┘     └───────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

## 2. App Lifecycle Behavior Matrix

| State | Android | iOS |
|---|---|---|
| **Foreground** | Upload via background isolate. Progress shown in UI + notification bar. | Same as Android. |
| **Background (user presses Home)** | Foreground service keeps uploading. Persistent notification in status bar. | Limited (~30s execution via BGTaskScheduler). Upload paused, resumed on foreground. |
| **Swiped away from Recents** | **Foreground service continues** (non-dismissable notification keeps service alive). Uploads continue. | iOS kills the app. Uploads **cannot continue**. Resume on next launch. |
| **Force-stopped from Settings** | Android kills everything. Pending uploads resume on next app launch. | Same — all state lost. Resume on next launch. |
| **Device reboot** | Pending uploads resume on next app launch. | Same. |
| **App not installed** | Push notifications (FCM) still work if server sends them. | Same. |

---

## 3. Notification Strategy

### 3.1 Local Notifications (Phase 1 — Immediate)
- **What**: `flutter_local_notifications` showing upload progress
- **When**: While app is backgrounded / service is running
- **Trigger**: Background isolate sends progress events
- **Types**:
  | Type | Behavior | Dismissable? |
  |---|---|---|
  | **Upload Progress** | Shows percentage (e.g., _"Uploading: Video Title — 45%"_) | No (ongoing) |
  | **Upload Complete** | Success notification with title | Yes (auto-dismiss) |
  | **Upload Failed** | Error message with retry action | Yes |
  | **Queue Finished** | All items processed | Yes |

### 3.2 Push Notifications via FCM (Phase 2 — Future)
- **What**: Firebase Cloud Messaging
- **When**: Server-side event triggers (upload fully processed, transcoded, published)
- **Why**: Covers cases where app is killed or not installed
- **Requires**:
  - Firebase project setup (google-services.json, GoogleService-Info.plist)
  - `firebase_messaging` package
  - Server-side integration to send push events
  - Notification channel for "Eduverse Updates"

---

## 4. Upload Queue System

### 4.1 Queue Lifecycle
```
User selects video(s)
        │
        ▼
    ┌─────────┐
    │ PENDING │ ◄── Added to SQLite queue with metadata
    └────┬────┘
         │
    ┌────▼──────┐
    │ UPLOADING │ ◄── Background isolate picks up item
    └────┬──────┘
         │
    ┌────▼─────────┐
    │ COMPLETED    │ ◄── Success: video post created via API
    │ (or FAILED)  │ ◄── Error: 3 retries with exponential backoff
    └──────────────┘        then marked failed
```

### 4.2 Resume Behavior
- **On app launch**: Check SQLite for any `pending` or `uploading` items
- **If found**: Immediately start processing from queue
- **Stale `uploading` items** (no progress > 5 min): Reset to `pending` and retry
- **Failed items**: Preserved for manual retry by user

### 4.3 Queue Table (SQLite) — Already Exists
```sql
CREATE TABLE upload_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filePath TEXT NOT NULL,
  title TEXT NOT NULL,
  videoDuration INTEGER,
  fileSize INTEGER,
  uploadUrl TEXT,
  fileUrl TEXT,
  status TEXT DEFAULT 'pending', -- pending|uploading|completed|failed|cancelled
  bytesUploaded INTEGER DEFAULT 0,
  errorMessage TEXT,
  createdAt TEXT DEFAULT CURRENT_TIMESTAMP
);
```

---

## 5. Implementation Phases

### Phase 1: Android Foreground Service (Week 1)
**Goal**: Upload continues even when app is swiped away.

**Changes needed:**

| File | Change |
|---|---|
| `pubspec.yaml` | No new deps needed (already have `flutter_background_service` + `flutter_local_notifications`) |
| `lib/main.dart` | Init service earlier, start foreground mode on app start |
| `lib/features/courses/services/background_upload_service.dart` | Add `ForegroundService` config with persistent notification (non-dismissable, shows upload progress) |
| `lib/global/core/services/upload_notification_service.dart` | Update notification channel for foreground service (high importance, ongoing) |
| `android/app/src/main/AndroidManifest.xml` | Add `FOREGROUND_SERVICE_*` permissions, `POST_NOTIFICATIONS` (API 33+) |

**Delivery**: On swipe-away, notification shows _"Eduverse is uploading a video..."_. Tap opens app.

---

### Phase 2: Auto-Resume on App Launch (Week 1)
**Goal**: If the background service was killed, resume pending uploads when user opens the app.

**Changes needed:**

| File | Change |
|---|---|
| `lib/main.dart` | Add `resumePendingUploads()` call after service init |
| `lib/features/courses/providers/video_queue_upload_provider.dart` | Add method `resumePending()` — reads SQLite for pending/uploading/expired items and enqueues them |
| `lib/features/courses/data/repositories/upload_queue_repository.dart` | Add query for stale `uploading` items (>5 min since last update) |

**Logic:**
```dart
Future<void> resumePendingUploads() async {
  final pending = await repo.getByStatus('pending');
  final staleUploading = await repo.getStaleUploading();
  // Reset stale to pending
  for (final item in staleUploading) {
    await repo.updateStatus(item.id, 'pending');
  }
  // Start background service if there are items
  if (pending.isNotEmpty || staleUploading.isNotEmpty) {
    BackgroundUploadService.start();
  }
}
```

---

### Phase 3: Improved Local Notifications (Week 2)
**Goal**: Rich notification experience — progress bar, action buttons (Pause/Cancel/Retry).

**Changes needed:**

| File | Change |
|---|---|
| `lib/global/core/services/upload_notification_service.dart` | Add notification actions: "Pause", "Cancel", "Retry" |
| `lib/features/courses/services/background_upload_service.dart` | Handle notification action callbacks, wire to queue provider |
| `lib/features/courses/providers/video_queue_upload_provider.dart` | Add handling for notification-triggered actions |

**Notification payload:**
```dart
UploadProgressNotification(
  queueItemId: 42,
  title: 'Calculus Lecture.mp4',
  progress: 0.45,
  status: 'uploading',
  actions: [NotificationAction('pause'), NotificationAction('cancel')],
)
```

---

### Phase 4: Push Notifications via FCM (Week 3-4)

**Changes needed:**

| File | Change |
|---|---|
| `pubspec.yaml` | Add `firebase_core`, `firebase_messaging` |
| `lib/main.dart` | Init Firebase, request notification permissions |
| `lib/global/core/services/push_notification_service.dart` | **New file** — handle token registration, incoming messages, foreground/background handlers |
| `lib/app/app.dart` | Register push notification service |
| `android/` | Add google-services.json |
| `ios/` | Add GoogleService-Info.plist |

**Push notification flows:**
| Event | Trigger | Notification Content |
|---|---|---|
| Upload processed | Server transcoding complete | "Your video 'Title' is ready!" |
| Upload failed on server | Server-side error | "Video 'Title' failed to process" |
| Course published | Mentor publishes course | "Your course 'Title' is live!" |

---

### Phase 5: Boot/Launch Auto-Start (Week 4, Optional)
**Goal**: Queue processing restarts automatically after device reboot.

**Android:**
- Add `RECEIVE_BOOT_COMPLETED` permission
- Register `BroadcastReceiver` to restart foreground service on boot
- Use `auto_start` package or manual manifest entry

**iOS:**
- Not possible (iOS does not allow post-reboot code execution)

---

## 6. Dependencies

### Current (already in pubspec.yaml)
```yaml
flutter_background_service: ^5.0.6
flutter_local_notifications: ^18.0.1
sqflite: ^2.4.2
path_provider: ^2.1.5
```

### New (to be added)
```yaml
firebase_core: ^3.x
firebase_messaging: ^15.x
```

---

## 7. Open Questions / Trade-offs

| Concern | Decision |
|---|---|
| **Android foreground service visible notification** | Required by Android 14+ for background processing. Shows _"Uploading video"_ — can't be hidden. Acceptable UX. |
| **iOS background execution limit** | iOS allows ~30s of background work. Uploads >30s must pause. Resume on next foreground. **No workaround.** |
| **FCM delivery guarantees** | Not guaranteed 100%. iOS may delay or drop. Use local notifications as fallback. |
| **Battery impact** | Foreground service with S3 uploads will drain battery. Consider Wi-Fi-only preference. |
| **Data usage** | Large video uploads use mobile data. Add a "Wi-Fi only" toggle for the queue. |

---

## 8. Success Criteria

- [ ] Upload continues after user swipes app away (Android)
- [ ] Persistent notification shows accurate, live progress percentage
- [ ] Pending uploads auto-resume on app launch (even after force-kill)
- [ ] Notification actions work (Pause / Cancel / Retry)
- [ ] Failed items show error message and allow retry
- [ ] FCM push notifications arrive when app is fully killed (Phase 4)
- [ ] No ANR (Application Not Responding) errors during background upload
- [ ] Queue survives device reboot (pending items remain)

---

## 9. Files Summary

### New Files
| File | Purpose |
|---|---|
| `lib/global/core/services/push_notification_service.dart` | FCM init, token mgmt, message handlers |
| `lib/global/core/services/foreground_service_handler.dart` | Foreground service config, persistent notification builder |

### Modified Files
| File | What Changes |
|---|---|
| `lib/main.dart` | Start foreground service, resume pending queue, init Firebase |
| `lib/app/app.dart` | Register push notification provider, permission handler |
| `pubspec.yaml` | Add firebase dependencies |
| `lib/features/courses/services/background_upload_service.dart` | Add foreground mode config, notification progress updates, handle notification actions |
| `lib/global/core/services/upload_notification_service.dart` | Add notification actions (pause/cancel/retry), foreground channel setup |
| `lib/features/courses/providers/video_queue_upload_provider.dart` | Add `resumePending()`, stale-item detection, notification action routing |
| `lib/features/courses/data/repositories/upload_queue_repository.dart` | Add `getStaleUploading()`, `resetToPending()` queries |
| `android/app/src/main/AndroidManifest.xml` | Foreground service permissions, boot receiver, FCM metadata |
| `ios/Runner/Info.plist` | Background modes, notification capabilities |
```

---

That's the full document. Want me to proceed to write it to `performance_planner.md` once implementation mode is active?