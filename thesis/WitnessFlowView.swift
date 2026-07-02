import SwiftUI
import Core451
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

struct WitnessStatementView: View {
    var title: String = "Witness Statement"
    @State private var witnessDescription: String = ""
#if canImport(UIKit)
    typealias PlatformImage = UIImage
#else
    // Fallback type to allow compilation on non-UIKit platforms
    struct PlatformImage: Hashable {}
#endif
    @State private var selectedImages: [PlatformImage] = []
    @State private var isShowingPhotoPicker: Bool = false
    @State private var isPublishing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppTopHeader()

            Text(title)
                .font(.title3).bold()

            Text("Describe what you witnessed:")
                .font(.headline)
                .padding(.top, 10)

            TextEditor(text: $witnessDescription)
                .frame(height: 150)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text("Add photos (optional):")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(selectedImages, id: \.self) { image in
#if canImport(UIKit)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
#else
                        // Placeholder on platforms without UIKit
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
#endif
                    }

                    Button(action: {
                        isShowingPhotoPicker = true
                    }) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            )
                    }
                }
                .padding(.vertical, 5)
            }

            Spacer()

            Button(action: {
                signAndPublishWitnessStatement()
            }) {
                if isPublishing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Submit Witness Statement")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(witnessDescription.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(witnessDescription.isEmpty || isPublishing)
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .background(Color.white)
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $isShowingPhotoPicker) {
#if canImport(PhotosUI) && canImport(UIKit)
            PhotoPicker(images: $selectedImages)
#else
            Text("Photo picking not available on this platform")
                .padding()
#endif
        }
#if os(iOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
#endif
    }

    private func signAndPublishWitnessStatement() {
        isPublishing = true
        // Simulate async publishing logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPublishing = false
            witnessDescription = ""
            selectedImages = []
            // Additional completion logic as needed
        }
    }
}

struct WitnessStatementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WitnessStatementView()
        }
    }
}

struct WitnessFlowView: View {
    @State private var showObjectsSheet = false
    @State private var showEventsSheet = false
    @State private var showNotarizeSheet = false
    @State private var showOralSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppTopHeader()

            Text("Witness Tools")
                .font(.title3).bold()
                .padding(.leading, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Choose a witness workflow to initiate:")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.leading, 20)

            VStack(spacing: 18) {
                GlassCardButton(title: "Objects Are Present", subtitle: "Capture photos or video to attest objects exist at a time/place", color: .blue) {
                    showObjectsSheet = true
                }
                .sheet(isPresented: $showObjectsSheet) {
                    NavigationStack {
                        WitnessStatementView(title: "Objects Are Present")
                            .navigationTitle("Objects Present")
#if canImport(UIKit)
                            .navigationBarTitleDisplayMode(.inline)
#endif
                            .padding()
                    }
                }

                GlassCardButton(title: "Witnessed Events", subtitle: "Describe events you witnessed; attach photos or video", color: .green) {
                    showEventsSheet = true
                }
                .sheet(isPresented: $showEventsSheet) {
                    NavigationStack {
                        WitnessStatementView(title: "Witnessed Events")
                            .navigationTitle("Witnessed Events")
#if canImport(UIKit)
                            .navigationBarTitleDisplayMode(.inline)
#endif
                            .padding()
                    }
                }

                GlassCardButton(title: "Notarize a Document", subtitle: "Reference a document by DID to notarize your witness", color: .orange) {
                    showNotarizeSheet = true
                }
                .sheet(isPresented: $showNotarizeSheet) {
                    NavigationStack {
                        NotarizeDocumentWitnessView()
                            .navigationTitle("Notarize Document")
#if canImport(UIKit)
                            .navigationBarTitleDisplayMode(.inline)
#endif
                            .padding()
                    }
                }

                GlassCardButton(title: "Oral Agreement / Wager", subtitle: "Record terms and parties; optional media attachments", color: .purple) {
                    showOralSheet = true
                }
                .sheet(isPresented: $showOralSheet) {
                    NavigationStack {
                        OralAgreementWitnessView()
                            .navigationTitle("Oral Agreement")
#if canImport(UIKit)
                            .navigationBarTitleDisplayMode(.inline)
#endif
                            .padding()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.white.ignoresSafeArea())
#if os(iOS) || os(watchOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }
}

struct NotarizeDocumentWitnessView: View {
    @State private var documentDID: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppTopHeader()

            Text("Notarize a Document")
                .font(.headline)
                .padding(.top, 10)

            Form {
                Section(header: Text("Document DID")) {
#if canImport(UIKit)
                    TextField("did:example:abc123...", text: $documentDID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
#else
                    TextField("did:example:abc123...", text: $documentDID)
#endif
                }
                Section(header: Text("Notes (optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
                Section {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Notarize Document")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(documentDID.isEmpty || isSubmitting)
                }
            }
        }
        .background(Color.white)
    }

    private func submit() {
        isSubmitting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            documentDID = ""
            notes = ""
        }
    }
}

struct OralAgreementWitnessView: View {
    @State private var partyA: String = ""
    @State private var partyB: String = ""
    @State private var terms: String = ""
    @State private var amount: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppTopHeader()

            Text("Oral Agreement / Wager")
                .font(.headline)
                .padding(.top, 10)

            Form {
                Section(header: Text("Parties")) {
                    TextField("Party A (name or DID)", text: $partyA)
                    TextField("Party B (name or DID)", text: $partyB)
                }
                Section(header: Text("Terms")) {
                    TextEditor(text: $terms)
                        .frame(height: 140)
                }
                Section(header: Text("Amount (optional)")) {
                    TextField("e.g., $100 or 0.01 BTC", text: $amount)
                }
                Section {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Record Witness")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled((partyA.isEmpty && partyB.isEmpty) || terms.isEmpty || isSubmitting)
                }
            }
        }
        .background(Color.white)
    }

    private func submit() {
        isSubmitting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            partyA = ""
            partyB = ""
            terms = ""
            amount = ""
        }
    }
}

