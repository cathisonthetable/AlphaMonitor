import Foundation
import ImageCaptureCore
import UIKit

/// Parla con la fotocamera Sony via USB (PTP, modalita' "PC Remote")
/// usando ImageCaptureCore di iOS. Tutto gira sul main thread; i comandi PTP
/// passano da una coda, uno alla volta.
final class CameraController: NSObject, ObservableObject {
    @Published var status = "Non connessa"
    @Published var connected = false
    @Published var logText = ""
    @Published var liveImage: UIImage?
    @Published var isLive = false
    @Published var fps: Double = 0
    @Published var isoText = "--"
    @Published var shutterText = "--"
    @Published var apertureText = "--"
    @Published var evText = "--"
    @Published var modeText = "--"

    private let browser = ICDeviceBrowser()
    private var camera: ICCameraDevice?
    private var transactionID: UInt32 = 1
    private var handshakeStarted = false
    private var props: [UInt16: SonyProperty] = [:]
    private var didDumpProps = false
    private var refreshTimer: Timer?

    // live view
    private var frameCount = 0
    private var fpsStart = Date()
    private var liveErrors = 0
    private var loggedBadFrame = false

    // coda comandi
    private struct Pending {
        let code: UInt16
        let params: [UInt32]
        let data: Data?
        let quiet: Bool
        let completion: ((Data, UInt16, Error?) -> Void)?
    }
    private var queue: [Pending] = []
    private var busy = false

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    override init() {
        super.init()
        browser.delegate = self
    }

    // MARK: - Log

    func log(_ s: String) {
        let line = "[\(Self.timeFmt.string(from: Date()))] \(s)\n"
        DispatchQueue.main.async {
            self.logText += line
            if self.logText.count > 80_000 { self.logText = String(self.logText.suffix(50_000)) }
        }
    }

    // MARK: - Avvio

    func start() {
        let info = Bundle.main.infoDictionary
        log("Alpha Monitor \(info?["CFBundleShortVersionString"] ?? "?") – iOS \(UIDevice.current.systemVersion)")
        log("Chiedo i permessi…")
        browser.requestContentsAuthorization { contents in
            self.log("Permesso contenuti: \(contents.rawValue)")
            self.browser.requestControlAuthorization { control in
                self.log("Permesso controllo: \(control.rawValue)")
                DispatchQueue.main.async {
                    if !self.browser.isBrowsing { self.browser.start() }
                    self.status = "Cerco la fotocamera… (cavo USB + PC Remote)"
                    self.log("Ricerca dispositivi avviata")
                }
            }
        }
    }

    // MARK: - Comandi PTP (coda seriale)

    func send(_ code: UInt16, _ params: [UInt32] = [], data: Data? = nil, quiet: Bool = false,
              completion: ((Data, UInt16, Error?) -> Void)? = nil) {
        queue.append(Pending(code: code, params: params, data: data, quiet: quiet, completion: completion))
        pump()
    }

    private func pump() {
        guard !busy, !queue.isEmpty else { return }
        guard let cam = camera else { queue.removeAll(); return }
        busy = true
        let p = queue.removeFirst()
        let cmd = PTPContainer.command(p.code, transactionID: transactionID, params: p.params)
        transactionID &+= 1
        cam.requestSendPTPCommand(cmd, outData: p.data) { data, response, error in
            DispatchQueue.main.async {
                let rc = PTPContainer.responseCode(response)
                if !p.quiet || error != nil || rc != PTPConst.responseOK {
                    let ps = p.params.map { String(format: "0x%X", $0) }.joined(separator: ",")
                    var line = String(format: "op 0x%04X", p.code) + " [\(ps)]"
                    if let out = p.data { line += " out=\(out.hex)" }
                    line += String(format: " → risp 0x%04X", rc) + ", \(data.count) byte"
                    if let e = error as NSError? { line += " ERRORE \(e.domain) \(e.code): \(e.localizedDescription)" }
                    self.log(line)
                }
                self.busy = false
                p.completion?(data, rc, error)
                self.pump()
            }
        }
    }

