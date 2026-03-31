import Foundation
import SwiftData

@Model
final class BackupManifest {
    @Attribute(.unique) var backupId: String = UUID().uuidString
    var createdAt: Date = Date()
    var deviceName: String = ""
    var stoneCount: Int = 0
    var customerCount: Int = 0
    var memoCount: Int = 0
    var invoiceCount: Int = 0
    var fileSize: Int64 = 0
    var isEncrypted: Bool = true
    var iCloudPath: String = ""

    init(
        deviceName: String,
        stoneCount: Int,
        customerCount: Int,
        memoCount: Int,
        invoiceCount: Int,
        fileSize: Int64,
        isEncrypted: Bool,
        iCloudPath: String
    ) {
        self.backupId = UUID().uuidString
        self.createdAt = Date()
        self.deviceName = deviceName
        self.stoneCount = stoneCount
        self.customerCount = customerCount
        self.memoCount = memoCount
        self.invoiceCount = invoiceCount
        self.fileSize = fileSize
        self.isEncrypted = isEncrypted
        self.iCloudPath = iCloudPath
    }
}
