# Eduverse — Store Publication Conflict Analysis

> Comprehensive audit of issues that will block or complicate Play Store & App Store publishing.

---

## Table of Contents

1. [Android — Build & Signing](#1-android--build--signing)
2. [Android — Manifest & Permissions](#2-android--manifest--permissions)
3. [iOS — Build & Signing](#3-ios--build--signing)
4. [iOS — Info.plist & Capabilities](#4-ios--infoplist--capabilities)
5. [iOS — Privacy Manifests (Apple Requirement)](#5-ios--privacy-manifests-apple-requirement)
6. [Cross-Platform — Network Security](#6-cross-platform--network-security)
7. [Cross-Platform — Firebase / Google Services](#7-cross-platform--firebase--google-services)
8. [Cross-Platform — Background Upload Service](#8-cross-platform--background-upload-service)
9. [Cross-Platform — media_kit (Video Player)](#9-cross-platform--media_kit-video-player)
10. [Cross-Platform — flutter_secure_storage](#10-cross-platform--flutter_secure_storage)
11. [Cross-Platform — Google Sign-In](#11-cross-platform--google-sign-in)
12. [Cross-Platform — image_picker & image_cropper](#12-cross-platform--image_picker--image_cropper)
13. [Cross-Platform — App Metadata](#13-cross-platform--app-metadata)
14. [Cross-Platform — Code Quality & Stability](#14-cross-platform--code-quality--stability)
15. [Cross-Platform — Payment / In-App Purchase](#15-cross-platform--payment--in-app-purchase)

---

## 1. Android — Build & Signing

### 1.1 Debug Signing Config in Release Build

**File:** `android/app/build.gradle.kts:36-40`

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug") // ❌
    }
}
```

**Issue:** Release builds use debug keystore. Play Store requires a release keystore with a unique alias, password validity >25 years.

**Solution:**

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("STORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable ProGuard/R8
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 1.2 minSdkVersion Not Explicitly Set

**File:** `android/app/build.gradle.kts:29`

```kotlin
minSdk = flutter.minSdkVersion
```

**Issue:** Relies on Flutter's default (which may be 21). Some plugins (e.g., `media_kit`, `flutter_background_service`) may require higher. Play Store requires minSdk ≥ 29 for new apps from Aug 2024, ≥ 26 for updates from Aug 2025.

**Solution:** Pin explicitly:

```kotlin
minSdk = 23  // or higher based on plugin requirements
```

Check with:

```bash
grep -r "minSdk" .dart_tool/ pubspec.lock
```

### 1.3 Version Code & Name Not Set

**File:** `android/app/build.gradle.kts:31-32`

```kotlin
versionCode = flutter.versionCode
versionName = flutter.versionName
```

**Issue:** Uses Flutter defaults (1.0). Need proper versioning for Play Store.

**Solution:** Set in `pubspec.yaml`:

```yaml
version: 1.0.0+1  # versionName + versionCode
```

---

## 2. Android — Manifest & Permissions

### 2.1 Cleartext HTTP Traffic Blocked

**File:** `lib/global/core/config/app_config.dart:7`

```dart
static const String baseUrl = 'http://108.181.195.154:3000/api/v1';
```

**Issue:** Android 9+ blocks cleartext HTTP. The base URL uses `http://`. Will get `Cleartext HTTP traffic not permitted` errors.

**Solution option A — Allow all cleartext (temporary):**
Add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
android:usesCleartextTraffic="true"
```

**Solution option B — Network Security Config (recommended):**
Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">108.181.195.154</domain>
    </domain-config>
</network-security-config>
```

Then reference in `AndroidManifest.xml`:

```xml
android:networkSecurityConfig="@xml/network_security_config"
```

**Best solution:** Move to HTTPS.

### 2.2 Missing INTERNET Permission

**File:** `android/app/src/main/AndroidManifest.xml`

**Issue:** No `<uses-permission android:name="android.permission.INTERNET"/>` declared. Flutter debug mode adds it implicitly, but release APK may lack it.

**Solution:**

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 2.3 App Label Uses Development Name

**File:** `android/app/src/main/AndroidManifest.xml:7`

```xml
android:label="eduverse_tan"
```

**Issue:** Shows "eduverse_tan" on the device launcher.

**Solution:**

```xml
android:label="Eduverse"
```

### 2.4 Missing Foreground Service Permissions

**File:** `android/app/src/main/AndroidManifest.xml:3-5`

Already has `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC`. But for Android 14+, `FOREGROUND_SERVICE_DATA_SYNC` must be explicitly listed when targeting SDK 34+.

**Check:** Ensure `targetSdk` is 34+ and these are present (already done).

**Additional:** Add `POST_NOTIFICATIONS` permission request at runtime (already handled in `video_queue_upload_provider.dart:167-169`). Good.

---

## 3. iOS — Build & Signing

### 3.1 No Podfile in Repository

**Issue:** `ios/Podfile` not checked in. Flutter generates it during `pod install`, but a custom Podfile is needed for:
- Minimum iOS version
- Post-install hooks
- Build settings

**Solution:** Create `ios/Podfile`:

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(
    File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'),
    __FILE__
  )
  unless File.exist?(generated_xcode_build_settings_path)
    generated_xcode_build_settings_path = File.expand_path(
      File.join('..', 'Flutter', 'Generated.xcconfig'),
      __FILE__
    )
  end
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure \"flutter pub get\" is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      # Required for media_kit on older Xcode
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
      ]
    end
  end
end
```

### 3.2 Minimum iOS Version Not Enforced

**Issue:** No explicit minimum iOS deployment target set. If it defaults below 13.0, older devices won't be supported and some plugins may break.

**Solution:** Set in Podfile as above (`platform :ios, '13.0'`) and match in Xcode project settings.

### 3.3 Code Signing & Provisioning

**Issue:** No explicit signing configuration in the Xcode project (uses automatic). For App Store distribution, you need:
- App Store distribution certificate
- App ID with proper bundle identifier
- App Store provisioning profile

**Solution:** In Xcode:
1. Set bundle ID to match App Store (e.g., `net.eduverseapp.platform`)
2. Change Team to your Apple Developer account
3. Use "Apple Distribution" signing for Release

---

## 4. iOS — Info.plist & Capabilities

### 4.1 HTTP (Non-HTTPS) Blocked by ATS

**File:** `ios/Runner/Info.plist`

**Issue:** Base URL uses `http://` (see `app_config.dart:7`). iOS App Transport Security blocks all HTTP by default.

**Solution:** Add to `ios/Runner/Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>108.181.195.154</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Best:** Migrate to HTTPS.

### 4.2 Missing Photo Library Usage Descriptions

**File:** `ios/Runner/Info.plist`

**Issue:** Uses `image_picker` but no `NSPhotoLibraryUsageDescription`. iOS will crash when trying to access photo library.

**Solution:** Add:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Eduverse needs access to your photo library to set your profile picture and upload course materials.</string>
<key>NSCameraUsageDescription</key>
<string>Eduverse needs camera access to take profile photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Eduverse may need microphone access for video recordings.</string>
```

### 4.3 Bundle Display Name Inconsistency

**File:** `ios/Runner/Info.plist:10-18`

```xml
<key>CFBundleDisplayName</key>
<string>Eduverse</string>
<key>CFBundleName</key>
<string>eduverse</string>
```

**Issue:** Inconsistent naming. `CFBundleName` cannot contain lowercase in some App Store checks.

**Solution:**

```xml
<key>CFBundleDisplayName</key>
<string>Eduverse</string>
<key>CFBundleName</key>
<string>Eduverse</string>
```

### 4.4 Background Modes — Upload Not Declared

**File:** `ios/Runner/Info.plist:40-43`

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

**Issue:** The app uses `flutter_background_service` for uploads. On iOS, true background execution is very restricted. Only `audio` is declared. If upload continues when app is backgrounded, iOS may terminate it.

**Solution option A:** If uploads should work in background, add `processing`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>processing</string>
</array>
```

**Solution option B (recommended):** Accept iOS limitations — only upload while app is in foreground. The `flutter_background_service` on iOS can only keep the app alive for ~30 seconds in background. Show a proper message.

---

## 5. iOS — Privacy Manifests (Apple Requirement)

### 5.1 Required Privacy Manifests

**Issue:** Starting Spring 2024, Apple requires privacy manifests for SDKs that use certain APIs (required reasons). Failing to provide them will result in App Store rejection.

**Affected SDKs used by this project:**

| SDK | Required Reason API | Risk |
|-----|-------------------|------|
| `flutter_secure_storage` | Keychain (NSUserDefaults) | High |
| `image_picker` | Photo Library | High |
| `path_provider` | File System | Medium |
| `media_kit_video` | Camera/Microphone | Medium |
| `sqflite` | File System | Medium |

**Solution:**

Each Flutter plugin should include its own privacy manifest. However, you must verify:

1. Run `flutter build ios` and check for warnings about missing privacy manifests.
2. For each plugin that lacks a privacy manifest, add one manually in `ios/Runner/`.
3. The main app also needs a privacy manifest if it accesses required reason APIs.

Create `ios/Runner/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>85F4.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

---

## 6. Cross-Platform — Network Security

### 6.1 Non-HTTPS Base URL

**File:** `lib/global/core/config/app_config.dart:7`

```dart
static const String baseUrl = 'http://108.181.195.154:3000/api/v1';
```

**Critical issue for both stores:**
- **Android:** Cleartext blocked by default (API 28+)
- **iOS:** ATS blocks non-HTTPS by default
- **User trust:** Chrome/Safari mark HTTP as "Not Secure"
- **Data security:** Tokens and user data sent over plaintext

**Solution:** Use HTTPS on the server. Update:

```dart
static const String baseUrl = 'https://yourdomain.com/api/v1';
```

### 6.2 No SSL Pinning

**Issue:** No certificate pinning. A man-in-the-middle attack could intercept JWT tokens.

**Solution:** Add certificate pinning using `http` package's `BadCertificateCallback` or use a package like `ssl_pinning_plugin`.

---

## 7. Cross-Platform — Firebase / Google Services

### 7.1 No Firebase Configuration Files

| Platform | Required File | Status |
|----------|--------------|--------|
| Android | `google-services.json` | ❌ Missing |
| iOS | `GoogleService-Info.plist` | ❌ Missing |

**Issue:** Without these files, Firebase services (Crashlytics, Analytics, Auth) will fail. The app does not currently import Firebase (verified: no `firebase_*` in `pubspec.yaml`), but `project.md` mentions Firebase integration. If Firebase is added later, these files are mandatory.

**Solution:** Download from Firebase Console when adding Firebase.

### 7.2 Google Sign-In — Android Configuration

**Issue:** `google_sign_in` needs `default_web_client_id` in `android/app/src/main/res/values/strings.xml` for the web client ID to work. Currently no such file.

**Solution:** Create `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="default_web_client_id" translatable="false">914828544219-v3sbd8bcui352873r4teffmcme2dtmqs.apps.googleusercontent.com</string>
</resources>
```

### 7.3 Google Sign-In — iOS Configuration

**File:** `ios/Runner/Info.plist:30-36`

The `CFBundleURLSchemes` is set to `com.googleusercontent.apps.914828544219-91pktjhp0knkjp8miffenc85i7kbu7o2`.

**Issue:** This must match the REVERSED_CLIENT_ID from the iOS GoogleService-Info.plist. Without `GoogleService-Info.plist`, the URL scheme may be incorrect.

**Solution:** Once you generate `GoogleService-Info.plist` from Firebase, extract the `REVERSED_CLIENT_ID` and ensure it matches the URL scheme. If not using Firebase, create the reversed client ID manually:

From `AppConfig.googleClientId` = `914828544219-v3sbd8bcui352873r4teffmcme2dtmqs.apps.googleusercontent.com`
Reversed = `com.googleusercontent.apps.914828544219-v3sbd8bcui352873r4teffmcme2dtmqs`

The current URL scheme `914828544219-91pktjhp0knkjp8miffenc85i7kbu7o2` does NOT match the reversed `serverClientId`. **This will break Google Sign-In on iOS.**

---

## 8. Cross-Platform — Background Upload Service

### 8.1 iOS Background Execution Limitations

**File:** `lib/features/courses/services/background_upload_service.dart`

**Issue:** The background upload service uses `flutter_background_service` which has fundamental differences:

| Behavior | Android | iOS |
|----------|---------|-----|
| Background execution | Full foreground service (persistent notification) | ~30 seconds max, then suspended |
| File upload completion | Works reliably | Will be killed |
| `_onIosBackground` handler | N/A | Returns `true` — no-op stub |

**Solution:** On iOS, implement a different upload strategy:

```dart
// In background_upload_service.dart
static void _onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    // Full background execution (existing code)
  } else {
    // iOS: Use BGTaskScheduler or URLSession background upload
    // Consider using a native iOS plugin or URLSession
    // Show a message: "Keep app open during upload"
  }
}
```

### 8.2 Background Processing on iOS (BGTaskScheduler)

**Issue:** iOS doesn't allow arbitrary background work. Apple rejects apps that attempt to run services in the background without a declared purpose.

**Solution:** For iOS, consider:
1. Remove background upload capability — only upload while app is foregrounded
2. Use `background_fetch` for short tasks
3. Implement proper BGTaskScheduler via a Swift native plugin

---

## 9. Cross-Platform — media_kit (Video Player)

### 9.1 Missing iOS Video Libraries

**File:** `pubspec.yaml:22`

```yaml
media_kit_libs_android_video: ^1.3.5
```

**Issue:** Only Android video libraries are included. iOS needs `media_kit_libs_ios_video`.

**Solution:** Add:

```yaml
media_kit_libs_ios_video: ^1.1.4
```

### 9.2 Video Metadata — Missing Android Platform Implementation

**File:** `lib/global/core/services/video_metadata_service.dart`

Uses a MethodChannel `eduverse/video_metadata`. The iOS handler exists in `AppDelegate.swift`. But **no Android handler** exists.

**Issue:** `getVideoInfo` will throw an exception on Android (fallback returns `{duration: 1, fileSize: 0}`).

**Solution:** Add Android MethodChannel handler in `MainActivity.kt` or `MainActivity.java`:

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "eduverse/video_metadata"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVideoInfo") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARG", "path required", null)
                    return@setMethodCallHandler
                }
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(path)
                    val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    val duration = durationStr?.toIntOrNull() ?: 0
                    val file = java.io.File(path)
                    result.success(mapOf(
                        "duration" to duration / 1000,
                        "fileSize" to file.length()
                    ))
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                } finally {
                    retriever.release()
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
```

---

## 10. Cross-Platform — flutter_secure_storage

### 10.1 Keychain / EncryptedPrefs Configuration

**Issue:** `flutter_secure_storage` uses Keychain on iOS and EncryptedSharedPreferences on Android. Potential issues:

**Android:**
- Requires `minSdkVersion` 18+ (OK)
- EncryptedSharedPreferences requires API 23+ for AES-256

**iOS:**
- Needs Keychain Sharing capability if accessing across apps (not needed here)
- Keychain data persists after app deletion (set accessibility level)

**Solution:** Configure accessibility in Dart code (optional):

```dart
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
```

---

## 11. Cross-Platform — Google Sign-In

### 11.1 Conflicting Client IDs

**File:** `lib/global/core/config/app_config.dart:10-11`

```dart
static const String googleClientId =
    '914828544219-v3sbd8bcui352873r4teffmcme2dtmqs.apps.googleusercontent.com';
```

**Issue:** This is used as both `clientId` and `serverClientId` in `google_sign_in_service.dart:44-45`.

- **Android:** `serverClientId` must match the Web Client ID from Google Cloud Console.
- **iOS:** `clientId` must match the iOS Client ID from Google Cloud Console.
- **Web:** `clientId` must match the Web Client ID.

Using the same ID for both may work but is not correct approach. Best practice:

```dart
_googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  // iOS uses clientId, Android uses serverClientId
  clientId: AppConfig.googleClientId,      // iOS
  serverClientId: AppConfig.googleServerClientId,  // Android & Web
);
```

### 11.2 Incorrect iOS URL Scheme

**File:** `ios/Runner/Info.plist:34`

```xml
<string>com.googleusercontent.apps.914828544219-91pktjhp0knkjp8miffenc85i7kbu7o2</string>
```

**Issue:** This URL scheme doesn't match the `AppConfig.googleClientId`'s reversed form (which would be `com.googleusercontent.apps.914828544219-v3sbd8bcui352873r4teffmcme2dtmqs`). This will cause Google Sign-In to fail on iOS.

**Solution:** Generate a dedicated iOS Client ID in Google Cloud Console, get its reversed form, and:

1. Update `ios/Runner/Info.plist` URL scheme
2. Set it as `clientId` in the GoogleSignIn constructor

---

## 12. Cross-Platform — image_picker & image_cropper

### 12.1 image_cropper iOS Configuration

**Issue:** `image_cropper` may need iOS-specific configuration. The package uses `TOCropViewController` on iOS.

**Solution:** Ensure `ios/Podfile` has:

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_MICROPHONE=1',
  'PERMISSION_CAMERA=1',
  'PERMISSION_PHOTOS=1',
]
```

### 12.2 Large Image Handling

**File:** `lib/features/profile/avatar/providers/avatar_upload_provider.dart:56-59`

```dart
maxWidth: 4096,
maxHeight: 4096,
```

**Issue:** 4096×4096 images can cause OOM on low-end devices.

**Solution:** Reduce to 2048 or make configurable.

---

## 13. Cross-Platform — App Metadata

### 13.1 App Name Inconsistency

| Location | Value |
|----------|-------|
| `pubspec.yaml` | `edtech` |
| `android/app/src/main/AndroidManifest.xml` | `eduverse_tan` |
| `ios/Runner/Info.plist CFBundleDisplayName` | `Eduverse` |
| `ios/Runner/Info.plist CFBundleName` | `eduverse` |
| `android/app/build.gradle.kts namespace` | `net.eduverseapp.platform` |
| `android/app/build.gradle.kts applicationId` | `net.eduverseapp.platform` |

**Issue:** Inconsistent naming across platforms.

**Solution:** Standardize:
- App display name: `Eduverse`
- Application ID: `net.eduverseapp.platform` (or `com.eduverse.app`)
- Package name in pubspec: `eduverse`

### 13.2 Missing App Icon Variations

**Issue:** No platform-specific app icon configurations. Play Store and App Store require specific icon formats.

**Solution:**
- **Android:** Use `flutter_launcher_icons` package or manually provide adaptive icons (foreground + background layers)
- **iOS:** Provide icons in all required sizes (20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024)

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

### 13.3 Missing Screenshots & Store Listing

**Issue:** No store listing assets.

**Solution:** Prepare per store requirements:
- **Play Store:** 2-8 screenshots per device type (phone, tablet, Chromebook, etc.), feature graphic (1024×500), TV banner (1280×720)
- **App Store:** 6.5" (1242×2688), 5.5" (1242×2208), 12.9" iPad (2048×2732) screenshots

---

## 14. Cross-Platform — Code Quality & Stability

### 14.1 No Privacy Policy URL

**Issue:** Both stores require a privacy policy URL if the app handles user data (email, profile photos, etc.).

**Solution:** Host a privacy policy page and provide URL in store listing.

### 14.2 App Review Guidelines — Minimum Functionality

**Issue:** The app has several empty/stub screens and hardcoded data:
- `social_feed` — empty/placeholder data
- `wish_list` — hardcoded items
- `notifications` — hardcoded items
- `payments` — mock data

**Solution:** Either implement real functionality or remove/hide these features for initial submission. App Store Review Guidelines 4.2 require apps to be useful and functional.

### 14.3 Error Handling on iOS (AppDelegate)

**File:** `ios/Runner/AppDelegate.swift:21-51`

The `getVideoInfo` MethodChannel handler uses `AVAsset` synchronously. For remote URLs, this blocks the UI thread.

**Issue:** `AVAsset` loading should be asynchronous using `loadValuesAsynchronously`.

**Solution:**

```swift
let asset = AVAsset(url: url)
let keys = ["duration", "fileSize"]
asset.loadValuesAsynchronously(forKeys: keys) {
    // Access duration/size properties after loading
}
```

### 14.4 Logger Prints to Console in Release Mode

**File:** `lib/global/core/services/logger_service.dart`

Uses `PrettyPrinter` with emojis, colors, and timestamps. This works in debug but prints sensitive data in release builds.

**Issue:** Potential data leakage. Logger may print tokens, user data, API responses.

**Solution:** Disable logging in release mode:

```dart
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: kReleaseMode ? Level.nothing : Level.debug,
  );
  // ...
}
```

---

## 15. Cross-Platform — Payment / In-App Purchase

### 15.1 No Payment Gateway Implementation

**Issue:** The app has a `payment_success_screen.dart` and a `payments_and_revenue_screen.dart` but no actual payment integration (no Stripe, no Razorpay, no in-app purchase).

**File:** `lib/features/courses/presentation/screens/payment_success_screen.dart`

This screen is navigated to directly from `course_details_screen.dart:545`:

```dart
onPressed: () => Navigator.pushNamed(context, AppRoutes.paymentSuccess),
```

**Issue:** This is a mock payment flow. If you implement payments:

- **Play Store (Android):** Digital goods must use Google Play's billing system (30% commission). Using Stripe/Razorpay directly is not allowed.
- **App Store (iOS):** Digital content must use in-app purchase (30% commission for most).

**Solution for physical/non-digital:** If Eduverse sells physical courses (attended in person), third-party payments are allowed.

**Solution for digital courses:** Must use:
- Android: Google Play Billing (`in_app_purchase` package)
- iOS: StoreKit via `in_app_purchase` package

---

## Summary: Blocking Issues by Store

### Play Store (Must Fix Before Publish)

| # | Issue | Severity |
|---|-------|----------|
| 1 | Release signing config (debug keystore) | 🔴 Blocking |
| 2 | Cleartext HTTP to API | 🔴 Blocking |
| 3 | Missing INTERNET permission | 🔴 Blocking |
| 4 | App label "eduverse_tan" | 🟡 High |
| 5 | No explicit minSdkVersion | 🟡 High |
| 6 | Version code management | 🟡 High |
| 7 | No app icon assets | 🟡 Medium |
| 8 | No privacy policy URL | 🟡 Medium |
| 9 | Missing Android video metadata handler (MethodChannel) | 🟡 Medium |

### App Store (Must Fix Before Publish)

| # | Issue | Severity |
|---|-------|----------|
| 1 | HTTP cleartext API (ATS blocks) | 🔴 Blocking |
| 2 | Missing privacy descriptions (photo library, camera) | 🔴 Blocking |
| 3 | Google Sign-In URL scheme mismatch | 🔴 Blocking |
| 4 | No Podfile / min iOS version | 🔴 Blocking |
| 5 | Missing privacy manifest (WWDC 2024 requirement) | 🔴 Blocking |
| 6 | No code signing / provisioning profile | 🔴 Blocking |
| 7 | Background service on iOS (limited) | 🟡 High |
| 8 | CFBundleName lowercase inconsistency | 🟡 High |
| 9 | Missing `media_kit_libs_ios_video` | 🟡 High |
| 10 | No privacy policy URL | 🟡 Medium |
| 11 | No GoogleService-Info.plist | 🟡 Medium |

### Both Stores (Should Fix)

| # | Issue | Severity |
|---|-------|----------|
| 1 | No actual payment gateway (mock flow) | 🟡 High |
| 2 | Stub/empty screens submitted | 🟡 Medium |
| 3 | Logger leaking data in release | 🟡 Medium |
| 4 | No SSL pinning | 🟡 Medium |
| 5 | Mock/hardcoded data (social, notifications) | 🟡 Low |
| 6 | 4096px image size may cause OOM | 🟡 Low |
| 7 | App name inconsistency across platforms | 🟡 Low |
| 8 | No app icon set | 🟡 Medium |
