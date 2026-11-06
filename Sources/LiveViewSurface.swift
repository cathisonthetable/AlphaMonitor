import SwiftUI

/// Live view con: zoom (pizzica) e spostamento (trascina), tocco per mettere a fuoco,
/// guide di formato, griglia, bordo rosso in registrazione.
struct LiveViewSurface: View {
    @EnvironmentObject var cam: CameraController
    var showFullscreenButton = false
    var onFullscreen: (() -> Void)? = nil

    @AppStorage("mirror") private var mirror = false
    @AppStorage("guide916") private var g916 = false
    @AppStorage("guide45") private var g45 = false
    @AppStorage("guide11") private var g11 = false
    @AppStorage("gridThirds") private var thirds = false
    @AppStorage("gridCenter") private var center = false

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let rect = fittedRect(cam.liveImage?.size ?? CGSize(width: 3, height: 2), in: size)
            ZStack {
                Color.black

                // Livello che si ingrandisce / specchia
                ZStack {
                    if let img = cam.liveImage {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        Text("Nessuna immagine").foregroundColor(.gray)
                    }
                    if let p = cam.focusPoint, cam.liveImage != nil {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .position(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(x: mirror ? -1 : 1, y: 1)
                .scaleEffect(zoom)
                .offset(pan)

                // Guide e griglia (solo senza zoom)
                if zoom <= 1.01 && cam.liveImage != nil {
                    FramingOverlay(rect: rect, g916: g916, g45: g45, g11: g11, thirds: thirds, center: center)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                handleTap(value.location, size: size, rect: rect)
            })
            .simultaneousGesture(dragGesture(size: size))
            .simultaneousGesture(magnifyGesture(size: size))
            .overlay(alignment: .topLeading) {
                RecTimer().padding(8)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    if zoom > 1.01 {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { resetZoom() }
                        } label: {
                            Text(String(format: "%.1f×", zoom))
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Capsule())
                        }
                    }
                    if showFullscreenButton {
                        Button { onFullscreen?() } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.footnote.bold())
                                .padding(8)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: cam.isRecording ? 6 : 0)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Gesti

    private func handleTap(_ loc: CGPoint, size: CGSize, rect: CGRect) {
        guard cam.connected, cam.liveImage != nil, rect.width > 0, rect.height > 0 else { return }
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        // inverso di: specchio -> zoom (dal centro) -> spostamento
        var u = CGPoint(x: (loc.x - c.x - pan.width) / zoom + c.x,
                        y: (loc.y - c.y - pan.height) / zoom + c.y)
        if mirror { u.x = 2 * c.x - u.x }
        guard rect.contains(u) else { return }
        cam.focus(at: CGPoint(x: (u.x - rect.minX) / rect.width, y: (u.y - rect.minY) / rect.height))
    }

    private func magnifyGesture(size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(6, max(1, lastZoom * value))
                pan = clampPan(pan, size: size)
            }
            .onEnded { _ in
                lastZoom = zoom
                lastPan = pan
                if zoom <= 1.01 { resetZoom() }
            }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard zoom > 1.01 else { return }
                pan = clampPan(CGSize(width: lastPan.width + value.translation.width,
                                      height: lastPan.height + value.translation.height), size: size)
            }
            .onEnded { _ in lastPan = pan }
    }

    private func clampPan(_ p: CGSize, size: CGSize) -> CGSize {
        let mx = (zoom - 1) * size.width / 2
        let my = (zoom - 1) * size.height / 2
        return CGSize(width: min(mx, max(-mx, p.width)), height: min(my, max(-my, p.height)))
    }

    private func resetZoom() {
        zoom = 1
        lastZoom = 1
        pan = .zero
        lastPan = .zero
    }
}

// MARK: - Guide di formato e griglia

struct FramingOverlay: View {
    let rect: CGRect
    let g916: Bool
    let g45: Bool
    let g11: Bool
    let thirds: Bool
    let center: Bool

    var body: some View {
        ZStack {
            if thirds {
                Path { p in
                    for i in 1...2 {
                        let x = rect.minX + rect.width * CGFloat(i) / 3
                        p.move(to: CGPoint(x: x, y: rect.minY))
                        p.addLine(to: CGPoint(x: x, y: rect.maxY))
                        let y = rect.minY + rect.height * CGFloat(i) / 3
                        p.move(to: CGPoint(x: rect.minX, y: y))
                        p.addLine(to: CGPoint(x: rect.maxX, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
            if center {
                Path { p in
                    let c = CGPoint(x: rect.midX, y: rect.midY)
                    p.move(to: CGPoint(x: c.x - 14, y: c.y))
                    p.addLine(to: CGPoint(x: c.x + 14, y: c.y))
                    p.move(to: CGPoint(x: c.x, y: c.y - 14))
                    p.addLine(to: CGPoint(x: c.x, y: c.y + 14))
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
            }
            if g916 { guide(9.0 / 16.0, "9:16", .yellow) }
            if g45 { guide(4.0 / 5.0, "4:5", .cyan) }
            if g11 { guide(1.0, "1:1", .orange) }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func guide(_ ratio: CGFloat, _ label: String, _ color: Color) -> some View {
        let h = rect.height
        let w = min(rect.width, h * ratio)
        let r = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: h)
        Path { p in p.addRect(r) }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        Text(label)
            .font(.caption2.bold())
            .foregroundColor(color)
            .position(x: r.minX + 18, y: r.minY + 10)
    }
}

// MARK: - Pulsanti e indicatori condivisi

struct ShutterButton: View {
    @EnvironmentObject var cam: CameraController
    var size: CGFloat = 60

    var body: some View {
        Button { cam.shoot() } label: {
            Image(systemName: "camera.circle.fill").font(.system(size: size))
        }
        .disabled(!cam.connected)
    }
}

struct RecButton: View {
    @EnvironmentObject var cam: CameraController
    var size: CGFloat = 60

    var body: some View {
        Button { cam.toggleRecord() } label: {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.6), lineWidth: 3)
                if cam.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: size * 0.36, height: size * 0.36)
                } else {
                    Circle().fill(Color.red).padding(size * 0.14)
                }
            }
            .frame(width: size, height: size)
        }
        .disabled(!cam.connected)
    }
}

struct RecTimer: View {
    @EnvironmentObject var cam: CameraController

    var body: some View {
        if let start = cam.recStart {
            TimelineView(.periodic(from: start, by: 1)) { ctx in
                let s = max(0, Int(ctx.date.timeIntervalSince(start)))
                Text(String(format: "● REC %02d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
            }
        }
    }
}
