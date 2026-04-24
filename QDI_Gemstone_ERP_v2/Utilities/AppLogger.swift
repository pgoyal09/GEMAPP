import os

enum AppLogger {
    private static let subsystem = "com.qualitydiajewels.QDI-Gemstone-ERP"

    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let rfid = Logger(subsystem: subsystem, category: "rfid")
    static let pdf = Logger(subsystem: subsystem, category: "pdf")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let backup = Logger(subsystem: subsystem, category: "backup")
    static let reports = Logger(subsystem: subsystem, category: "reports")
}
