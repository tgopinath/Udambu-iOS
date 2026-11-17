import SwiftUI

struct ContentView: View {
    @State private var loading = true
    @State private var failed = false
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea().opacity(loading && !failed ? 1 : 0)

            // The web page draws edge to edge and handles the safe areas itself.
            AppWebView(url: AppWebView.home, loading: $loading, failed: $failed, reloadToken: reloadToken)
                .ignoresSafeArea()
                .opacity(loading || failed ? 0 : 1)

            if loading && !failed {
                Image("LaunchIcon")
                    .resizable().scaledToFit().frame(width: 120)
                    .accessibilityLabel("Udambu is loading")
            }

            if failed {
                ContentUnavailableView {
                    Label("Something went wrong", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Udambu could not open. Please try again.")
                } actions: {
                    Button("Try Again") {
                        failed = false
                        loading = true
                        reloadToken += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: loading)
    }
}

#Preview {
    ContentView()
}
