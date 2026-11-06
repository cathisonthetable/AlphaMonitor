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
    @FocusState private var editing: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 200)
                    .focused($editing)
                    .scrollDismissesKeyboard(.interactively)
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
                    Text("In lettura: tocca = pausa · trascina su/giù = scorri · swipe ←/→ = velocità · swipe giù dal bordo alto = chiudi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.footnote)

                Button { editing = false; playing = true } label: {
                    Label("Avvia gobbo", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            // Swipe verso il basso = chiudi la tastiera
            .simultaneousGesture(
                DragGesture(minimumDistance: 25).onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if dy > 50 && dy > abs(dx) { editing = false }
                }
            )
            .navigationTitle("Gobbo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if editing {
                        Button("Fine") { editing = false }.bold()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { editing = false }
                }
            }
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
    @State private var dragStartOffset: CGFloat?
    @State private var dragFromTop = false
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
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { v in
                        if dragStartOffset == nil {
                            dragStartOffset = offset
                            dragFromTop = v.startLocation.y < geo.size.height * 0.12
                        }
                        // Trascina su/giu' = scorri il testo a mano (mette in pausa)
                        guard !dragFromTop, abs(v.translation.height) > abs(v.translation.width) else { return }
                        running = false
                        offset = min(textHeight, max(0, (dragStartOffset ?? 0) - v.translation.height))
                    }
                    .onEnded { v in
                        defer { dragStartOffset = nil }
                        let dx = v.translation.width, dy = v.translation.height
                        // Swipe giu' partendo dal bordo alto = chiudi
                        if dragFromTop && dy > 80 { dismiss(); return }
                        // Swipe destra / sinistra = piu' veloce / piu' lento
                        if abs(dx) > 80 && abs(dx) > abs(dy) * 1.5 {
                            speed = dx > 0 ? min(150, speed + 10) : max(10, speed - 10)
                        }
                    }
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)
                    .allowsHitTesting(false)
            }
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
