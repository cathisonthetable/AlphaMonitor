import SwiftUI
import UIKit

@main
struct AlphaMonitorApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var cam = CameraController()
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(cam.connected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(cam.status).font(.footnote).lineLimit(2)
                Spacer()
                if cam.isLive {
                    Text(String(format: "%.1f fps", cam.fps))
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            ZStack {
                Color.black
                if let img = cam.liveImage {
                    Image(uiImage: img).resizable().scaledToFit()
                } else {
                    Text("Nessuna immagine").foregroundColor(.gray)
                }
            }
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("Modo: \(cam.modeText)")
                Spacer()
                Text(cam.evText)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ParamControl(title: "ISO", value: cam.isoText,
                             minus: { cam.step(SonyProp.iso, up: false) },
                             plus: { cam.step(SonyProp.iso, up: true) })
                ParamControl(title: "Tempo", value: cam.shutterText,
                             minus: { cam.step(SonyProp.shutterSpeed, up: false) },
                             plus: { cam.step(SonyProp.shutterSpeed, up: true) })
                ParamControl(title: "Diaframma", value: cam.apertureText,
                             minus: { cam.step(SonyProp.fNumber, up: false) },
                             plus: { cam.step(SonyProp.fNumber, up: true) })
            }
            .disabled(!cam.connected)

            HStack(spacing: 24) {
                Button(cam.isLive ? "Stop live" : "Live view") { cam.toggleLive() }
                    .buttonStyle(.bordered)
                    .disabled(!cam.connected)

                Button { cam.shoot() } label: {
                    Image(systemName: "camera.circle.fill").font(.system(size: 60))
                }
                .disabled(!cam.connected)

                Button("Log") { showLog = true }
                    .buttonStyle(.bordered)
            }

            if !cam.connected {
                Button("Riprova connessione") { cam.start() }
                    .font(.footnote)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .sheet(isPresented: $showLog) { LogView(text: cam.logText) }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            cam.start()
        }
    }
}

struct ParamControl: View {
    let title: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Button(action: minus) { Image(systemName: "chevron.left") }
                Button(action: plus) { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
    }
}

struct LogView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text.isEmpty ? "(vuoto)" : text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: text) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
    }
}
