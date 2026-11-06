import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("guide916") private var g916 = false
    @AppStorage("guide45") private var g45 = false
    @AppStorage("guide11") private var g11 = false
    @AppStorage("gridThirds") private var thirds = false
    @AppStorage("gridCenter") private var center = false
    @AppStorage("peaking") private var peaking = false
    @AppStorage("peakingColor") private var peakingColor = "rosso"
    @AppStorage("peakingThreshold") private var peakingThreshold = 0.25
    @AppStorage("mirror") private var mirror = false
    @AppStorage("autoSavePhotos") private var autoSavePhotos = true

    private let colors = ["rosso", "giallo", "azzurro", "bianco"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("9:16 (1080×1920) – TikTok, Reels, Shorts", isOn: $g916)
                    Toggle("4:5 (1080×1350) – post Instagram", isOn: $g45)
                    Toggle("1:1 (1080×1080) – quadrato", isOn: $g11)
                } header: {
                    Text("Guide di formato")
                }

                Section {
                    Toggle("Griglia dei terzi", isOn: $thirds)
                    Toggle("Centro", isOn: $center)
                } header: {
                    Text("Griglia")
                }

                Section {
                    Toggle("Attivo", isOn: $peaking)
                    Picker("Colore", selection: $peakingColor) {
                        ForEach(colors, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    VStack(alignment: .leading) {
                        Text("Sensibilità")
                        Slider(value: $peakingThreshold, in: 0.05...0.6) {
                            Text("Sensibilità")
                        } minimumValueLabel: {
                            Text("più").font(.caption)
                        } maximumValueLabel: {
                            Text("meno").font(.caption)
                        }
                    }
                } header: {
                    Text("Focus peaking")
                } footer: {
                    Text("Colora i contorni a fuoco. Utile soprattutto con la messa a fuoco manuale.")
                }

                Section {
                    Toggle("Salva sull'iPhone dopo ogni scatto", isOn: $autoSavePhotos)
                } header: {
                    Text("Foto")
                } footer: {
                    Text("Ogni foto scattata con la fotocamera collegata viene copiata nell'app Foto. Solo foto: i video restano sulla scheda.")
                }

                Section {
                    Toggle("Specchia immagine", isOn: $mirror)
                } header: {
                    Text("Visualizzazione")
                } footer: {
                    Text("Capovolge la live view, comodo quando ti riprendi da sola. Le foto e i video non cambiano.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }
}
