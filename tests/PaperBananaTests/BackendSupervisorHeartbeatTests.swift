import XCTest
@testable import PaperBanana

final class BackendSupervisorHeartbeatTests: XCTestCase {
    @MainActor
    func testHeartbeatMarksReachableBackendReadyWithSnapshotDetails() {
        let supervisor = BackendSupervisor(heartbeatInterval: 60)
        let configuration = PaperBananaSettingsSnapshot(
            repoPath: "/tmp/PaperBananaTests",
            serverPort: 8123,
            defaultImageModel: .nanoBanana2,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )

        supervisor.configureForTesting(configuration: configuration, state: .starting)
        supervisor.applyHeartbeatForTesting(
            reachable: true,
            managedProcessID: nil,
            managedProcessRunning: false,
            externalProcessID: 4242,
            date: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(supervisor.runtimeSnapshot.status, .ready)
        XCTAssertEqual(supervisor.runtimeSnapshot.port, 8123)
        XCTAssertEqual(supervisor.runtimeSnapshot.processID, 4242)
        XCTAssertEqual(supervisor.runtimeSnapshot.lastHeartbeatSucceeded, true)
        XCTAssertEqual(supervisor.runtimeSnapshot.lastHeartbeatMessage, "Backend responded on http://127.0.0.1:8123")
        XCTAssertEqual(supervisor.state, .ready(URL(string: "http://127.0.0.1:8123")!))
    }

    @MainActor
    func testHeartbeatFailsManagedProcessExitWhenBackendIsUnreachable() {
        let supervisor = BackendSupervisor(heartbeatInterval: 60)
        let configuration = PaperBananaSettingsSnapshot(
            repoPath: "/tmp/PaperBananaTests",
            serverPort: 8124,
            defaultImageModel: .nanoBanana2,
            codexModel: "gpt-5.5",
            codexReasoning: "xhigh",
            googleAPIKey: "",
            openRouterAPIKey: ""
        )

        supervisor.configureForTesting(configuration: configuration, state: .starting)
        supervisor.applyHeartbeatForTesting(
            reachable: false,
            managedProcessID: 9001,
            managedProcessRunning: false,
            externalProcessID: nil,
            date: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(supervisor.runtimeSnapshot.status, .failed)
        XCTAssertEqual(supervisor.runtimeSnapshot.processID, 9001)
        XCTAssertEqual(supervisor.runtimeSnapshot.lastHeartbeatSucceeded, false)
        XCTAssertEqual(supervisor.runtimeSnapshot.lastHeartbeatMessage, "Managed backend process 9001 is not running and port 8124 is unreachable.")

        guard case .failed(let message) = supervisor.state else {
            return XCTFail("Expected failed state, got \(supervisor.state)")
        }
        XCTAssertTrue(message.contains("Managed backend process 9001 is not running"))
    }
}