    // MARK: - Handshake Sony

    private func sonyHandshake() {
        guard !handshakeStarted else { return }
        handshakeStarted = true
        status = "Handshake Sony…"
        log("Handshake Sony (SDIO connect 1/2/3)…")
        send(PTPOp.sonySDIOConnect, [1, 0, 0])
        send(PTPOp.sonySDIOConnect, [2, 0, 0])
        send(PTPOp.sonyGetExtDeviceInfo, [0xC8]) { data, rc, _ in
            self.log("ExtDeviceInfo (\(data.count) byte): \(data.prefix(48).hex)")
        }
        send(PTPOp.sonySDIOConnect, [3, 0, 0]) { _, rc, err in
            if err == nil && rc == PTPConst.responseOK {
                self.connected = true
                self.status = "Connessa ✓"
                self.log("Handshake completato")
            } else {
                self.status = "Handshake fallito – vedi Log"
            }
            self.refreshProps()
            self.startRefreshTimer()
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.camera != nil else { return }
            if !self.queue.contains(where: { $0.code == PTPOp.sonyGetAllExtDevicePropInfo }) {
                self.refreshProps()
            }
        }
    }

    // MARK: - Proprieta'

    func refreshProps(then: (() -> Void)? = nil) {
        send(PTPOp.sonyGetAllExtDevicePropInfo, quiet: true) { data, rc, err in
            defer { then?() }
            guard err == nil, rc == PTPConst.responseOK else { return }
            let (p, perr) = SonyProps.parseAll(data)
            if !self.didDumpProps || perr != nil {
                self.didDumpProps = true
                self.log("Proprietà lette: \(p.count) (\(data.count) byte)" + (perr.map { " – errore parsing: \($0)" } ?? ""))
                let codes = p.keys.sorted().map { String(format: "%04X", $0) }.joined(separator: " ")
                self.log("Codici: \(codes)")
                if p.isEmpty { self.log("Inizio dati: \(data.prefix(64).hex)") }
            }
            for (k, v) in p { self.props[k] = v }
            self.isoText = SonyProps.formatISO(self.props[SonyProp.iso]?.current.intValue)
            self.shutterText = SonyProps.formatShutter(self.props[SonyProp.shutterSpeed]?.current.intValue)
            self.apertureText = SonyProps.formatAperture(self.props[SonyProp.fNumber]?.current.intValue)
            self.evText = SonyProps.formatEV(self.props[SonyProp.exposureComp]?.current.intValue)
            self.modeText = SonyProps.formatMode(self.props[SonyProp.exposureMode]?.current.intValue)
        }
    }

