import SwiftUI
import AVFoundation

/// Udambu for iPhone: a native shell around the bundled web app.
/// The web app recognises this shell (its user agent contains "Udambu-iOS") and switches to its iPhone look.
@main
struct UdambuApp: App {
    init() {
        // The read-aloud voice plays even when the ring/silent switch is on, like any media app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
