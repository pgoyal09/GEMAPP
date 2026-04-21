import SwiftData

/// Schema versioning for GemApp SwiftData models.
/// When adding/removing/changing model properties, create a new VersionedSchema
/// and add a SchemaMigrationPlan step.
enum GemAppSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Gemstone.self,
            Customer.self,
            Memo.self,
            Invoice.self,
            LineItem.self,
            LotTransaction.self,
            HistoryEvent.self,
            RFIDTag.self,
            Payment.self,
            PaymentReminder.self,
            BackupManifest.self,
            ReconciliationRecord.self,
        ]
    }
}

/// Migration plan: defines the ordered list of schemas and migration stages.
/// Currently only V1 exists (no migrations needed yet).
/// When V2 is created, add a MigrationStage here.
enum GemAppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GemAppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the only version.
        // Example for future V2:
        // migrateV1toV2
        []
    }

    // Example migration stage template:
    // static let migrateV1toV2 = MigrationStage.lightweight(
    //     fromVersion: GemAppSchemaV1.self,
    //     toVersion: GemAppSchemaV2.self
    // )
}