    /// Cambia ISO / tempo / diaframma di un passo. Prima prova il "passo" Sony
    /// (0x9207 con +1/-1); se il valore non cambia, prova a impostare
    /// direttamente il valore successivo dell'elenco (0x9205).
    func step(_ prop: UInt16, up: Bool) {
        let before = props[prop]?.current.intValue
        send(PTPOp.sonySetControlDeviceB, [UInt32(prop)], data: Data([up ? 0x01 : 0xFF]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.refreshProps {
                guard let p = self.props[prop], let now = p.current.intValue else { return }
                if now != before { return }
                guard let idx = p.enumValues.firstIndex(of: now) else {
                    self.log(String(format: "0x%04X: valore invariato, nessun elenco valori", prop))
                    return
                }
                let next = idx + (up ? 1 : -1)
                guard p.enumValues.indices.contains(next) else { return }
                self.log(String(format: "0x%04X: passo senza effetto, provo impostazione diretta", prop))
                self.send(PTPOp.sonySetControlDeviceA, [UInt32(prop)],
                          data: SonyProps.encode(p.enumValues[next], type: p.dataType)) { _, _, _ in
                    self.refreshProps()
                }
            }
        }
    }

    private func button(_ prop: UInt16, _ value: UInt16, then: (() -> Void)? = nil) {
        var d = Data()
        d.appendLE(value)
        send(PTPOp.sonySetControlDeviceB, [UInt32(prop)], data: d) { _, _, _ in then?() }
    }

    /// Mezza pressione -> pressione completa -> rilascio.
    func shoot() {
        log("Scatto")
        button(SonyProp.halfPress, 2) {
            self.button(SonyProp.fullPress, 2) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.button(SonyProp.fullPress, 1) {
                        self.button(SonyProp.halfPress, 1)
                    }
                }
            }
        }
    }

    // MARK: - Live view

    func toggleLive() { isLive ? stopLive() : startLive() }

    func startLive() {
        guard camera != nil else { log("Nessuna fotocamera collegata"); return }
        log("Live view avviata")
        isLive = true
        frameCount = 0
        liveErrors = 0
        fpsStart = Date()
        fetchFrame()
    }

    func stopLive() {
        if isLive { log("Live view fermata") }
        isLive = false
        fps = 0
    }

    private func fetchFrame() {
        guard isLive else { return }
        send(PTPOp.getObject, [PTPConst.liveViewHandle], quiet: true) { data, rc, err in
            if err == nil, rc == PTPConst.responseOK,
               let jpeg = PTPContainer.extractJPEG(data), let img = UIImage(data: jpeg) {
                self.liveErrors = 0
                self.liveImage = img
                self.frameCount += 1
                let dt = Date().timeIntervalSince(self.fpsStart)
                if dt >= 1 {
                    self.fps = Double(self.frameCount) / dt
                    self.frameCount = 0
                    self.fpsStart = Date()
                }
                if !self.loggedBadFrame && self.liveImage != nil && self.frameCount == 1 {
                    self.log("Primo fotogramma: \(Int(img.size.width))×\(Int(img.size.height)), \(data.count) byte")
                    self.loggedBadFrame = true
                }
                self.fetchFrame()
            } else {
                self.liveErrors += 1
                if self.liveErrors <= 3 {
                    self.log("Fotogramma non valido (\(data.count) byte): \(data.prefix(32).hex)")
                }
                if self.liveErrors > 50 {
                    self.log("Troppi errori, live view fermata")
                    self.stopLive()
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.fetchFrame() }
            }
        }
    }

    // MARK: - Reset

    private func reset(_ why: String) {
        log(why)
        stopLive()
        refreshTimer?.invalidate()
        camera = nil
        handshakeStarted = false
        connected = false
        queue.removeAll()
        busy = false
        props = [:]
        status = "Non connessa"
    }
}

// MARK: - ICDeviceBrowserDelegate

extension CameraController: ICDeviceBrowserDelegate {
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        log("Dispositivo trovato: \(device.name ?? "?") – capacità: \(device.capabilities.joined(separator: ", "))")
        guard camera == nil, let cam = device as? ICCameraDevice else { return }
        camera = cam
        cam.delegate = self
        status = "Apro la sessione…"
        cam.requestOpenSession()
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if device === camera { reset("Fotocamera scollegata") }
    }
}

// MARK: - ICCameraDeviceDelegate

extension CameraController: ICCameraDeviceDelegate {
    func didRemove(_ device: ICDevice) {
        if device === camera { reset("Fotocamera rimossa") }
    }

    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if let error {
            log("Errore apertura sessione: \(error.localizedDescription)")
            status = "Sessione non aperta – vedi Log"
            return
        }
        log("Sessione aperta")
        // Di solito si aspetta deviceDidBecomeReady; se non arriva, partiamo comunque.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.sonyHandshake() }
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        log("Sessione chiusa \(error?.localizedDescription ?? "")")
    }

    func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        log("Fotocamera pronta")
        sonyHandshake()
    }

    func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {
        // Gli eventi Sony (es. 0xC203 "proprietà cambiata") sono molto frequenti: non li logghiamo.
    }

    func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {}
    func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}
    func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: Error?) {}
    func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: Error?) {}
    func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}
    func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}
}
