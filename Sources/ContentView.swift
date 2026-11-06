import SwiftUI
import UIKit

@main
struct AlphaMonitorApp: App {
    @StateObject private var cam = CameraController()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(cam)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var cam: CameraController
    @State private var started = false

    var body: some View {
        TabView {
            CameraScreen()
                .tabItem { Label("Camera", systemImage: "camera") }
            PrompterScreen()
                .tabItem { Label("Gobbo", systemImage: "text.alignleft") }
            ShotListScreen()
                .tabItem { Label("Scaletta", systemImage: "checklist") }
        }
        .onAppear {
            guard !started else { return }
            started = true
            UIApplication.shared.isIdleTimerDisabled = true
            cam.start()
        }
    }
}

/// Rettangolo occupato da un'immagine "scaledToFit" dentro un contenitore.
func fittedRect(_ image: CGSize, in box: CGSize) -> CGRect {
    guard image.width > 0, image.height > 0 else { return .zero }
    let scale = min(box.width / image.width, box.height / image.height)
    let w = image.width * scale, h = image.height * scale
    return CGRect(x: (box.width - w) / 2, y: (box.height - h) / 2, width: w, height: h)
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
