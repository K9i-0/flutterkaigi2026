// macOS Vision only; no network, Python package, or model download required.
import Foundation
import Vision
import ImageIO

let paths = CommandLine.arguments.dropFirst()
var rows = [[String: Any]]()
for path in paths {
    var row: [String: Any] = ["path": path]
    do {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(url: URL(fileURLWithPath: path)).perform([request])
        row["lines"] = (request.results ?? []).compactMap { observation -> [String: Any]? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let rect = observation.boundingBox
            return ["text": candidate.string, "confidence": candidate.confidence,
                    "bounds": [rect.minX, rect.minY, rect.width, rect.height]]
        }
    } catch {
        row["error"] = String(describing: error)
        row["lines"] = []
    }
    rows.append(row)
}
let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
