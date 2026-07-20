//
//  DraftsView.swift
//  wordsmatter
//
//  Created by User451 on 9/8/25.
//

import SwiftUI

struct DraftsView: View {
    @State private var drafts: [Book] = []
    @State private var isLoading = false
    @State private var openDraft: Book?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if drafts.isEmpty {
                    emptyState
                } else {
                    draftReel
                }
            }
            .navigationTitle("Drafts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await createAndOpenNewDraft() }
                    } label: {
                        Label("New Draft", systemImage: "plus")
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .help("Reload")
                }
            }
            .task { await reload() }
            .navigationDestination(item: $openDraft) { book in
                DraftEditorView(book: book)
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No Drafts Yet")
                .font(.title2).bold()
            Text("Create a draft to get started.")
                .foregroundColor(.secondary)
            Button {
                Task { await createAndOpenNewDraft() }
            } label: {
                Label("New Draft", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Full-screen, snap-paged reel of drafts — one draft per screen.
    private var draftReel: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(drafts, id: \.id) { book in
                    DraftReelPage(
                        book: book,
                        onOpen: { openDraft = book },
                        onDelete: { Task { await deleteDraft(book) } }
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
    }

    // MARK: - Actions

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        if let list = try? await DraftsStore.shared.loadAllDrafts() {
            await MainActor.run { drafts = list }
        }
    }

    /// Creates a new draft and immediately opens it for editing
    private func createAndOpenNewDraft() async {
        isLoading = true
        defer { isLoading = false }

        if let book = try? await DraftsStore.shared.createNewDraft() {
            await reload()
            await MainActor.run {
                openDraft = book
            }
        }
    }

    private func deleteDraft(_ book: Book) async {
        isLoading = true
        defer { isLoading = false }
        try? await DraftsStore.shared.delete(id: book.id)
        await reload()
    }
}

// MARK: - Draft Reel Page

/// One full-screen draft page. Tap anywhere (or the actions) to open the editor.
private struct DraftReelPage: View {
    let book: Book
    let onOpen: () -> Void
    let onDelete: () -> Void

    private var title: String {
        book.title.isEmpty ? "Untitled Draft" : book.title
    }

    private var gradient: [Color] {
        let base = DraftReelPalette.colors[abs(book.id.hashValue) % DraftReelPalette.colors.count]
        return [base, base.opacity(0.55), .black.opacity(0.9)]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottom)
                .ignoresSafeArea()

            // Document hero.
            VStack {
                Spacer(minLength: 0)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 120, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 150)

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .lineLimit(4)
                    Text(book.did)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    Button(action: onOpen) {
                        Label("Open", systemImage: "arrow.up.right.square.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    DraftActionButton(icon: "square.and.pencil", label: "Edit", action: onOpen)
                    DraftActionButton(icon: "trash.fill", label: "Delete", tint: .red, action: onDelete)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

/// A TikTok-style vertical action button for the drafts reel.
private struct DraftActionButton: View {
    let icon: String
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private enum DraftReelPalette {
    static let colors: [Color] = [
        Color(red: 0.36, green: 0.42, blue: 0.78),
        Color(red: 0.78, green: 0.38, blue: 0.52),
        Color(red: 0.30, green: 0.58, blue: 0.55),
        Color(red: 0.66, green: 0.45, blue: 0.74),
        Color(red: 0.82, green: 0.52, blue: 0.32),
        Color(red: 0.32, green: 0.56, blue: 0.74)
    ]
}

#Preview {
    DraftsView()
}
