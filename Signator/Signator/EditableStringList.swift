import SwiftUI

struct EditableStringList: View {
    @Binding var strings: [String]
    @State private var newEntry: String = ""
    var validateEntry: ((String) async -> Bool)? = nil

    var body: some View {
        VStack {
            List {
                ForEach(strings.indices, id: \.self) { idx in
                    TextField("Enter text", text: Binding(
                        get: { strings[idx] },
                        set: { strings[idx] = $0.lowercased() }
                    ))
                }
                .onDelete { indices in
                    strings.remove(atOffsets: indices)
                }
            }
            
            HStack {
                TextField("New entry", text: $newEntry)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: {
                    Task {
                        let trimmed = newEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if let validate = validateEntry {
                            let isValid = await validate(trimmed)
                            if isValid {
                                strings.append(trimmed.lowercased())
                                newEntry = ""
                            }
                        } else {
                            strings.append(trimmed.lowercased())
                            newEntry = ""
                        }
                    }
                }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add new entry")
            }
            .padding()
        }
    }
}

struct EditableStringList_Previews: PreviewProvider {
    @State static var sampleStrings = ["apple", "banana", "cherry"]
    static var previews: some View {
        EditableStringList(strings: $sampleStrings)
    }
}
