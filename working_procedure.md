# Video Upload Working Procedure

## Architecture Overview

```
User taps "Upload"
       |
ManageModuleProvider          (UI coordination, polling, pending-lesson tracking)
       |
UnifiedUploadQueueProvider     (queue orchestrator, lock, callbacks)
       |
       +-- UploadQueueRepository            (SQLite persistence)
       +-- BackgroundUploadService          (presigned URL fetch)
       +-- BackgroundUploaderService        (enqueue to native WorkManager)
       +-- VideoMetadataHelper              (duration/size extraction)
       +-- UploadNotificationService        (permissions)
```

## Complete Flow (Module Lesson Upload)

### Phase 1: User taps "Upload"

1. **`ManageModuleProvider.addVideoLesson()`** — validates no concurrent queue op (`_isQueuing`), checks dedup (`_checkDedupOrCleanup`), generates `lessonId`, calls into queue provider.

2. **`UnifiedUploadQueueProvider.addModuleLessonToQueue()`**:
   - Checks file exists on disk
   - Checks not already in queue (`_hasInFlightFile`)
   - Ensures notification permission (3-step escalation: request → dialog → open-settings)
   - Creates `ModuleLessonMetadata` (moduleId, courseId, lessonTitle, lessonId) → serialized as JSON
   - Extracts `fileSize` + `duration` via `VideoMetadataHelper`
   - **Inserts** an `UploadQueueItem` (`status: 'pending'`) into SQLite
   - **Fetches presigned S3 URL** via `BackgroundUploadService.fetchPresignedUrl()` — POSTs to server with filename + contentType + moduleID
   - **Stores URLs** in SQLite via `updateUrls()`
   - Shows toast "Video lesson queued"
   - Calls **`_processNextItem()`** to kick the engine

### Phase 2: Queue picks it up

3. **`_processNextItem()`** (serial, one at a time):
   - Acquires `_isUploading` lock (set synchronously before any `await`)
   - Queries `getActive()` → finds first `pending` item with `uploadUrl` and no `workerId`
   - Sets `status → 'uploading'` in SQLite, notifies UI
   - Calls **`BackgroundUploaderService.enqueueUpload()`**:
     - Creates `UploadTask.fromFile` → `PUT`, binary, presigned URL
     - Embeds `{itemId: <id>}` in `metaData` (survives app kill)
     - Configures `retries: 10`, `updates: Updates.statusAndProgress`
     - Calls `FileDownloader().enqueue(task)` → native WorkManager
   - Stores returned `taskId` as `workerId` in SQLite

### Phase 3: Native upload (survives app kill)

4. **WorkManager** runs in native isolate (Android):
   - Opens PUT connection to S3
   - Streams file chunks
   - Runs as foreground service with notification
   - Auto-retries up to 10 times on failure

### Phase 4: Progress reporting

5. **`_onNativeTaskProgress()`** (fires from native):
   - Extracts `itemId` from `update.task.metaData`
   - Clamps progress 0-100%, updates `_activeProgress`
   - Throttled write: only persists to SQLite on whole-percent boundary
   - Every 200th tick → `checkpointWal()` (trims WAL file)

6. **`ManageModuleProvider._pollProgress()`** (5s timer):
   - Reads SQLite + `background_downloader` database for live progress
   - Updates `PendingLesson` → UI shows progress

### Phase 5: Upload completes

7. **`_onNativeTaskStatus(complete)`** → `_handleNativeComplete()`:
   - Sets `nativeMarkedCompleted = 1` in SQLite
   - Calls **`_sendCallbackForItem()`**:
     - Builds payload via `_buildCallbackDetails()` — for module_lesson: POST to `/api/course-module-lesson` with `{title, videoUrl, moduleId, duration, fileSize}`
     - Sends with `Idempotency-Key: <uploadId>_callback`
     - Accepts 200/201/409 as success
   - **Callback succeeds**: sets `serverCallbackCompleted = 1`, `status = 'completed'`, deletes cached file, shows success toast
   - **Callback fails**: marks item `'failed'` — S3 uploaded but server doesn't know

### Phase 6: Next item in queue

8. **`_onItemTerminal(id)`**:
   - Releases `_isUploading` lock, clears `_activeItem`
   - Reloads queue from SQLite, notifies UI
   - Calls `_processNextItem()` — starts next queued item

### Phase 7: UI refresh

9. **`_pollProgress()`** detects `completed`:
   - Removes from `_pendingLessons`, shows toast (once per queueId)
   - Calls **`_silentRefresh()`** → re-fetches course from server → new lesson appears

---

## Edge Cases & Recovery

| Scenario | How it's handled |
|---|---|
| **App killed mid-upload** | WorkManager continues — on restart, `start(doRescheduleKilledTasks: true)` re-fires completion callbacks; 500ms settling delay ensures terminal states persist before `_loadQueue` inspects |
| **App killed, upload completed while dead** | Callback re-fired by `start()`; 500ms delay lets it arrive before `_processNextItem` runs |
| **Concurrent upload attempts** | `_isUploading` mutex — second caller returns immediately; `_onItemTerminal` triggers next after current finishes |
| **Native task lost (WorkManager dropped it)** | Queue pump runs every 15s — if item in `'uploading'` for >10 min, calls `resetStaleUploading()` to revert to `'pending'` and re-enqueue |
| **Dart lock stuck** | Pump detects `_isUploading` true for >5 min with no `'uploading'` item in DB → releases lock |
| **Stale native callback arrives after item is terminal** | `_onNativeTaskStatus()` skips if status is already `completed`/`cancelled` |
| **Same file added twice** | `_checkDedupOrCleanup()` blocks if `pending`/`uploading`; deletes old row + cached file if terminal, allowing re-upload |
| **Network fails mid-upload** | `retries: 10` — WorkManager auto-retries; if exhausted, item marked `'failed'`, user taps Retry → fresh presigned URL |
| **S3 succeeds, server callback fails** | Item marked `'failed'` (file is on S3 but not registered); retry re-uploads to new S3 URL |
| **Notification permission denied** | 3-step escalation — request → dialog → open-settings; upload blocked without permission |
| **SQLite WAL grows large** | Progress writes throttled to whole-percent boundaries; WAL checkpoint every 200 progress ticks; `runStartupCleanup()` on every app start |
| **Orphaned cache files** | `cleanupOrphanedCacheFiles()` on startup — deletes files in docs/temp not tracked by any SQLite row |

## Key Files

| File | Role |
|---|---|
| `providers/unified_upload_queue_provider.dart` | Queue orchestrator — init, process, callbacks, lock, pump, callback server |
| `manage_module/providers/manage_module_provider.dart` | UI coordination — add lessons, poll progress, restore pending, refresh |
| `services/background_uploader_service.dart` | Bridge to `background_downloader` — `enqueueUpload()`, `sendServerCallback()` |
| `services/background_upload_service.dart` | Presigned URL fetch — `fetchPresignedUrl()`, S3 verify, content-type helpers |
| `data/repositories/upload_queue_repository.dart` | SQLite CRUD — schema v5, `resetStaleUploading()`, `checkpointWal()`, cleanup |
| `data/models/upload_task.dart` | Enums (`UploadTaskType`), metadata models (`ModuleLessonMetadata`) |
| `app/native_init.dart` | Startup — configure foreground service, `runStartupCleanup()` |
| `global/core/services/upload_notification_service.dart` | Notification channels, permission, foreground service lifecycle |
