import Foundation

enum ButtonsCLI {
    static func checkJSON(path: String) {
        guard !path.isEmpty else {
            FileHandle.standardError.write(Data("usage: Buttons --check-json <path-to-json>\n".utf8))
            exit(2)
        }
        let url = URL(fileURLWithPath: path)
        do {
            let result = try BTTJSONImporter().read(from: url)
            print("Imported triggers: \(result.triggers.count)")
            for (i, t) in result.triggers.enumerated() {
                print("  [\(i)] name=\"\(t.name)\"")
                print("        input:  \(t.input.summary)")
                print("        action: \(t.action.summary)")
            }
            if !result.skipped.isEmpty {
                print("Skipped: \(result.skipped.count)")
                for s in result.skipped {
                    print("  - \(s.title): \(s.reason)")
                }
            }
        } catch {
            FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
