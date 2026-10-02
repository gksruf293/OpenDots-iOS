import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pages: [Page] = []
    @State private var spaceId = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Space", selection: $spaceId) { ForEach(store.workspace?.spaces ?? []) { space in Text(space.name).tag(space.id) } }
                }
                Section("문서") {
                    ForEach(pages) { page in NavigationLink { PageView(page: page) } label: { Label(page.title, systemImage: "doc.text") } }
                    if pages.isEmpty { Text("아직 저장한 문서가 없어요.").foregroundStyle(.secondary) }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("문서")
            .task {
                if spaceId.isEmpty { spaceId = store.workspace?.spaces.first?.id ?? "" }
                await load()
            }
            .onChange(of: spaceId) { _, _ in Task { await load() } }
            .refreshable { await load() }
        }
    }
    @MainActor private func load() async {
        guard let client = store.client, !spaceId.isEmpty else { return }
        let selected = spaceId
        do { let result = try await client.pages(selected); if spaceId == selected { pages = result; error = nil } }
        catch { if spaceId == selected { self.error = error.localizedDescription } }
    }
}

struct PageView: View {
    @EnvironmentObject private var store: AppStore
    @State var page: Page
    @State private var editing = false
    @State private var title = ""
    @State private var content = ""
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        Group {
            if editing {
                VStack {
                    TextField("제목", text: $title).font(.title2.bold()).padding(.horizontal)
                    TextEditor(text: $content).padding(.horizontal).accessibilityLabel("문서 Markdown 내용")
                    if let error { Text(error).font(.footnote).foregroundStyle(.red).padding() }
                }
            } else {
                ScrollView { VStack(alignment: .leading, spacing: 20) { Text(page.title).font(.largeTitle.bold()); Text(.init(page.content)).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading).padding() }
            }
        }
        .navigationTitle("문서").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !editing, let error { Text(error).font(.footnote).foregroundStyle(.red).padding().frame(maxWidth: .infinity).background(.bar) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "저장" : "편집") {
                    if !editing { title = page.title; content = page.content; editing = true; return }
                    guard let client = store.client, !saving else { return }
                    saving = true
                    Task {
                        defer { saving = false }
                        do { page = try await client.updatePage(page, title: title, content: content); editing = false; error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                }.disabled(saving || (editing && title.trimmingCharacters(in: .whitespaces).isEmpty))
            }
            if editing { ToolbarItem(placement: .topBarLeading) { Button("취소") { editing = false; error = nil }.disabled(saving) } }
        }
        .task {
            guard let client = store.client else { return }
            do { page = try await client.page(page.spaceId, page.id) }
            catch { self.error = error.localizedDescription }
        }
    }
}
