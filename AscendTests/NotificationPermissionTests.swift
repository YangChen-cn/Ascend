import XCTest
import SwiftData
import UserNotifications
@testable import Ascend

final class NotificationPermissionTests: XCTestCase {
    func testNotificationPermissionSnapshotAuthorizedAndProvisional() {
        let authorizedSnapshot = NotificationPermissionSnapshot(
            authorizationStatus: .authorized,
            alertSetting: .enabled,
            soundSetting: .enabled,
            notificationCenterSetting: .enabled
        )
        XCTAssertTrue(authorizedSnapshot.isAuthorizedOrProvisional)
        XCTAssertEqual(authorizedSnapshot.authorizationStatus, .authorized)
        XCTAssertEqual(authorizedSnapshot.alertSetting, .enabled)
        XCTAssertEqual(authorizedSnapshot.soundSetting, .enabled)
        XCTAssertEqual(authorizedSnapshot.notificationCenterSetting, .enabled)

        let provisionalSnapshot = NotificationPermissionSnapshot(
            authorizationStatus: .provisional,
            alertSetting: .disabled,
            soundSetting: .disabled,
            notificationCenterSetting: .enabled
        )
        XCTAssertTrue(provisionalSnapshot.isAuthorizedOrProvisional)
    }

    func testNotificationPermissionSnapshotDeniedAndNotDetermined() {
        let notDeterminedSnapshot = NotificationPermissionSnapshot(
            authorizationStatus: .notDetermined,
            alertSetting: .notSupported,
            soundSetting: .notSupported,
            notificationCenterSetting: .notSupported
        )
        XCTAssertFalse(notDeterminedSnapshot.isAuthorizedOrProvisional)

        let deniedSnapshot = NotificationPermissionSnapshot(
            authorizationStatus: .denied,
            alertSetting: .disabled,
            soundSetting: .disabled,
            notificationCenterSetting: .disabled
        )
        XCTAssertFalse(deniedSnapshot.isAuthorizedOrProvisional)
    }

    func testSchedulerErrorDescriptions() {
        let notDeterminedError = DigestScheduler.SchedulerError.notDetermined
        XCTAssertEqual(
            notDeterminedError.errorDescription,
            "尚未请求系统通知权限，请先开启通知"
        )

        let deniedError = DigestScheduler.SchedulerError.notificationDenied
        XCTAssertEqual(
            deniedError.errorDescription,
            "通知已被系统拒绝，请前往系统设置开启"
        )

        let systemError = DigestScheduler.SchedulerError.systemError("Disk full")
        XCTAssertEqual(
            systemError.errorDescription,
            "通知配置失败：Disk full"
        )
    }

    @MainActor
    func testAppStateNotificationPermissionSnapshotReturnsRealState() async throws {
        let schema = Schema(AscendSchemaV8.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let appState = AppState(modelContainer: container)

        let snapshot = await appState.notificationPermissionSnapshot()
        let authStatus = await appState.checkNotificationAuthorizationStatus()
        XCTAssertEqual(snapshot.authorizationStatus, authStatus)
    }
}
