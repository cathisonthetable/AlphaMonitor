import Foundation

// MARK: - Codici PTP (standard + estensioni Sony "PC Remote", come in libgphoto2)

enum PTPOp {
    static let getObject: UInt16 = 0x1009
    static let sonySDIOConnect: UInt16 = 0x9201
    static let sonyGetExtDeviceInfo: UInt16 = 0x9202
    static let sonySetControlDeviceA: UInt16 = 0x9205   // imposta un valore
    static let sonySetControlDeviceB: UInt16 = 0x9207   // "preme un tasto" / passo +-1
    static let sonyGetAllExtDevicePropInfo: UInt16 = 0x9209
}

enum SonyProp {
    static let whiteBalance: UInt16 = 0x5005
    static let fNumber: UInt16 = 0x5007
    static let exposureMode: UInt16 = 0x500E
    static let exposureComp: UInt16 = 0x5010
    static let shutterSpeed: UInt16 = 0xD20D
    static let iso: UInt16 = 0xD21E
    static let halfPress: UInt16 = 0xD2C1
    static let fullPress: UInt16 = 0xD2C2
    static let movieRec: UInt16 = 0xD2C8
    static let afAreaPosition: UInt16 = 0xD2DC   // x<<16 | y, area 640x480 (modelli recenti)
    static let afAreaPositionAlt: UInt16 = 0xD230 // x<<16 | y, sulla a6400 vale 320,180 al centro (640x360)
    static let focusFramePos: UInt16 = 0xD232
    static let batteryLevel: UInt16 = 0xD218
}

enum PTPStdOp {
    static let getStorageIDs: UInt16 = 0x1004
    static let getStorageInfo: UInt16 = 0x1005
}

enum PTPConst {
    static let liveViewHandle: UInt32 = 0xFFFF_C002
    static let responseOK: UInt16 = 0x2001
    static let notReady: UInt16 = 0x200F   // live view: fotogramma non ancora pronto
}

// MARK: - Contenitori PTP

enum PTPContainer {
    static func command(_ code: UInt16, transactionID: UInt32, params: [UInt32]) -> Data {
        var d = Data()
        d.appendLE(UInt32(12 + 4 * params.count))
        d.appendLE(UInt16(1)) // tipo: comando
        d.appendLE(code)
        d.appendLE(transactionID)
        for p in params { d.appendLE(p) }
        return d
    }

    /// Codice di risposta dal contenitore di risposta (byte 6-7).
    static func responseCode(_ response: Data) -> UInt16 {
        let b = [UInt8](response)
        guard b.count >= 8 else { return 0 }
        return UInt16(b[6]) | (UInt16(b[7]) << 8)
    }

    /// Cerca un JPEG (FFD8 ... FFD9) dentro i dati della live view Sony.
    static func extractJPEG(_ data: Data) -> Data? {
        let b = [UInt8](data)
        guard b.count > 4 else { return nil }
        var start = -1
        var i = 0
        while i < b.count - 1 {
            if b[i] == 0xFF && b[i + 1] == 0xD8 { start = i; break }
            i += 1
        }
        guard start >= 0 else { return nil }
        var end = b.count - 2
        while end > start {
            if b[end] == 0xFF && b[end + 1] == 0xD9 { break }
            end -= 1
        }
        guard end > start else { return nil }
        return Data(b[start...(end + 1)])
    }
}

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ v: T) {
        var le = v.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}

// MARK: - Lettura proprieta' Sony (risposta di 0x9209)

enum ParseError: Error, CustomStringConvertible {
    case eof
    case unknownType(UInt16)
    case badForm(UInt8, UInt16)

    var description: String {
        switch self {
        case .eof: return "fine dati inattesa"
        case .unknownType(let t): return String(format: "tipo dato sconosciuto 0x%04X", t)
        case .badForm(let f, let c): return String(format: "form %d sconosciuto per 0x%04X", f, c)
        }
    }
}

struct ByteReader {
    let b: [UInt8]
    var pos = 0
    init(_ d: Data) { b = [UInt8](d) }
    var remaining: Int { b.count - pos }

    mutating func u8() throws -> UInt8 {
        guard remaining >= 1 else { throw ParseError.eof }
        defer { pos += 1 }
        return b[pos]
    }
    mutating func u16() throws -> UInt16 {
        guard remaining >= 2 else { throw ParseError.eof }
        defer { pos += 2 }
        return UInt16(b[pos]) | (UInt16(b[pos + 1]) << 8)
    }
    mutating func u32() throws -> UInt32 {
        let lo = UInt32(try u16()), hi = UInt32(try u16())
        return lo | (hi << 16)
    }
    mutating func u64() throws -> UInt64 {
        let lo = UInt64(try u32()), hi = UInt64(try u32())
        return lo | (hi << 32)
    }
    mutating func skip(_ n: Int) throws {
        guard remaining >= n else { throw ParseError.eof }
        pos += n
    }
}

