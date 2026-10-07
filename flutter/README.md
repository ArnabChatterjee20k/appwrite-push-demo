# Appwrite Push in Flutter

A one-screen Flutter app that signs in, subscribes to the signed-in user's own topic and logs
connection changes, messages and notification taps. This README is the full guide to Push in the
`appwrite` package. The server side (provider, `createPush`) is in the
[root README](../README.md#server-provider-and-sending).

## Run this app

1. Fill in `lib/config.dart` (endpoint, project, email and password).
2. `flutter pub get`
3. `flutter run` on an Android device or emulator, an iOS device or simulator, or Chrome.

Send a push to the user's id and watch it arrive in the app's log, or as a notification while the
app is in the background or closed. On Android, use the buttons to allow exact alarms and the
battery exemption, and **Check background status** to see what background delivery can rely on;
the manifest declares both permissions.

## 1. Install

```bash
flutter pub add appwrite
```

Android: `Push` includes a native plugin that needs Android 7.0 (API 24) or later, and
`flutter_local_notifications` needs core library desugaring. Add both to
`android/app/build.gradle.kts`, as this app does:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

## 2. Client and sign-in

```dart
final client = Client().setEndpoint(endpoint).setProject(project);
await Account(client).createEmailPasswordSession(email: email, password: password);

final push = Push(client);
```

- `Push` uses the session the app signed in with through this client (its cookie store; on the
  web, the `cookieFallback` the client keeps when the browser blocks Appwrite's cookies), or a JWT
  or session set on the client. Background delivery reconnects with it, so prefer a session over a
  short-lived JWT.
- The broker address defaults to `push.<your API host>` over TLS (port 8883; on the web, a secure
  WebSocket). Override it with `client.setPushEndpoint('mqtts://push.example.com')`.
- Leave `setPushClientId` unset: the SDK derives a stable id, which lets the broker replay what
  was missed.

## 3. Subscribe

```dart
// The signed-in user's own topic, users/<userId>: what createPush(users: ...) reaches.
// Background delivery is on by default.
final sub = await push.subscribe(null, (message) {
  final body = jsonDecode(message.data) as Map<String, dynamic>;
  print('${body['notification']?['title']} ${body['data']}');
});

// Or Messaging topics, with options.
final news = await push.subscribe(
  ['news'],
  onNews,
  background: true,           // notify, and keep delivering when backgrounded or closed (Android)
  title: 'News',              // fallback notification title
  retry: true,                // QoS 1: replay what was missed while offline (default)
  notifyInForeground: false,  // also notify while the app is on screen
);

news.update(notifyInForeground: true); // change options live
news.unsubscribe();
```

`subscribe` completes once the broker has acknowledged the subscription. Each `PushMessage` has
`topic`, `data` (the payload as text), `payload` (bytes) and `qos`.

Connection events:

```dart
push
    .onOpen(() => print('connected'))
    .onClose(() => print('disconnected'))
    .onError((e) => print('error: $e'));
```

## 4. Notifications

- A background subscription posts a notification for each message while the app is not on
  screen, with the `title`, `body` and `image` sent with `createPush` (falling back to the
  subscription's `title`). On screen your callback shows the message, unless `notifyInForeground`
  is set.
- Android 13+: the first background subscription asks for the notification permission. If the
  user declines, messages still reach your callback but no notification is posted.
- Android notification icon:
  `<meta-data android:name="io.appwrite.push.notification_icon" android:resource="@drawable/..." />`
  in your `<application>`; otherwise a generic icon is used.

## 5. Taps

```dart
// The tap that launched the app (reported once): call it at startup.
final opened = await push.getInitialNotification(); // PushNotificationOpened?
if (opened != null) openSale(opened.data['saleId']);

// Taps while the app is running, including in the background.
final stop = push.onNotificationOpened((opened) => openSale(opened.data['saleId']));
stop(); // stop listening
```

`data` is the `data` sent with `createPush` (empty when there was none). On Android the native
plugin reports taps, and a tap made while nothing listens is kept for `getInitialNotification()`.
On iOS taps come from `flutter_local_notifications`. On the web, a click on a notification the page
showed reaches `onNotificationOpened` while the page is open, and `getInitialNotification()` is
always null.

## 6. Delivery while the app is closed (Android)

The native plugin saves background subscriptions and wakes the app on a schedule to reconnect; the
broker replays what was sent in between and a notification is posted.

| Device state | When a message arrives |
|---|---|
| Awake, exact alarms allowed | within about 60 s |
| Awake, no exact alarms | about every 15 s, but inexact (battery saver can defer it) |
| Doze (screen off, idle) | about every 9 min, even with exact alarms |
| `setForeground(true)` | immediately, also in Doze |
| Force-stopped | nothing until the app is opened again (then replayed) |

Punctual wake-ups: declare the permissions in `android/app/src/main/AndroidManifest.xml` (both
optional; `SCHEDULE_EXACT_ALARM` needs a Google Play declaration), and on Android 13+ the user
allows exact alarms under Settings > Apps > Special app access > Alarms & reminders.

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

```dart
final status = await push.backgroundStatus(); // null outside Android
if (status?.bestEffort == true) {
  // explain why, then from a button press:
  await push.requestExactAlarms();                // false when there is nothing to ask
  await push.requestIgnoreBatteryOptimizations(); // false when there is nothing to ask
}
```

Immediate delivery: `await push.setForeground(true)` runs a foreground service with a quiet
ongoing notification. Call it while the app is on screen; it is saved across restarts. It uses a
`remoteMessaging` foreground service, which Google Play asks you to declare.

## 7. iOS and the web

- iOS: a background subscription moves the connection to a background isolate, which posts local
  notifications. iOS suspends a backgrounded app within seconds, so delivery stops until the app
  is opened again; the broker then replays what was missed.
- Web: messages arrive while the page is open. Background subscriptions show browser
  notifications once the user allows them.

## 8. Sign-out

```dart
push.close(); // closes the connection and stops background delivery, saved subscriptions included
await Account(client).deleteSession(sessionId: 'current');
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Build fails on `minSdk` or desugaring | Add the Android settings from step 1 |
| `subscribe()` throws "needs a signed-in user" | Not signed in through this client, and no JWT or session set on it |
| Works open, nothing when closed (Android) | Notification permission declined, app force-stopped, Doze, or exact alarms not allowed (`backgroundStatus().bestEffort`) |
| Messages sent while offline never arrive | A random `setPushClientId`, or `retry: false` |
| No notification while the app is open | Expected; set `notifyInForeground: true` |
