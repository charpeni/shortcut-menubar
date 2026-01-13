import Foundation
import os
import Security

private let logger = Logger(subsystem: "com.charpeni.shortcut-menubar", category: "Storage")

/// Stores the API token securely in the macOS Keychain.
///
/// Uses `kSecAttrAccessibleWhenUnlocked` which:
/// - Encrypts the token at rest
/// - Allows access when the device is unlocked without prompting for password
/// - Is protected by the Secure Enclave on supported hardware
final class TokenStorage: @unchecked Sendable {
    static let shared = TokenStorage()

    private let service = "com.charpeni.shortcut-menubar"
    private let account = "api-token"
    private let lock = NSLock()

    /// Cached token to avoid repeated Keychain reads.
    private var cachedToken: String?

    private init() {
        // Migrate from file-based storage if needed
        migrateFromFileStorageIfNeeded()
    }

    // MARK: - Public API

    func saveAPIToken(_ token: String) -> Bool {
        lock.withLock {
            let result = saveToKeychain(token)
            if result {
                cachedToken = token
            }
            return result
        }
    }

    func getAPIToken() -> String? {
        lock.withLock {
            if let cached = cachedToken {
                return cached
            }

            if let token = readFromKeychain() {
                cachedToken = token
                return token
            }

            return nil
        }
    }

    @discardableResult
    func deleteAPIToken() -> Bool {
        lock.withLock {
            cachedToken = nil
            return deleteFromKeychain()
        }
    }

    var hasAPIToken: Bool {
        getAPIToken() != nil
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(_ token: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            logger.error("Failed to encode token as UTF-8")
            return false
        }

        // First, try to delete any existing item
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            logger.debug("Token saved to Keychain")
            return true
        } else {
            logger.error("Failed to save token to Keychain: \(status, privacy: .public)")
            return false
        }
    }

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            if status != errSecItemNotFound {
                logger.error("Failed to read token from Keychain: \(status, privacy: .public)")
            }
            return nil
        }

        return token
    }

    @discardableResult
    private func deleteFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.debug("Token deleted from Keychain")
            return true
        } else {
            logger.error("Failed to delete token from Keychain: \(status, privacy: .public)")
            return false
        }
    }

    // MARK: - Migration from File Storage

    private var legacyTokenFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("shortcut-menubar", isDirectory: true)
            .appendingPathComponent("api-token")
    }

    /// Migrates token from the old file-based storage to Keychain.
    /// This runs once on first launch after the update.
    private func migrateFromFileStorageIfNeeded() {
        guard let fileURL = legacyTokenFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        logger.info("Found legacy file-based token, migrating to Keychain...")

        do {
            let token = try String(contentsOf: fileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !token.isEmpty else {
                // Empty file, just delete it
                try? FileManager.default.removeItem(at: fileURL)
                return
            }

            // Save to Keychain
            if saveToKeychain(token) {
                // Securely delete the old file
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
                if fileSize > 0 {
                    let zeros = Data(repeating: 0, count: fileSize)
                    try zeros.write(to: fileURL)
                }
                try FileManager.default.removeItem(at: fileURL)

                // Also remove the directory if empty
                let directory = fileURL.deletingLastPathComponent()
                let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
                if contents?.isEmpty == true {
                    try? FileManager.default.removeItem(at: directory)
                }

                logger.info("Successfully migrated token to Keychain and removed legacy file")
            } else {
                logger.error("Failed to migrate token to Keychain, keeping legacy file")
            }
        } catch {
            logger.error("Failed to read legacy token file: \(error.localizedDescription, privacy: .public)")
        }
    }
}
