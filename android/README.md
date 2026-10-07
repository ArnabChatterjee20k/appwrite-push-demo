# Appwrite Push on Android

A one-screen Kotlin app that signs in, subscribes to the signed-in user's own topic and logs
connection changes, messages and notification taps. This README is the full guide to Push in
`io.appwrite:sdk-for-android`. The server side (provider, `createPush`) is in the
[root README](../README.md#server-provider-and-sending).

## Run this app

1. Fill in `app/src/main/java/io/appwrite/pushusage/Config.kt` (endpoint, project, email and
   password).
2. `./gradlew :app:installDebug` with a device or emulator connected, or open the folder in
   Android Studio and run `app`.

Send a push to the user's id and watch it arrive in the app's log, or as a notification while the
app is in the background or closed. Use the buttons to allow exact alarms and the battery
exemption, and **Check background status** to see what background delivery can rely on; the
manifest declares both permissions.

## 1. Install

```kotlin
dependencies {
    implementation("io.appwrite:sdk-for-android:<version>")
}
```

Release candidates are published on JitPack instead of Maven Central, as this app uses them:
add `maven { url = uri("https://jitpack.io") }` to your repositories and depend on
`com.github.appwrite:sdk-for-android:<version>`.

The SDK needs Android 7.0 (API 24) or later. Its manifest declares everything background delivery
needs (services, receivers, the boot receiver and their permissions).

## 2. Client and sign-in

```kotlin
val client = Client(context).setEndpoint(ENDPOINT).setProject(PROJECT)
Account(client).createEmailPasswordSession(email, password)

val push = Push(client, activity) // or any Context; an Activity lets Push ask for permissions
```

- `Push` uses the session the app signed in with through this client (its cookie store), or a JWT
  or session set on it (`setJWT`, `setSession`). Background delivery reconnects with it, so prefer
  a session over a short-lived JWT.
- The broker address defaults to `push.<your API host>` over TLS (port 8883). Override it with
  `client.setPushEndpoint("mqtts://push.example.com")`.
- Leave `setPushClientId` unset: the SDK derives a stable id per user and install, which lets the
  broker replay what was missed.

## 3. Notification permission

Android 13+ needs the `POST_NOTIFICATIONS` runtime permission to show background notifications.
The first background subscription asks for it, from the visible activity: the one `Push` was
created with, else the next one to resume. To ask at a moment of your choosing instead, call this
from an `Activity`:

```kotlin
Push.requestNotificationPermission(activity)
```

If the user declines, messages still reach your callback but no notification is posted.

## 4. Subscribe

`subscribe` blocks until the broker acknowledges the subscription, so call it off the main thread.

```kotlin
// The signed-in user's own topic, users/<userId>: what createPush(users = ...) reaches.
// Background delivery is on by default.
val sub = push.subscribe { message ->
    Log.d("push", message.data)
}

// Or Messaging topics, with options.
val news = push.subscribe(
    listOf("news"),
    background = true,          // notify, and keep delivering when backgrounded or closed
    title = "News",             // fallback notification title
    retry = true,               // QoS 1: replay what was missed while offline (default)
    notifyInForeground = false, // also notify while the app is on screen
) { message -> onNews(message) }

news.update(notifyInForeground = true) // change options live
news.unsubscribe()
```

Each `PushMessage` has `topic`, `data` (the payload as text), `payload` (bytes) and `qos`.

Connection events:

```kotlin
push
    .onOpen { Log.d("push", "connected") }
    .onClose { Log.d("push", "disconnected") }
    .onError { Log.w("push", it.message ?: "") }
```

## 5. Notifications

- A background subscription posts a notification for each message while the app is not on
  screen, with the `title`, `body` and `image` sent with `createPush` (falling back to the
  subscription's `title`). On screen your callback shows the message, unless `notifyInForeground`
  is set.
- Notification icon: `<meta-data android:name="io.appwrite.push.notification_icon" android:resource="@drawable/ic_notification" />`
  in your `<application>`; otherwise a generic icon is used.
- Handle messages in code while no callback is live (e.g. after the app was started in the
  background): subclass `PushReceiver` and declare it in your manifest with the
  `io.appwrite.push.MESSAGE` action. Return true from `onMessage` when you handled it, so no
  notification is posted.

## 6. Taps

```kotlin
// The tap that launched the app (reported once): call it at startup.
push.getInitialNotification()?.let { openSale(it.data["saleId"]) }

// Taps while the app is running (on the main thread), including in the background.
val stop = push.onNotificationOpened { opened -> openSale(opened.data["saleId"]) }
stop() // stop listening
```

`data` is the `data` sent with `createPush`, parsed (empty when there was none). A tap made while
nothing listens is kept for `getInitialNotification()`. The intent that opens your app also carries
`Push.EXTRA_TOPIC` and `Push.EXTRA_PAYLOAD`.

## 7. Delivery while the app is closed

The SDK saves background subscriptions and wakes the app on a schedule to reconnect; the broker
replays what was sent in between and a notification is posted.

| Device state | When a message arrives |
|---|---|
| Awake, exact alarms allowed | within about 60 s |
| Awake, no exact alarms | about every 15 s, but inexact (battery saver can defer it) |
| Doze (screen off, idle) | about every 9 min, even with exact alarms |
| `setForeground(true)` | immediately, also in Doze |
| Force-stopped | nothing until the app is opened again (then replayed) |

Punctual wake-ups: declare the permissions in your manifest (both optional; `SCHEDULE_EXACT_ALARM`
needs a Google Play declaration), and on Android 13+ the user allows exact alarms under
Settings > Apps > Special app access > Alarms & reminders.

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

```kotlin
val status = Push.backgroundStatus(context)
if (status.bestEffort) {
    // explain why, then from a user action:
    Push.requestExactAlarms(context)                // false when there is nothing to ask
    Push.requestIgnoreBatteryOptimizations(context) // false when there is nothing to ask
}
```

Immediate delivery: `push.setForeground(true)` runs a foreground service with a quiet ongoing
notification. Call it while the app is on screen; it is saved across restarts. It uses a
`remoteMessaging` foreground service, which Google Play asks you to declare; apps that never enable
it can remove `io.appwrite.services.PushService` and
`android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING` with `tools:node="remove"`.

## 8. Sign-out

```kotlin
push.close() // closes the connection and stops background delivery, saved subscriptions included
Account(client).deleteSession("current")
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `NetworkOnMainThreadException` from `subscribe` | Call it off the main thread |
| `subscribe()` throws "needs a signed-in user" | Not signed in through this client, and no JWT or session set on it |
| Messages arrive but no notification | `POST_NOTIFICATIONS` declined, or the app is on screen |
| Nothing while the app is closed | App force-stopped, Doze, or exact alarms not allowed (`Push.backgroundStatus(context).bestEffort`) |
| Messages sent while offline never arrive | A random `setPushClientId`, or `retry = false` |
