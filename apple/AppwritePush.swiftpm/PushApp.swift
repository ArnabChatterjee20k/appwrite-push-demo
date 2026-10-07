import Appwrite
import SwiftUI

@main
struct PushApp: SwiftUI.App {
    // Created at launch, so Push receives the tap that launched the app.
    @StateObject private var model = PushModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}

@MainActor
final class PushModel: ObservableObject {
    @Published var lines: [String] = []

    private let client = Client().setEndpoint(endpoint).setProject(project)
    private lazy var account = Account(client)
    private lazy var push = Push(client)
    private var stopOpened: (() -> Void)?

    init() {
        stopOpened = push.onNotificationOpened { [weak self] opened in
            self?.log("notification opened: \(opened.data)")
        }
        push
            .onOpen { [weak self] in self?.log("connected") }
            .onClose { [weak self] in self?.log("disconnected") }
            .onError { [weak self] error in self?.log("error: \(error.localizedDescription)") }
        Task { await start() }
    }

    nonisolated private func log(_ line: String) {
        print("[push] \(line)")
        Task { @MainActor in self.lines.insert(line, at: 0) }
    }

    private func start() async {
        do {
            let user: AppwriteModels.User<[String: AnyCodable]>
            do {
                user = try await account.get()
            } catch {
                _ = try await account.createEmailPasswordSession(email: email, password: password)
                user = try await account.get()
            }
            log("signed in as \(user.id)")

            _ = try await push.subscribe { [weak self] message in
                self?.log("message: \(message.data)")
            }
            log("subscribed")

            if let opened = push.getInitialNotification() {
                log("launched from notification: \(opened.data)")
            }
        } catch {
            log("error: \(error.localizedDescription)")
        }
    }

    func signOut() async {
        push.close()
        _ = try? await account.deleteSession(sessionId: "current")
        log("signed out")
    }
}
