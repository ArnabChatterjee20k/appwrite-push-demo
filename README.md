# Appwrite Push usage

Small apps that use Appwrite Push end to end, one per client SDK:

| Folder | SDK | Platforms |
|---|---|---|
| [`react-native/`](react-native/README.md) | `react-native-appwrite` | Android, iOS (Expo) |
| [`flutter/`](flutter/README.md) | `appwrite` (pub.dev) | Android, iOS, web |
| [`android/`](android/README.md) | `io.appwrite:sdk-for-android` | Android |
| [`apple/`](apple/README.md) | `sdk-for-apple` | iOS |

Each app does the same thing on one screen: sign in, subscribe to the signed-in user's own topic,
log connection changes, messages and notification taps, and sign out. On Android it also shows
what background delivery can rely on, with buttons to allow exact alarms and the battery
exemption. Each README is the full
guide to Push in that SDK.

> The apps use release candidates: `react-native-appwrite` 1.2.0-rc.4, `appwrite` (Flutter)
> 27.1.0-rc.7, `sdk-for-android` 29.1.0-rc.3 (from JitPack) and `sdk-for-apple` 20.1.0-rc.3.

## How Push works

Appwrite Push delivers messages over MQTT, without FCM or APNs. Your server sends a push through
Appwrite Messaging; the app subscribes with the SDK's `Push` service and receives each message in
a callback while it runs. A subscription with background delivery also posts a notification for
each message while the app is not on screen, and on Android keeps receiving after the app is
closed.

```
server (createPush) ──► Appwrite ──► MQTT broker ──► Push in the app ──► your callback
                                                          └──► notification (background)
```

## Server: provider and sending

Create the Appwrite Push provider once per project (console, CLI or a server SDK). `qos: 1` keeps
messages for clients that are offline and replays them when they reconnect; `expiry` is how long,
in seconds (at most 7 days).

```ts
import { Client, ID, Messaging } from 'node-appwrite';

const messaging = new Messaging(
  new Client().setEndpoint(ENDPOINT).setProject(PROJECT).setKey(API_KEY),
);

await messaging.createAppwriteProvider({
  providerId: 'appwrite-push',
  name: 'Appwrite Push',
  enabled: true,
  qos: 1,
  expiry: 604800,
});
```

Send to users (each user's own `users/<userId>` topic) or to Messaging topics:

```ts
await messaging.createPush({
  messageId: ID.unique(),
  users: ['<userId>'],           // or topics: ['<topicId>']
  title: 'Flash sale',
  body: '30% off: 3 new items',
  image: '<bucketId>:<fileId>',  // optional, an image in Appwrite Storage
  data: { saleId: '42' },        // your own key-values, e.g. for opening a screen on tap
});
```

The app receives the message as JSON:

```json
{
  "messageId": "6ac5…",
  "notification": { "title": "Flash sale", "body": "30% off: 3 new items", "image": "https://…" },
  "data": { "saleId": "42" }
}
```

## Concepts shared by every SDK

- **Sign-in.** `Push` uses the client's credential: a JWT or session set on it, else the session
  the app signed in with through it (e.g. `Account.createEmailPasswordSession`). Background
  delivery reconnects with it, so prefer a session over a short-lived JWT.
- **Topics.** `subscribe` without a topic subscribes to the signed-in user's own topic,
  `users/<userId>`, which `createPush({ users })` reaches. It defaults to background delivery.
  Pass topics to subscribe to Messaging topics instead.
- **Replay.** `retry` (on by default) subscribes at QoS 1: the broker keeps what was sent while
  the app was offline and replays it when it reconnects. Keep the client id stable (the default)
  so the broker recognises the app.
- **Notifications.** A background subscription posts a notification per message while the app is
  not on screen, with the `title`, `body` and `image` sent with `createPush`. While the app is on
  screen your callback shows the message, unless `notifyInForeground` is set.
- **Taps.** `getInitialNotification()` returns the tap that launched the app (once);
  `onNotificationOpened(callback)` reports later taps and returns a function that stops listening.
  Both give `{ topic, data }`, where `data` is the `data` sent with `createPush`.
- **Sign-out.** `push.close()` closes the connection and stops background delivery.

## Configure the apps

Each app reads the endpoint, project id and a user's email and password from one config file
(see its README). Create that user in the console, and send pushes to its user id.
