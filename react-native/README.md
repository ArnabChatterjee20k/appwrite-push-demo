# Appwrite Push in React Native

A one-screen Expo app that signs in, subscribes to the signed-in user's own topic and logs
connection changes, messages and notification taps. This README is the full guide to Push in
`react-native-appwrite`. The server side (provider, `createPush`) is in the
[root README](../README.md#server-provider-and-sending).

## Run this app

```bash
cp .env.example .env.local   # fill in endpoint, project, email and password
npm install
npx expo run:android         # or: npx expo run:ios
```

Push needs native modules, so use a development or standalone build: it does not run in Expo Go.
On Android, use the buttons to allow exact alarms and the battery exemption, and **Check
background status** to see what background delivery can rely on.

This app runs on Expo 57, and `react-native-appwrite` 1.2.0-rc.4 depends on `expo-file-system` 18,
whose native module does not load in an Expo 57 app. `package.json` therefore overrides it to the
app's own `expo-file-system` (`"overrides": { "react-native-appwrite": { "expo-file-system": "$expo-file-system" } }`).
Push does not use it.
Send a push to the user's id and watch it arrive in the app's log, or as a notification while the
app is in the background or closed.

## 1. Install

```bash
npx expo install react-native-appwrite react-native-url-polyfill react-native-tcp-socket
# iOS notifications and taps:
npx expo install expo-notifications react-native-background-actions
```

- Import the URL polyfill once, before the SDK: `import 'react-native-url-polyfill/auto';`.
- On Expo SDK 52 and older, enable package exports in `metro.config.js`:
  `config.resolver.unstable_enablePackageExports = true;`.
- There is no config plugin: if you used an earlier release candidate, remove
  `"react-native-appwrite"` from `plugins` in `app.json`.

## 2. Client and sign-in

```ts
import { Account, Client, Push } from 'react-native-appwrite';

const client = new Client().setEndpoint(ENDPOINT).setProject(PROJECT);
await new Account(client).createEmailPasswordSession({ email, password });

const push = new Push(client);
```

- `Push` uses the session the app signed in with (read from the device's cookie store), or a JWT
  or session set on the client. Background delivery reconnects with it, and on Android it follows
  a rotated session on its own, so prefer a session over a short-lived JWT.
- The broker address defaults to `push.<your API host>` over TLS (port 8883). Override it with
  `client.setPushEndpoint('mqtts://push.example.com')`.
- Leave `setPushClientId` unset: the SDK derives a stable id per user and install, which lets the
  broker replay what was missed. A random id per launch loses the backlog.

## 3. Subscribe

```ts
// The signed-in user's own topic, users/<userId>: what createPush({ users }) reaches.
// Background delivery is on by default.
const sub = await push.subscribe((message) => {
  const { notification, data } = JSON.parse(message.data);
  console.log(notification?.title, data);
});

// Or Messaging topics, with options.
const news = await push.subscribe(['news'], onNews, {
  background: true,          // notify, and keep delivering when backgrounded or closed (Android)
  title: 'News',             // fallback notification title
  retry: true,               // QoS 1: replay what was missed while offline (default)
  notifyInForeground: false, // also notify while the app is on screen
});

news.update({ notifyInForeground: true }); // change options live
news.unsubscribe();
```

`subscribe` resolves once the broker has acknowledged the subscription. Each message has `topic`,
`data` (the payload as text), `payload` (bytes) and `qos`.

Connection events:

```ts
push
  .onOpen(() => console.log('connected'))
  .onClose(() => console.log('disconnected'))
  .onError((error) => console.warn(error.message));
```

## 4. Notifications

- A background subscription posts a notification for each message while the app is not on
  screen, with the `title`, `body` and `image` sent with `createPush` (falling back to the
  subscription's `title`). On screen your callback shows the message, unless `notifyInForeground`
  is set.
- Android 13+: the first background subscription asks for the notification permission. If the
  user declines, messages still reach your callback but no notification is posted.
- Android notification icon: add
  `<meta-data android:name="io.appwrite.push.notification_icon" android:resource="@drawable/ic_notification" />`
  to your `<application>` (through a config plugin of your own); otherwise a generic icon is used.

## 5. Taps

```ts
// The tap that launched the app (reported once): call it at startup.
const opened = await push.getInitialNotification(); // { topic, data } | null
if (opened) openSale(opened.data.saleId);

// Taps while the app is running, including in the background.
const stop = push.onNotificationOpened(({ topic, data }) => openSale(data.saleId));
stop(); // stop listening
```

`data` is the `data` sent with `createPush` (`{}` when there was none). A tap made while nothing
listens is kept for `getInitialNotification()`. On Android the SDK reports taps itself; on iOS they
come from `expo-notifications`.

## 6. Delivery while the app is closed (Android)

The SDK saves background subscriptions and wakes the app on a schedule to reconnect; the broker
replays what was sent in between and a notification is posted.

| Device state | When a message arrives |
|---|---|
| Awake, exact alarms allowed | within about 60 s |
| Awake, no exact alarms | about every 15 s, but inexact (battery saver can defer it) |
| Doze (screen off, idle) | about every 9 min, even with exact alarms |
| `setForeground(true)` | immediately, also in Doze |
| Force-stopped | nothing until the app is opened again (then replayed) |

Punctual wake-ups: declare the permissions in `app.json` (both optional; `SCHEDULE_EXACT_ALARM`
needs a Google Play declaration), and on Android 13+ the user allows exact alarms under
Settings > Apps > Special app access > Alarms & reminders.

```json
{ "expo": { "android": { "permissions": [
  "android.permission.SCHEDULE_EXACT_ALARM",
  "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
] } } }
```

```ts
const status = await push.backgroundStatus();
// { exactAlarms, ignoringBatteryOptimizations, foregroundService, bestEffort } | null (not Android)
if (status?.bestEffort) {
  // explain why, then from a button press:
  await push.requestExactAlarms();                // false when there is nothing to ask
  await push.requestIgnoreBatteryOptimizations(); // false when there is nothing to ask
}
```

Immediate delivery: `await push.setForeground(true)` runs a foreground service with a quiet
ongoing notification. Call it while the app is on screen; it is saved across restarts. It uses a
`remoteMessaging` foreground service, which Google Play asks you to declare.

## 7. iOS

iOS suspends a backgrounded app within seconds and never lets it wake itself:

| App state | Delivery |
|---|---|
| On screen | callback |
| Just backgrounded, until iOS suspends it | callback and a local notification |
| Suspended or killed | nothing |
| Opened again | the broker replays what was missed |

## 8. Sign-out

```ts
push.close(); // closes the connection and stops background delivery, saved subscriptions included
await new Account(client).deleteSession({ sessionId: 'current' });
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| "background delivery needs the SDK's native Android module" | Running in Expo Go, or the app was not rebuilt after installing |
| `subscribe()` throws "needs a signed-in user" | Not signed in through this client, and no JWT or session set on it |
| Works open, nothing when closed (Android) | Notification permission declined, app force-stopped, Doze, or exact alarms not allowed (`backgroundStatus().bestEffort`) |
| Messages sent while offline never arrive | A random `setPushClientId` per launch, or `retry: false` |
| No notification while the app is open | Expected; set `notifyInForeground: true` |
