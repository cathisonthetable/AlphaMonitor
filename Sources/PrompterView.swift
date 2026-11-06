import SwiftUI
import Combine

// MARK: - Gobbo (teleprompter)

struct PrompterScreen: View {
    @EnvironmentObject var cam: CameraController
    @AppStorage("prompterText") private var text = "Scrivi qui il testo da leggere…"
    @AppStorage("prompterSpeed") private var speed = 40.0
    @AppStorage("prompterFont") private var fontSize = 40.0
    @AppStorage("prompterMirror") private var mirrorText = false
    @State private var playing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                VStack(spacing: 8) {
                    HStack {
                        Text("Velocità").frame(width: 80, alignment: .leading)
                        Slider(value: $speed, in: 10...150)
                        Text("\(Int(speed))").monospacedDigit().frame(width: 36)
                    }
                    HStack {
                        Text("Carattere").frame(width: 80, alignment: .leading)
                        Slider(value: $fontSize, in: 20...90)
                        Text("\(Int(fontSize))").monospacedDigit().frame(width: 36)
                    }
                    Toggle("Testo specchiato (per vetro da teleprompter)", isOn: $mirrorText)
                }
                .font(.footnote)

                Button { playing = true } label: {
                    Label("Avvia gobbo", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Gobbo")
            .fullScreenCover(isPresented: $playing) {
                PrompterPlayer(text: text, speed: $speed, fontSize: fontSize, mirrorText: mirrorText)
                    .environmentObject(cam)
            }
        }
    }
}

private struct TextHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PrompterPlayer: View {
    let text: String
    @Binding var speed: Double
    let fontSize: Double
    let mirrorText: Bool

    @EnvironmentObject var cam: CameraController
    @Environment(\.dismiss) private var dismiss
    @State private var offset: CGFloat = 0
    @State private var running = false
    @State private var textHeight: CGFloat = 0
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let readingLine = geo.size.height * 0.3
            ZStack(alignment: .topLeading) {
                Color.black

                Text(text)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .lineSpacing(fontSize * 0.25)
                    .padding(.horizontal, 28)
                    .frame(width: geo.size.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { t in
                            Color.clear.preference(key: TextHeightKey.self, value: t.size.height)
                        }
                    )
                    .offset(y: readingLine - offset)
                    .scaleEffect(x: mirrorText ? -1 : 1, y: 1)

                // Linea di lettura
                Rectangle()
                    .fill(Color.yellow.opacity(0.35))
                    .frame(width: 24, height: 4)
                    .offset(x: 0, y: readingLine + fontSize * 0.5)
            }
            .contentShape(Rectangle())
            .onTapGesture { running.toggle() }
            .onPreferenceChange(TextHeightKey.self) { textHeight = $0 }
            .onReceive(tick) { _ in
                guard running else { return }
                offset += CGFloat(speed) / 60
                if offset > textHeight { running = false }
            }
            .overlay(alignment: .topTrailing) { thumbnail }
            .overlay(alignment: .bottom) { controls }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let img = cam.liveImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .overlay(Rectangle().stroke(cam.isRecording ? Color.red : Color.gray, lineWidth: 3))
                .padding(.top, 50)
                .padding(.trailing, 16)
        }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
            Button { offset = 0; running = false } label: { Image(systemName: "backward.end.fill") }
            Button { speed = max(10, speed - 10) } label: { Image(systemName: "tortoise.fill") }
            Text("\(Int(speed))").monospacedDigit().font(.headline)
            Button { speed = min(150, speed + 10) } label: { Image(systemName: "hare.fill") }
            Button { running.toggle() } label: { Image(systemName: running ? "pause.fill" : "play.fill") }
            RecButton(size: 40)
        }
        .font(.title3)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .clipShape(Capsule())
        .padding(.bottom, 30)
    }
}
