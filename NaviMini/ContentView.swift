import SwiftUI

struct ContentView: View {
  @StateObject private var session = SessionStore.shared
  @StateObject private var playback = PlaybackController.shared

  var body: some View {
    NavigationStack {
      if session.isLoggedIn {
        LibraryView(session: session, playback: playback)
      } else {
        LoginView(session: session)
      }
    }
  }
}
