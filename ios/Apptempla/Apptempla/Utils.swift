import Foundation

func prettyPrint(_ value: Encodable) -> String {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = .prettyPrinted
    if let output = try? jsonEncoder.encode(value) {
        return String(decoding: output, as: UTF8.self)
    } else {
        return ""
    }
}
