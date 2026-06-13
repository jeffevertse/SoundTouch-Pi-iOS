import XCTest
@testable import SoundTouch_Pi

final class KeychainStoreTests: XCTestCase {

    func testSaveReadUpdateDelete() {
        let account = "unit_test_\(UUID().uuidString)"
        XCTAssertNil(KeychainStore.read(account))

        KeychainStore.save("token-abc", account: account)
        XCTAssertEqual(KeychainStore.read(account), "token-abc")

        KeychainStore.save("token-xyz", account: account)   // exercises the update path
        XCTAssertEqual(KeychainStore.read(account), "token-xyz")

        KeychainStore.delete(account)
        XCTAssertNil(KeychainStore.read(account))
    }

    func testForgetPinnedCertificateClearsPin() {
        PinningDelegate.forgetPinnedCertificate()
        XCTAssertFalse(PinningDelegate.hasPinnedCertificate)
    }
}
