import SwiftUI

// MARK: - Built-in molecule catalog

struct BuiltInMolecule: Identifiable {
    let id = UUID()
    let name: String
    let ext: String
    var displayName: String { name }
}

let builtInMolecules: [BuiltInMolecule] = [
    BuiltInMolecule(name: "Caffeine",           ext: "pdb"),
    BuiltInMolecule(name: "DNA",                ext: "pdb"),
    BuiltInMolecule(name: "Insulin",            ext: "pdb"),
    BuiltInMolecule(name: "Nanotube",           ext: "pdb"),
    BuiltInMolecule(name: "TransferRNA",        ext: "pdb"),
    BuiltInMolecule(name: "TheoreticalBearing", ext: "pdb"),
    BuiltInMolecule(name: "Buckminsterfullerene", ext: "sdf"),
    BuiltInMolecule(name: "Heme",               ext: "sdf"),
]

// MARK: - Molecule Attachment View

struct MoleculeAttachmentView: View {
    let objectId: String
    let moleculeName: String
    var onMoleculeChanged: ((String) -> Void)?
    var onRemove: (() -> Void)?

    @State private var molecule: (any MolecularStructure)?
    @State private var autorotate = true
    @State private var visualizationStyle = MoleculeVisualizationStyle.spacefilling
    @State private var showingPicker = false
    @State private var showingPDBEntry = false
    @State private var pdbIDInput = ""
    @State private var pdbFetchError: String?
    @State private var isFetchingPDB = false
    @State private var loadError = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            rendererBody
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .task(id: moleculeName) { loadMolecule(moleculeName) }
        .sheet(isPresented: $showingPicker) { pickerSheet }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "atom")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Molecule")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("— \(displayMoleculeName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                visualizationStyle = visualizationStyle.next()
            } label: {
                Image(systemName: styleIconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Visualization: \(visualizationStyle.displayName)")
            Button {
                showingPicker = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Molecule")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Renderer

    @ViewBuilder
    private var rendererBody: some View {
        if let mol = molecule {
            ZStack(alignment: .bottomLeading) {
                RealityKitMoleculeView(
                    molecule: mol,
                    autorotate: $autorotate,
                    visualizationStyle: $visualizationStyle
                )
                .frame(height: 280)
                .clipped()

                Button {
                    autorotate.toggle()
                } label: {
                    Image(systemName: autorotate
                          ? "arrow.uturn.backward.circle.fill"
                          : "arrow.uturn.backward.circle")
                        .imageScale(.large)
                        .foregroundColor(.accentColor)
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
        } else if loadError {
            Text("Could not load \"\(displayMoleculeName)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                if isFetchingPDB {
                    Text("Fetching \(displayMoleculeName) from RCSB…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
        }
    }

    private var displayMoleculeName: String {
        if moleculeName.hasPrefix(Self.pdbPrefix) {
            return "PDB " + moleculeName.dropFirst(Self.pdbPrefix.count)
        }
        return moleculeName
    }

    // MARK: Picker sheet

    private var pickerSheet: some View {
        NavigationStack {
            List {
                Section("Built-in") {
                    ForEach(builtInMolecules) { item in
                        Button {
                            onMoleculeChanged?(item.name)
                            showingPicker = false
                        } label: {
                            HStack {
                                Text(item.displayName)
                                    .foregroundStyle(item.name == moleculeName ? Color.accentColor : .primary)
                                Spacer()
                                if item.name == moleculeName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                Section("Protein Data Bank") {
                    Button {
                        pdbIDInput = ""
                        pdbFetchError = nil
                        showingPDBEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text("Load from PDB ID…")
                        }
                    }
                }
            }
            .navigationTitle("Choose Molecule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPicker = false }
                }
            }
            .alert("Load from PDB", isPresented: $showingPDBEntry) {
                TextField("4-character ID (e.g. 1HHO)", text: $pdbIDInput)
                    .disableAutocorrection(true)
                Button("Load") { submitPDBID() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let err = pdbFetchError {
                    Text(err)
                } else {
                    Text("Enter a 4-character RCSB Protein Data Bank identifier.")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitPDBID() {
        guard let normalized = RCSBService.normalize(pdbIDInput) else {
            pdbFetchError = "Invalid PDB ID. IDs are 4 alphanumeric characters."
            showingPDBEntry = true
            return
        }
        onMoleculeChanged?(Self.pdbPrefix + normalized)
        showingPicker = false
    }

    // MARK: Helpers

    private var cardBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    static let pdbPrefix = "pdb:"

    private var styleIconName: String {
        switch visualizationStyle {
        case .spacefilling: return "circle.fill"
        case .ballAndStick: return "atom"
        case .electronCloud: return "circle.dotted"
        }
    }

    private func loadMolecule(_ name: String) {
        loadTask?.cancel()
        molecule = nil
        loadError = false
        isFetchingPDB = false

        if name.hasPrefix(Self.pdbPrefix) {
            let id = String(name.dropFirst(Self.pdbPrefix.count))
            loadTask = Task { await loadFromRCSB(id: id) }
            return
        }

        if let mol = loadFromBundle(name: name, ext: "pdb", make: { try PDBFile(data: $0) }) {
            molecule = mol
        } else if let mol = loadFromBundle(name: name, ext: "sdf", make: { try SDFFile(data: $0) }) {
            molecule = mol
        } else if let mol = loadFromBundle(name: name, ext: "xyz", make: { try XYZFile(data: $0) }) {
            molecule = mol
        } else {
            loadError = true
        }
    }

    @MainActor
    private func loadFromRCSB(id: String) async {
        isFetchingPDB = true
        defer { isFetchingPDB = false }
        do {
            let data = try await RCSBService.shared.fetch(id: id)
            if Task.isCancelled { return }
            let mol = try PDBFile(data: data)
            molecule = mol
        } catch {
            if !Task.isCancelled {
                loadError = true
            }
        }
    }

    private func loadFromBundle(name: String, ext: String, make: (Data) throws -> any MolecularStructure) -> (any MolecularStructure)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url),
              let mol = try? make(data) else { return nil }
        return mol
    }
}
