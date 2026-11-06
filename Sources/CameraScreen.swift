import SwiftUI

// MARK: - Schermata normale

struct CameraScreen: View {
    @EnvironmentObject var cam: CameraController
    @State private var showLog = false
    @State private var showSettings = false
    @State private var fullscreen = false

    var body: some View {
        VStack(spacing: 10) {
            StatusRow()

            LiveViewSurface(showFullscreenButton: true, onFullscreen: { fullscreen = true })
                .aspectRatio(3.0 / 2.0, contentMode: .fit)

            HStack {
                Text("Modo: \(cam.modeText)")
                Spacer()
                Label(cam.storageText, systemImage: "sdcard")
                Spacer()
                Text(cam.evText)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            ToolsRow(showSettings: $showSettings)

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

            HStack(spacing: 22) {
                Button(cam.isLive ? "Stop live" : "Live") { cam.toggleLive() }
                    .buttonStyle(.bordered)
                    .disabled(!cam.connected)
                ShutterButton(size: 58)
                RecButton(size: 58)
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
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $fullscreen) {
            FullscreenCameraView().environmentObject(cam)
        }
    }
}

struct StatusRow: View {
    @EnvironmentObject var cam: CameraController

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(cam.connected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(cam.status).font(.footnote).lineLimit(1)
            Spacer()
            if cam.isLive {
                Text(String(format: "%.1f fps", cam.fps))
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Label(cam.batteryText, systemImage: "battery.75")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct ToolsRow: View {
    @Binding var showSettings: Bool
    @AppStorage("peaking") private var peaking = false
    @AppStorage("guide916") private var g916 = false
    @AppStorage("guide45") private var g45 = false
    @AppStorage("guide11") private var g11 = false
    @AppStorage("gridThirds") private var thirds = false
    @AppStorage("gridCenter") private var center = false

    var body: some View {
        HStack(spacing: 10) {
            GuidesMenu(g916: $g916, g45: $g45, g11: $g11, thirds: $thirds, center: $center)
            Toggle(isOn: $peaking) { Label("Peaking", systemImage: "scope") }
                .toggleStyle(.button)
            Spacer()
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.bordered)
        }
        .font(.footnote)
    }
}

struct GuidesMenu: View {
    @Binding var g916: Bool
    @Binding var g45: Bool
    @Binding var g11: Bool
    @Binding var thirds: Bool
    @Binding var center: Bool
    var compact = false

    var body: some View {
        Menu {
            Toggle("9:16 (1080×1920)", isOn: $g916)
            Toggle("4:5 (1080×1350)", isOn: $g45)
            Toggle("1:1 (1080×1080)", isOn: $g11)
            Divider()
            Toggle("Griglia dei terzi", isOn: $thirds)
            Toggle("Centro", isOn: $center)
        } label: {
            if compact {
                Image(systemName: "rectangle.dashed")
            } else {
                Label("Guide", systemImage: "rectangle.dashed")
            }
        }
    }
}

// MARK: - Schermo intero

struct FullscreenCameraView: View {
    @EnvironmentObject var cam: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                // Orizzontale: info a sinistra, comandi a destra
                HStack(spacing: 6) {
                    InfoColumn().frame(width: 96)
                    LiveViewSurface()
                    ControlColumn(showSettings: $showSettings, close: { dismiss() })
                        .frame(width: 80)
                }
                .padding(.vertical, 4)
            } else {
                // Verticale: info sopra, comandi sotto
                VStack(spacing: 8) {
                    InfoBar()
                    Spacer(minLength: 0)
                    LiveViewSurface().aspectRatio(3.0 / 2.0, contentMode: .fit)
                    Spacer(minLength: 0)
                    ControlBar(showSettings: $showSettings, close: { dismiss() })
                }
                .padding(8)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)
        .environment(\.colorScheme, .dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

/// Parametro compatto con frecce piccole (schermo intero)
struct CompactParam: View {
    @EnvironmentObject var cam: CameraController
    let title: String
    let value: String
    let prop: UInt16

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9)).foregroundColor(.gray)
            HStack(spacing: 4) {
                Button { cam.step(prop, up: false) } label: { Image(systemName: "chevron.left") }
                Text(value)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minWidth: 44)
                Button { cam.step(prop, up: true) } label: { Image(systemName: "chevron.right") }
            }
            .font(.system(size: 12, weight: .bold))
        }
        .disabled(!cam.connected)
    }
}

