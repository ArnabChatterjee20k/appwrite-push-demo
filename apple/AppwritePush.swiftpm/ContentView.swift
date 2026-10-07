import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PushModel

    var body: some View {
        NavigationStack {
            List(model.lines, id: \.self) { line in
                Text(line).font(.system(.footnote, design: .monospaced))
            }
            .navigationTitle("Appwrite Push")
            .toolbar {
                Button("Sign out") {
                    Task { await model.signOut() }
                }
            }
        }
    }
}
