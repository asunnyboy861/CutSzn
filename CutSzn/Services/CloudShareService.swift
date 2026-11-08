import Foundation
import CloudKit
import UIKit
import SwiftUI

final class CloudShareService {
    static let shared = CloudShareService()
    private let container = CKContainer(identifier: "iCloud.com.zzoutuo.CutSzn")
    private var database: CKDatabase { container.privateCloudDatabase }

    func accountAvailable() async -> Bool {
        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
        return status == .available
    }

    func makeTeamShare(athleteName: String, statusText: String, usgText: String) async throws -> URL {
        let zoneID = CKRecordZone.ID(zoneName: "CutSznTeam", ownerName: CKCurrentUserDefaultName)
        _ = try? await database.save(CKRecordZone(zoneID: zoneID))

        let recordID = CKRecord.ID(recordName: "athlete-\(UUID().uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "AthleteSnapshot", recordID: recordID)
        record["athleteName"] = athleteName as CKRecordValue
        record["status"] = statusText as CKRecordValue
        record["usg"] = usgText as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "\(athleteName) — CutSzn" as CKRecordValue
        share.publicPermission = .readOnly
        let saved = try await database.save(share)

        guard let savedShare = saved as? CKShare, let url = savedShare.url else {
            throw NSError(domain: "CloudShare", code: 1, userInfo: [NSLocalizedDescriptionKey: "Share link unavailable."])
        }
        return url
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