struct InfoColumn: View {
    @EnvironmentObject var cam: CameraController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompactParam(title: "ISO", value: cam.isoText, prop: SonyProp.iso)
            CompactParam(title: "TEMPO", value: cam.shutterText, prop: SonyProp.shutterSpeed)
            CompactParam(title: "DIAFRAMMA", value: cam.apertureText, prop: SonyProp.fNumber)
            Text(cam.evText).font(.system(size: 12).monospacedDigit())
            Text("Modo \(cam.modeText)").font(.system(size: 12))
            Spacer(minLength: 0)
            Label(cam.batteryText, systemImage: "battery.75").font(.system(size: 11))
            Label(cam.storageText, systemImage: "sdcard")
                .font(.system(size: 10))
                .lineLimit(3)
            if cam.isLive {
                Text(String(format: "%.0f fps", cam.fps)).font(.system(size: 10)).foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
    }
}

struct InfoBar: View {
    @EnvironmentObject var cam: CameraController

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                CompactParam(title: "ISO", value: cam.isoText, prop: SonyProp.iso)
                Spacer()
                CompactParam(title: "TEMPO", value: cam.shutterText, prop: SonyProp.shutterSpeed)
                Spacer()
                CompactParam(title: "DIAFRAMMA", value: cam.apertureText, prop: SonyProp.fNumber)
            }
            HStack {
                Text("\(cam.modeText)  \(cam.evText)")
                Spacer()
                Label(cam.batteryText, systemImage: "battery.75")
                Label(cam.storageText, systemImage: "sdcard").lineLimit(1)
            }
            .font(.system(size: 11))
            .foregroundColor(.gray)
        }
    }
}

struct ControlColumn: View {
    @Binding var showSettings: Bool
    let close: () -> Void
    @AppStorage("peaking") private var peaking = false
    @AppStorage("guide916") private var g916 = false
    @AppStorage("guide45") private var g45 = false
    @AppStorage("guide11") private var g11 = false
    @AppStorage("gridThirds") private var thirds = false
    @AppStorage("gridCenter") private var center = false

    var body: some View {
        VStack(spacing: 14) {
            Button(action: close) { Image(systemName: "arrow.down.right.and.arrow.up.left") }
            GuidesMenu(g916: $g916, g45: $g45, g11: $g11, thirds: $thirds, center: $center, compact: true)
            Button { peaking.toggle() } label: {
                Image(systemName: "scope").foregroundColor(peaking ? .yellow : .white)
            }
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
            Spacer(minLength: 0)
            RecButton(size: 52)
            ShutterButton(size: 52)
            Spacer(minLength: 0)
        }
        .font(.system(size: 18))
        .padding(.vertical, 8)
    }
}

struct ControlBar: View {
    @Binding var showSettings: Bool
    let close: () -> Void
    @AppStorage("peaking") private var peaking = false
    @AppStorage("guide916") private var g916 = false
    @AppStorage("guide45") private var g45 = false
    @AppStorage("guide11") private var g11 = false
    @AppStorage("gridThirds") private var thirds = false
    @AppStorage("gridCenter") private var center = false

    var body: some View {
        HStack(spacing: 18) {
            Button(action: close) { Image(systemName: "arrow.down.right.and.arrow.up.left") }
            GuidesMenu(g916: $g916, g45: $g45, g11: $g11, thirds: $thirds, center: $center, compact: true)
            Button { peaking.toggle() } label: {
                Image(systemName: "scope").foregroundColor(peaking ? .yellow : .white)
            }
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
            Spacer()
            RecButton(size: 56)
            ShutterButton(size: 56)
        }
        .font(.system(size: 20))
    }
}
