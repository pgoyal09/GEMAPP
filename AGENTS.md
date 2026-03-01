# AGENTS.md

## Cursor Cloud specific instructions

### Overview

QDI Gemstone ERP is a native macOS SwiftUI desktop application. A `Package.swift` enables cross-platform compilation of the core business logic (models + RFID services) and test execution on Linux via Swift Package Manager.

### What works on the Cloud VM (Linux)

| Command | Purpose |
|---|---|
| `swift build` | Compiles core library (models + RFID scan logic) |
| `swift test` | Runs all 11 unit tests (RFID identity, assignment conflict, workflow) |
| `swiftlint lint QDI_Gemstone_ERP QDI_Gemstone_ERPTests` | Lints all 59 Swift files (pass paths to avoid linting `.build/`) |
| `swiftc -parse <file.swift>` | Validates Swift syntax for any individual file |

- Swift 6.0.3 is installed at `/opt/swift/usr/bin` (added to PATH via `~/.bashrc`).
- SwiftLint 0.63.2 is installed at `/usr/local/bin/swiftlint`.
- No `.swiftlint.yml` config exists; default rules apply (527 pre-existing violations).

### Cross-platform architecture

Model files use `#if canImport(SwiftData)` guards so that:
- **macOS + Xcode**: `@Model`, `@Relationship`, `@Attribute` are applied normally. The `.xcodeproj` is unaffected by `Package.swift`.
- **Linux + SPM**: Classes compile as plain Swift classes. Persistence methods in `RFIDScanService` are excluded. Tests run against pure business logic.

The SPM library target (`QDI_Gemstone_ERP`) includes only `Models/*.swift` and `Services/RFIDScanService.swift`. All SwiftUI Views, ViewModels, and macOS-only services are excluded.

### What does NOT work on Linux

- Running the GUI app (requires macOS + SwiftUI runtime)
- SwiftData persistence methods (guarded behind `#if canImport(SwiftData)`)
- macOS-only services: `RFIDManager`, `RFIDService`, `PDFService`, `DemoDataManager`

### Development on macOS

On a Mac with Xcode 15+:
- Open `QDI_Gemstone_ERP.xcodeproj` (not `Package.swift`) to get the full app
- Build and run: Cmd+R (targets macOS 14.0+)
- Run tests: Cmd+U
- ORSSerialPort SPM dependency resolves automatically on first build
