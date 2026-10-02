import SwiftUI

struct ChatView: View {
    let thread: Conversation
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var phase
    @StateObject private var chat = ChatStore()
    @State private var draft = ""
    @State private var saveDialog = false
    @State private var pageTitle = ""
    @State private var savedPage: Page?
    private var dotName: String { store.workspace?.dots.first(where: { $0.id == thread.dotId })?.name ?? "Dot" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if chat.messages.isEmpty && chat.loaded {
                            ContentUnavailableView("무슨 생각 중인가요?", systemImage: "sparkles", description: Text("\(dotName)에게 메시지를 보내보세요."))
                        }
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.role == "user" { Spacer(minLength: 36) }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message.role == "user" ? "나" : dotName).font(.caption.bold()).foregroundStyle(.secondary)
                                    Text(.init(message.content)).textSelection(.enabled)
                                }
                                .padding(14)
                                .background(message.role == "user" ? Color.indigo.opacity(0.12) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                if message.role != "user" { Spacer(minLength: 36) }
                            }.id(message.id)
                        }
                        if chat.running { HStack { ProgressView(); Text(chat.activity).font(.caption).foregroundStyle(.secondary) } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding()
                }
                .onChange(of: chat.messages) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            if let error = chat.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.horizontal).padding(.bottom, 8) }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("\(dotName)에게 메시지", text: $draft, axis: .vertical).lineLimit(1...6).padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                Button {
                    guard let client = store.client else { return }
                    if chat.running { Task { await chat.stop(client: client, thread: thread) } }
                    else {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty, text.count <= 4000 else { return }
                        chat.send(client: client, thread: thread, prompt: text); draft = ""
                    }
                } label: { Image(systemName: chat.running ? "stop.fill" : "arrow.up").font(.headline).frame(width: 42, height: 42).background(.indigo, in: Circle()).foregroundStyle(.white) }
                .disabled(!chat.running && (!chat.loaded || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 4000))
                .accessibilityLabel(chat.running ? "응답 중지" : "메시지 보내기")
            }.padding().background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        .environment(\.openURL, OpenURLAction { url in
            guard let client = store.client,
                  url.host == nil || url.host == client.baseURL.host,
                  let fragment = url.fragment else { return .systemAction }
            let parts = fragment.split(separator: "/").map(String.init)
            guard parts.count == 4, parts[0] == "spaces", parts[2] == "pages" else { return .systemAction }
            Task {
                do { savedPage = try await client.page(parts[1], parts[3]) }
                catch { chat.error = error.localizedDescription }
            }
            return .handled
        })
        .navigationTitle(dotName).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { pageTitle = thread.title; saveDialog = true } label: { Image(systemName: "doc.badge.plus") }.disabled(chat.running || chat.messages.isEmpty).accessibilityLabel("대화를 문서로 저장") }
        }
        .task { if let client = store.client { await chat.load(client: client, thread: thread) } }
        .onChange(of: chat.unsentPrompt) { _, value in if let value, draft.isEmpty { draft = value } }
        .onChange(of: phase) { _, value in
            if value == .active && !chat.running, let client = store.client { Task { await chat.load(client: client, thread: thread) } }
        }
        .onDisappear { if chat.running, let client = store.client { Task { await chat.stop(client: client, thread: thread) } } }
        .alert("대화를 문서로 저장", isPresented: $saveDialog) {
            TextField("문서 제목", text: $pageTitle)
            Button("취소", role: .cancel) {}
            Button("저장") {
                guard let client = store.client else { return }
                Task {
                    do { savedPage = try await client.saveConversation(thread.id, title: pageTitle); await store.reload() }
                    catch { chat.error = error.localizedDescription }
                }
            }
        }
        .sheet(item: $savedPage) { page in NavigationStack { PageView(page: page).environmentObject(store) } }
    }
}
