import SwiftUI

struct LoginView: View {
  @ObservedObject var session: SessionStore

  @State private var isLoading = false
  @State private var errorText: String?

  var body: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("连接到你的 Navidrome 资料库")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)

      Form {
        Section("服务器") {
          TextField("服务器地址，例如 https://your-domain.example.com/rest", text: $session.baseURLString)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }

        Section("帐户") {
          TextField("用户名", text: $session.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          SecureField("密码", text: $session.password)
        }

        if let errorText {
          Section {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
              Text(errorText)
                .font(.footnote)
                .foregroundStyle(.red)
            }
          }
        }

        Section {
          Button(action: { Task { await login() } }) {
            HStack {
              Spacer()
              if isLoading {
                ProgressView()
                  .progressViewStyle(.circular)
              }
              Text("登录")
                .fontWeight(.semibold)
              Spacer()
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(isLoading)
        }
      }
      .formStyle(.grouped)
    }
    .navigationTitle("连接资料库")
  }

  @MainActor
  private func login() async {
    isLoading = true
    errorText = nil

    defer { isLoading = false }

    do {
      let client = try session.makeClient()
      let ok = try await client.ping()
      guard ok else {
        errorText = "无法连接服务器，请检查地址、用户名和密码。"
        return
      }

      session.persist()
      session.isLoggedIn = true
    } catch {
      // 简单的错误归类，避免直接抛系统文案
      let msg = error.localizedDescription
      if msg.contains("App Transport Security") {
        errorText = "无法建立安全连接，请确认服务器使用 HTTPS。"
      } else {
        errorText = msg
      }
    }
  }
}
