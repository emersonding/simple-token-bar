import XCTest
@testable import TokenBarCore

final class KeychainManagerTests: XCTestCase {

    private let testKey = "tokenbar.test.keychainTests"
    private var km: KeychainManager!

    override func setUp() async throws {
        // Isolated service keeps tests from touching production keychain data
        km = KeychainManager(service: "com.tokenbar.tests")
        // Clean up any leftover item from a previous test run
        try await km.delete(key: testKey)
    }

    override func tearDown() async throws {
        try? await km.delete(key: testKey)
    }

    // MARK: - Round-trip

    func testSaveAndLoadReturnsSavedValue() async throws {
        try await km.save(key: testKey, value: "hello-keychain")
        let loaded = try await km.load(key: testKey)
        XCTAssertEqual(loaded, "hello-keychain")
    }

    func testSaveOverwritesPreviousValue() async throws {
        try await km.save(key: testKey, value: "first-value")
        try await km.save(key: testKey, value: "second-value")
        let loaded = try await km.load(key: testKey)
        XCTAssertEqual(loaded, "second-value")
    }

    // MARK: - Not found

    func testLoadNonexistentKeyThrowsItemNotFound() async throws {
        do {
            _ = try await km.load(key: testKey)
            XCTFail("Expected KeychainError.itemNotFound to be thrown")
        } catch KeychainError.itemNotFound {
            // expected
        } catch {
            XCTFail("Expected KeychainError.itemNotFound but got \(error)")
        }
    }

    // MARK: - Delete

    func testDeleteRemovesItemSoSubsequentLoadFails() async throws {
        try await km.save(key: testKey, value: "to-delete")
        try await km.delete(key: testKey)

        do {
            _ = try await km.load(key: testKey)
            XCTFail("Expected KeychainError.itemNotFound after delete")
        } catch KeychainError.itemNotFound {
            // expected
        } catch {
            XCTFail("Expected KeychainError.itemNotFound but got \(error)")
        }
    }

    func testDeleteNonexistentKeySucceedsWithoutThrowing() async throws {
        // delete() should not throw when the item does not exist
        try await km.delete(key: "nonexistent-\(UUID().uuidString)")
    }
}
