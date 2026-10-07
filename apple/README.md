# Appwrite Push on Apple platforms

A one-screen SwiftUI app that signs in, subscribes to the signed-in user's own topic and logs
connection changes, messages and notification taps. This README is the full guide to Push in
`sdk-for-apple`. The server side (provider, `createPush`) is in the
[root README](../README.md#server-provider-and-sending).

## Run this app

1. Fill in `AppwritePush.swiftpm/Config.swift` (endpoint, project, email and password).
2. Open `AppwritePush.swiftpm` in Xcode (or Swift Playgrounds) and run it on an iPhone or the
   simulator.

Send a push to the user's id and watch it arrive in the app's log, or as a notification right
after you leave the app.

## 1. Install

Add the package in Xcode (File > Add Package Dependencies) or in `Package.swift`:

```swift
.package(url: "https://github.com/appwrite/sdk-for-apple", from: "<version>")
```

and depend on its `Appwrite` product. The `Appwrite` module has its own `App` type, so write
`SwiftUI.App` for your app struct.

## 2. Client and sign-in

```swift
let client = Client().setEndpoint(endpoint).setProject(project)
_ = try await Account(client).createEmailPasswordSession(email: email, password: password)

let push = Push(client)
```

- `Push` uses the session the app signed in with through this client (the cookies it saved), or a
  JWT or session set on it (`setJWT`, `setSession`).
- The broker address defaults to `push.<your API host>` over TLS (port 8883). Override it with
  `client.setPushEndpoint("mqtts://push.example.com")`.
- Leave `setPushClientId` unset: the SDK derives a stable id, which lets the broker replay what
  was missed.

## 3. Subscribe

```swift
// The signed-in user's own topic, users/<userId>: what createPush(users:) reaches.
// Background delivery is on by default.
let sub = try await push.subscribe { message in
    print(message.data)
}

// Or Messaging topics, with options.
let news = try await push.subscribe(
    ["news"],
    background: true, // post a local notification per message
    title: "News",    // fallback notification title
    retry: true       // QoS 1: replay what was missed while offline (default)
) { message in
    onNews(message)
}

news.update(background: false) // change options live
news.unsubscribe()
```

`subscribe` returns once the broker has acknowledged the subscription. Each `PushMessage` has
`topic`, `data` (the payload as text), `payload` (bytes) and `qos`.

Connection events:

```swift
push
    .onOpen { print("connected") }
    .onClose { print("disconnected") }
    .onError { error in print("error: \(error)") }
```

## 4. Notifications

- The first background subscription asks the user for notification permission.
- A background subscription posts a local notification for each message, with the `title`,
  `body` and `image` sent with `createPush` (falling back to the subscription's `title`).
- iOS suspends a backgrounded app within seconds and never lets it wake itself, so delivery stops
  until the app is opened again; the broker then replays what was missed (with `retry`).

| App state | Delivery |
|---|---|
| On screen | callback |
| Just backgrounded, until iOS suspends it | callback and a local notification |
| Suspended or killed | nothing |
| Opened again | the broker replays what was missed |

## 5. Taps

Create `Push` while the app launches (e.g. in your `App`'s state, as this app does): the first
`Push` becomes the notification center's delegate, and the tap that launched the app arrives just
after launch.

```swift
// Taps while the app runs, including the one that launched it.
let stop = push.onNotificationOpened { opened in
    openSale(opened.data["saleId"] as? String)
}

// A tap made while nothing listened, reported once.
if let opened = push.getInitialNotification() {
    openSale(opened.data["saleId"] as? String)
}
stop() // stop listening
```

`data` is the `data` sent with `createPush` (empty when there was none). `Push` forwards every
other notification-center delegate call to the delegate the app had set. If the app sets its own
delegate after creating `Push`, pass responses on:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    if !Push.handleNotificationResponse(response) {
        // the app's own handling
    }
    completionHandler()
}
```

## 6. Sign-out

```swift
push.close()
_ = try await Account(client).deleteSession(sessionId: "current")
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `'App' is ambiguous` | Write `SwiftUI.App`: the `Appwrite` module also has an `App` type |
| `subscribe()` throws "needs a signed-in user" | Not signed in through this client, and no JWT or session set on it |
| No notification | Permission declined, or the app was already suspended |
| Tap not reported | `Push` was created after launch, or the app replaced the notification delegate without forwarding to `Push.handleNotificationResponse` |
| Messages sent while offline never arrive | A random `setPushClientId`, or `retry: false` |