enum PropValue {
    case int(Int64)
    case string(String)
    case other

    var intValue: Int64? { if case .int(let v) = self { return v } else { return nil } }
}

struct SonyProperty {
    let code: UInt16
    let dataType: UInt16
    let getSet: UInt8
    let enabled: UInt8
    let current: PropValue
    let enumValues: [Int64]
}

enum SonyProps {
    static func readValue(_ r: inout ByteReader, type: UInt16) throws -> PropValue {
        switch type {
        case 0x0001: return .int(Int64(Int8(bitPattern: try r.u8())))
        case 0x0002: return .int(Int64(try r.u8()))
        case 0x0003: return .int(Int64(Int16(bitPattern: try r.u16())))
        case 0x0004: return .int(Int64(try r.u16()))
        case 0x0005: return .int(Int64(Int32(bitPattern: try r.u32())))
        case 0x0006: return .int(Int64(try r.u32()))
        case 0x0007, 0x0008: return .int(Int64(bitPattern: try r.u64()))
        case 0x0009, 0x000A: try r.skip(16); return .other
        case 0xFFFF:
            let n = Int(try r.u8())
            var chars: [UInt16] = []
            for _ in 0..<n { chars.append(try r.u16()) }
            while chars.last == 0 { chars.removeLast() }
            return .string(String(decoding: chars, as: UTF16.self))
        default:
            if type & 0x4000 != 0 {
                let count = Int(try r.u32())
                for _ in 0..<count { _ = try readValue(&r, type: type & ~0x4000) }
                return .other
            }
            throw ParseError.unknownType(type)
        }
    }

    /// Restituisce le proprieta' lette (anche parziali) e l'eventuale errore.
    static func parseAll(_ data: Data) -> ([UInt16: SonyProperty], String?) {
        var r = ByteReader(data)
        var out: [UInt16: SonyProperty] = [:]
        do {
            let count = try r.u64()
            for _ in 0..<min(count, 2000) {
                let code = try r.u16()
                let type = try r.u16()
                let getSet = try r.u8()      // get/set
                let enabled = try r.u8()     // campo extra Sony
                _ = try readValue(&r, type: type) // valore di fabbrica
                let current = try readValue(&r, type: type)
                let form = try r.u8()
                var enums: [Int64] = []
                switch form {
                case 0: break
                case 1:
                    _ = try readValue(&r, type: type)
                    _ = try readValue(&r, type: type)
                    _ = try readValue(&r, type: type)
                case 2:
                    let n = Int(try r.u16())
                    for _ in 0..<n {
                        if let v = try readValue(&r, type: type).intValue { enums.append(v) }
                    }
                default:
                    throw ParseError.badForm(form, code)
                }
                out[code] = SonyProperty(code: code, dataType: type, getSet: getSet, enabled: enabled,
                                         current: current, enumValues: enums)
            }
            return (out, nil)
        } catch {
            return (out, "\(error)")
        }
    }

    static func encode(_ value: Int64, type: UInt16) -> Data {
        var d = Data()
        switch type {
        case 0x0001, 0x0002: d.appendLE(UInt8(truncatingIfNeeded: value))
        case 0x0003, 0x0004: d.appendLE(UInt16(truncatingIfNeeded: value))
        case 0x0005, 0x0006: d.appendLE(UInt32(truncatingIfNeeded: value))
        default: d.appendLE(UInt64(bitPattern: value))
        }
        return d
    }

    // MARK: Formattazione

    static func formatISO(_ v: Int64?) -> String {
        guard let v else { return "--" }
        let iso = v & 0xFF_FFFF
        return iso == 0xFF_FFFF ? "AUTO" : "\(iso)"
    }

    static func formatShutter(_ v: Int64?) -> String {
        guard let v else { return "--" }
        if v == 0 { return "BULB" }
        let num = (v >> 16) & 0xFFFF, den = v & 0xFFFF
        guard den != 0 else { return "--" }
        if num == 1 && den > 1 { return "1/\(den)" }
        if den == 1 { return "\(num)\"" }
        return String(format: "%.1f\"", Double(num) / Double(den))
    }

    static func formatAperture(_ v: Int64?) -> String {
        guard let v, v > 0, v < 0xFFFE else { return "--" }
        return String(format: "f/%.1f", Double(v) / 100)
    }

    static func formatEV(_ v: Int64?) -> String {
        guard let v else { return "--" }
        return String(format: "%+.1f EV", Double(Int16(truncatingIfNeeded: v)) / 1000)
    }

    static func formatMode(_ v: Int64?) -> String {
        guard let v else { return "--" }
        switch v {
        case 0x0001: return "M"
        case 0x0002: return "P"
        case 0x0003: return "A"
        case 0x0004: return "S"
        case 0x8000, 0x8001: return "AUTO"
        default: return String(format: "modo 0x%04X", v)
        }
    }
}
