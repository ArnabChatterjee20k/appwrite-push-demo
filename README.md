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
