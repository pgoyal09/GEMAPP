# AGENTS.md

## Cursor Cloud specific instructions

### Platform constraint

This is a **native macOS SwiftUI application** (Xcode project). It **cannot be built, run, or tested on Linux**. The app requires:

- **macOS 14.0+** (Sonoma) with **Xcode 15+**
- Apple frameworks: SwiftUI, SwiftData, `os` (Logger)
- SPM dependency: ORSSerialPort (fetched automatically by Xcode)

There is no `Package.swift` — the project is an `.xcodeproj` only.

### What works on the Cloud VM (Linux)

| Tool | Command | Purpose |
|---|---|---|
| **SwiftLint** | `swiftlint lint` (from repo root) | Lints all 59 Swift files |
| **Swift syntax check** | `swiftc -parse <file.swift>` | Validates Swift syntax (no semantic/type checking) |

- Swift 6.0.3 is installed at `/opt/swift/usr/bin` (added to PATH via `~/.bashrc`).
- SwiftLint 0.63.2 is installed at `/usr/local/bin/swiftlint`.
- No `.swiftlint.yml` config exists in the repo; default rules apply.

### What does NOT work on the Cloud VM

- `xcodebuild` / `swift build` — macOS SDK and Apple frameworks are unavailable.
- Running the app — requires macOS GUI + SwiftUI runtime.
- Running XCTest tests — tests import `@testable import QDI_Gemstone_ERP` which depends on SwiftData/SwiftUI.

### Project structure (quick reference)

- `QDI_Gemstone_ERP/` — main app source (Models, Views, ViewModels, Services, Utilities)
- `QDI_Gemstone_ERPTests/` — XCTest tests (RFID identity, assignment conflict, workflow logic)
- `QDI_Gemstone_ERP.xcodeproj/` — Xcode project file
- `prd.md` — product requirements document
- `CODEBASE_REVIEW.md` — architecture review notes

### Development on macOS

On a real Mac with Xcode installed:
- Open `QDI_Gemstone_ERP.xcodeproj` in Xcode
- Build and run: Cmd+R (targets macOS 14.0+)
- Run tests: Cmd+U
- ORSSerialPort SPM dependency resolves automatically on first build
