import SwiftUI

@main
struct OpenDotsApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).tint(.indigo) }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group {
            if store.workspace == nil {
                ConnectionView()
            } else {
                TabView {
                    ChatListView().tabItem { Label("대화", systemImage: "bubble.left.and.bubble.right") }
                    DocumentsView().tabItem { Label("문서", systemImage: "doc.text") }
                    ConnectionView().tabItem { Label("연결", systemImage: "link") }
                }
            }
        }
        .task { await store.reload() }
    }
}

struct DotAvatar: View {
    let name: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [.indigo.opacity(0.8), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "sparkles").font(.title2).foregroundStyle(.white)
        }.frame(width: 52, height: 52).accessibilityLabel(name)
    }
}

struct ConnectionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var address = ""
    @State private var token = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        DotAvatar(name: "OpenDots")
                        Text("내 Dot을 아이폰으로").font(.title2.bold())
                        Text("PC에서 실행 중인 OpenDots에 연결하면 대화와 문서를 여기에서 이어갈 수 있어요.").foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                Section("서버 연결") {
                    TextField("https://dots.example.com", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("서버 접속 토큰", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button { Task { _ = await store.connect(address: address, token: token) } } label: {
                        if store.connecting { ProgressView() } else { Text("연결 확인하고 저장") }
                    }.disabled(store.connecting || address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section {
                    Text("127.0.0.1은 아이폰 자신을 가리켜요. PC에 접근할 수 있는 HTTPS 주소를 입력해주세요. PC가 켜져 있어야 Codex가 작업합니다.").font(.footnote).foregroundStyle(.secondary)
                    if let detail = store.workspace?.setup.detail { Label(detail, systemImage: "checkmark.circle").font(.footnote) }
                    if let error = store.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("connectionError") }
                }
            }.navigationTitle("OpenDots")
        }
        .onAppear {
            address = store.server
            if let url = try? APIClient.validateURL(address) { token = TokenStore.read(server: url.absoluteString) }
        }
    }
}

struct ChatListView: View {
    @EnvironmentObject private var store: AppStore
    @State private var creating = false
    @State private var path: [Conversation] = []
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("새 대화") {
                    ForEach(store.workspace?.dots ?? []) { dot in
                        Button {
                            guard let client = store.client, !creating else { return }
                            creating = true
                            Task {
                                defer { creating = false }
                                do {
                                    let thread = try await client.conversation(dotId: dot.id, title: "아이폰에서 시작한 대화")
                                    await store.reload(); path.append(thread)
                                } catch { store.error = error.localizedDescription }
                            }
                        } label: {
                            HStack(spacing: 14) { DotAvatar(name: dot.name); VStack(alignment: .leading) { Text(dot.name).font(.headline); Text(dot.instructions).font(.caption).foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Image(systemName: "plus") }
                        }.disabled(creating)
                    }
                }
                Section("최근 대화") {
                    ForEach(store.workspace?.conversations ?? []) { thread in
                        NavigationLink(value: thread) {
                            Label { VStack(alignment: .leading, spacing: 4) { Text(thread.title); Text(store.workspace?.dots.first(where: { $0.id == thread.dotId })?.name ?? "Dot").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "bubble.left") }
                        }
                    }
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("내 Dots")
            .refreshable { await store.reload() }
            .navigationDestination(for: Conversation.self) { thread in ChatView(thread: thread) }
        }
    }
}
