import SwiftUI

struct ContentView: View {
  @StateObject private var session = SessionStore.shared
  @StateObject private var playback = PlaybackController.shared

  var body: some View {
    NavigationStack {
      LibraryView(session: session, playback: playback)
    }
  }
}
