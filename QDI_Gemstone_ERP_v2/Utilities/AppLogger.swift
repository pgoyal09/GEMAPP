import os

enum AppLogger {
    static let ui = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "ui")
    static let data = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "data")
    static let rfid = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "rfid")
    static let pdf = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "pdf")
    static let api = Logger(subsystem: "com.qualitydiajewels.QDI-Gemstone-ERP", category: "api")
}
