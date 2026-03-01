// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QDI_Gemstone_ERP",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "QDI_Gemstone_ERP",
            path: "QDI_Gemstone_ERP",
            exclude: [
                "Assets.xcassets",
                "QDI_Gemstone_ERP.entitlements",
                ".cursor",
                "Views",
                "ViewModels",
                "Utilities",
                "ContentView.swift",
                "QDI_Gemstone_ERPApp.swift",
                "Services/RFIDService.swift",
                "Services/RFIDManager.swift",
                "Services/PDFService.swift",
                "Services/DemoDataManager.swift",
                "Services/DataSeeder.swift",
                "Services/HistoryLogger.swift",
            ],
            sources: [
                "Models/Gemstone.swift",
                "Models/Customer.swift",
                "Models/Memo.swift",
                "Models/Invoice.swift",
                "Models/LineItem.swift",
                "Models/HistoryEvent.swift",
                "Services/RFIDScanService.swift",
            ]
        ),
        .testTarget(
            name: "QDI_Gemstone_ERPTests",
            dependencies: ["QDI_Gemstone_ERP"],
            path: "QDI_Gemstone_ERPTests"
        ),
    ]
)
