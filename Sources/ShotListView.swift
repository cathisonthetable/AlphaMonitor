import SwiftUI

struct Shot: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}

struct ShotListScreen: View {
    @AppStorage("shotsJSON") private var shotsJSON = "[]"
    @State private var shots: [Shot] = []
    @State private var newTitle = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Nuova ripresa…", text: $newTitle)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    ForEach($shots) { $shot in
                        Button {
                            shot.done.toggle()
                        } label: {
                            HStack {
                                Image(systemName: shot.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(shot.done ? .green : .secondary)
                                Text(shot.title)
                                    .strikethrough(shot.done)
                                    .foregroundColor(shot.done ? .secondary : .primary)
                            }
                        }
                    }
                    .onDelete { shots.remove(atOffsets: $0) }
                    .onMove { shots.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("\(shots.filter { $0.done }.count) di \(shots.count) fatte · scorri a sinistra per eliminare")
                }
            }
            .navigationTitle("Scaletta")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Azzera") {
                        for i in shots.indices { shots[i].done = false }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                shots = (try? JSONDecoder().decode([Shot].self, from: Data(shotsJSON.utf8))) ?? []
            }
            .onChange(of: shots) { newValue in
                if let d = try? JSONEncoder().encode(newValue) {
                    shotsJSON = String(decoding: d, as: UTF8.self)
                }
            }
        }
    }

    private func add() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        shots.append(Shot(title: t))
        newTitle = ""
    }
}
