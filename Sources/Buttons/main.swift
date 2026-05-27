import Foundation

// Hidden CLI modes — run before SwiftUI takes over.
let args = CommandLine.arguments
if args.count >= 2 {
    switch args[1] {
    case "--check-json":
        let path = args.count >= 3 ? args[2] : ""
        ButtonsCLI.checkJSON(path: path)
        exit(0)
    case "--version":
        print("Buttons 0.1.0")
        exit(0)
    default:
        break
    }
}

ButtonsApp.main()
