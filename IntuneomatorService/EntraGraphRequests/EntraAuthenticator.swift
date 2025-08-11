//
//  EntraAuthenticator.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation
import CommonCrypto

/// Handles Microsoft Entra ID authentication for accessing Microsoft Graph API
/// Supports both certificate-based and client secret authentication methods with token caching
class EntraAuthenticator {
    
    // MARK: - Singleton
    /// Shared singleton instance to maintain token cache across all operations
    static let shared = EntraAuthenticator()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    // MARK: - Token Cache
    /// Cached access token to avoid unnecessary authentication requests
    private var cachedToken: String?
    
    /// Expiration date of the cached token
    private var tokenExpiration: Date?
    
    
    /// Custom error types for Entra ID authentication operations
    enum EntraAuthError: Error, LocalizedError {
        case keychainError(OSStatus, String)
        case privateKeyNotFound(String)
        case signatureCreationFailed(String)
        case authenticationFailed(String)
        case invalidConfiguration(String)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .keychainError(let status, let message):
                return "Keychain error (\(status)): \(message)"
            case .privateKeyNotFound(let reason):
                return "Private key not found: \(reason)"
            case .signatureCreationFailed(let reason):
                return "Failed to create signature: \(reason)"
            case .authenticationFailed(let reason):
                return "Authentication failed: \(reason)"
            case .invalidConfiguration(let reason):
                return "Invalid configuration: \(reason)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Get Entra ID Token
    
    /// Retrieves a valid Entra ID access token, using cached token if available and not expired
    /// - Returns: Valid access token for Microsoft Graph API
    /// - Throws: EntraAuthError for various authentication failures
    func getEntraIDToken() async throws -> String {
        // Check if a valid token is cached
        if let token = cachedToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }

        // Otherwise, request a new token
        let tenantId = ConfigManager.readPlistValue(key: "TenantID") ?? ""
        let clientId = ConfigManager.readPlistValue(key: "ApplicationID") ?? ""
        let authMethod = ConfigManager.readPlistValue(key: "AuthMethod") ?? ""
        
        // Validate configuration
        guard !tenantId.isEmpty else {
            throw EntraAuthError.invalidConfiguration("Tenant ID is empty")
        }
        
        guard !clientId.isEmpty else {
            throw EntraAuthError.invalidConfiguration("Client ID is empty")
        }
        
        guard !authMethod.isEmpty else {
            throw EntraAuthError.invalidConfiguration("Auth Method is empty")
        }
        
        // Authenticate and return token
        var newToken: String
        switch authMethod {
        case "certificate":
            newToken = try await authenticateWithCertificate(tenantId: tenantId, clientId: clientId)
        case "secret":
            newToken = try await authenticateWithSecretKey(tenantId: tenantId, clientId: clientId)
        default:
            Logger.info("Invalid authentication method: \(authMethod)", category: .core)
            throw EntraAuthError.invalidConfiguration("Invalid authentication method: \(authMethod)")
        }
        
        // Cache the new token and expiration time
        cachedToken = newToken
        tokenExpiration = Date().addingTimeInterval(3500) // 3500 seconds (~58 min) for safety
        
        return newToken
    }
    
    // MARK: - Secret Key Based Auth
    
    /// Authenticates using client secret stored in keychain
    /// - Parameters:
    ///   - tenantId: Azure AD tenant identifier
    ///   - clientId: Application (client) ID from Azure AD app registration
    /// - Returns: Access token for Microsoft Graph API
    /// - Throws: EntraAuthError for authentication failures
    func authenticateWithSecretKey(tenantId: String, clientId: String) async throws -> String {
        // Retrieve the secret key from the system keychain
        guard let secretKey = KeychainManager.retrieveEntraIDSecretKey() else {
            Logger.error("Failed to retrieve Entra ID secret key from keychain", category: .core)
            throw EntraAuthError.keychainError(-1, "Secret key not found")
        }
                
        let tokenUrl = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Form parameters for client secret authentication
        let formData = [
            "client_id": clientId,
            "client_secret": secretKey,
            "scope": "https://graph.microsoft.com/.default",
            "grant_type": "client_credentials"
        ]
        
        let formString = formData.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            Logger.error("HTTP error: \(httpResponse.statusCode)", category: .core)
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.info("Response: \(responseText)", category: .core)
            }
            throw EntraAuthError.authenticationFailed("HTTP error: \(httpResponse.statusCode)")
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
//                Logger.info("Successfully obtained access token", category: .core)
                return accessToken
            } else {
                throw EntraAuthError.authenticationFailed("Failed to retrieve access token from response")
            }
            
        } catch {
            Logger.error("JSON parsing error: \(error)", category: .core)
            throw EntraAuthError.authenticationFailed("JSON parsing error")
        }
    }
    
    // MARK: - Certificate Based Auth
    
    /// Authenticates using certificate-based authentication with JWT client assertion
    /// - Parameters:
    ///   - tenantId: Azure AD tenant identifier
    ///   - clientId: Application (client) ID from Azure AD app registration
    /// - Returns: Access token for Microsoft Graph API
    /// - Throws: EntraAuthError for authentication failures
    func authenticateWithCertificate(tenantId: String, clientId: String) async throws -> String {
        
//        Logger.info("authenticateWithCertificate():", category: .core)
//        Logger.info("tenantId: \(tenantId, category: .core), clientId: \(clientId)", logType: logType)
        
        
        // 1. Get the private key from the keychain
        guard let privateKey = KeychainManager.getPrivateKeyFromKeychain() else {
            Logger.error("Failed to retrieve private key from keychain", category: .core)
            throw EntraAuthError.privateKeyNotFound("Private key not found")
        }
        
        // 2. Get the certificate thumbprint from the saved plist
        let certificateManager = CertificateManager()
        guard let certInfo = certificateManager.loadCertificateInfoFromPlist() else {
            Logger.error("Failed to load certificate info", category: .core)
            throw EntraAuthError.invalidConfiguration("Certificate info not found")
        }
        
        let thumbprint = certInfo.thumbprint
//        Logger.info("Using certificate with thumbprint: \(thumbprint)", category: .core)
        
        // 3. Create JWT assertion for authentication
        let assertion = createClientAssertion(
            clientId: clientId,
            tenantId: tenantId,
            privateKey: privateKey,
            thumbprint: thumbprint
        )
        
        // 4. Request access token using the assertion
        return try await requestMicrosoftGraphToken(
            clientId: clientId,
            tenantId: tenantId,
            assertion: assertion
        )
    }
    
    
    /// Creates a JWT client assertion for certificate-based authentication
    /// - Parameters:
    ///   - clientId: Application (client) ID
    ///   - tenantId: Azure AD tenant identifier
    ///   - privateKey: Private key for signing the JWT
    ///   - thumbprint: Certificate thumbprint for x5t header claim
    /// - Returns: Signed JWT assertion string
    func createClientAssertion(clientId: String, tenantId: String, privateKey: SecKey, thumbprint: String) -> String {
        // Create JWT header
        let header = [
            "alg": "RS256",
            "typ": "JWT",
            "x5t": thumbprint.replacingOccurrences(of: " ", with: "")
                .fromBase16ToBase64URLSafe()
        ]
        
        // Current time and expiration (1 hour from now)
        let now = Int(Date().timeIntervalSince1970)
        let exp = now + 3600
        
        // Create JWT payload
        let payload = [
            "aud": "https://login.microsoftonline.com/\(tenantId)/oauth2/token",
            "exp": exp,
            "iss": clientId,
            "jti": UUID().uuidString,
            "nbf": now,
            "sub": clientId
        ] as [String : Any]
        
        // Encode header and payload
        guard let headerJson = try? JSONSerialization.data(withJSONObject: header),
              let payloadJson = try? JSONSerialization.data(withJSONObject: payload) else {
            Logger.error("Failed to encode JWT parts", category: .core)
            return ""
        }
        
        let encodedHeader = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let encodedPayload = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Create the data to sign (header.payload)
        let headerAndPayload = "\(encodedHeader).\(encodedPayload)"
        
        // Sign the data
        guard let dataToSign = headerAndPayload.data(using: .utf8) else {
            Logger.error("Failed to convert JWT to data", category: .core)
            return ""
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            dataToSign as CFData,
            &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() {
                Logger.error("Signing error: \(error)", category: .core)
            }
            return ""
        }
        
        // Encode the signature (URL-safe base64)
        let encodedSignature = signature.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Return the complete JWT
        return "\(headerAndPayload).\(encodedSignature)"
    }
    
    
    /// Requests an access token from Microsoft using the JWT client assertion
    /// - Parameters:
    ///   - clientId: Application (client) ID
    ///   - tenantId: Azure AD tenant identifier
    ///   - assertion: Signed JWT client assertion
    /// - Returns: Access token for Microsoft Graph API
    /// - Throws: EntraAuthError for request failures
    func requestMicrosoftGraphToken(clientId: String, tenantId: String, assertion: String) async throws -> String {
        // Create URL for token request
        let tokenUrl = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        
        // Create request
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create form data
        let formData = [
            "client_id": clientId,
            "scope": "https://graph.microsoft.com/.default",
            "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            "client_assertion": assertion,
            "grant_type": "client_credentials"
        ]
        
        let formString = formData.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            Logger.error("HTTP error: \(httpResponse.statusCode)", category: .core)
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.info("Response: \(responseText)", category: .core)
            }
            throw EntraAuthError.authenticationFailed("HTTP error: \(httpResponse.statusCode)")
        }
        
        // Parse the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
//                Logger.info("Successfully obtained access token", category: .core)
                return accessToken
            } else {
                throw EntraAuthError.authenticationFailed("Failed to retrieve access token from response")
            }
        } catch {
            Logger.error("JSON parsing error: \(error)", category: .core)
            throw EntraAuthError.authenticationFailed("JSON parsing error")
        }
    }
    
    // MARK: - Test Methods
    
    /// Tests authentication with provided credentials without affecting cached tokens
    /// - Parameters:
    ///   - tenantId: Azure AD tenant identifier
    ///   - clientId: Application (client) ID
    ///   - authMethod: Authentication method ("certificate" or "secret")
    ///   - clientSecret: Client secret (required if authMethod is "secret")
    /// - Returns: True if authentication succeeds
    func testAuthentication(tenantId: String, clientId: String, authMethod: String, clientSecret: String? = nil) async -> Bool {
        do {
            var token: String
            
            switch authMethod {
            case "certificate":
                token = try await authenticateWithCertificate(tenantId: tenantId, clientId: clientId)
            case "secret":
                guard let secret = clientSecret else {
                    Logger.error("Client secret required for secret authentication", category: .core)
                    return false
                }
                token = try await testAuthenticateWithSecretKey(tenantId: tenantId, clientId: clientId, clientSecret: secret)
            default:
                Logger.error("Invalid authentication method: \(authMethod)", category: .core)
                return false
            }
            
            return !token.isEmpty
        } catch {
            Logger.error("Test authentication failed: \(error.localizedDescription)", category: .core)
            return false
        }
    }
    
    /// Test version of authenticateWithSecretKey that accepts a secret parameter
    /// - Parameters:
    ///   - tenantId: Azure AD tenant identifier
    ///   - clientId: Application (client) ID from Azure AD app registration
    ///   - clientSecret: Client secret to test with
    /// - Returns: Access token for Microsoft Graph API
    /// - Throws: EntraAuthError for authentication failures
    private func testAuthenticateWithSecretKey(tenantId: String, clientId: String, clientSecret: String) async throws -> String {
        let tokenUrl = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Form parameters for client secret authentication
        let formData = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "scope": "https://graph.microsoft.com/.default",
            "grant_type": "client_credentials"
        ]
        
        let formString = formData.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            Logger.error("HTTP error: \(httpResponse.statusCode)", category: .core)
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.info("Response: \(responseText)", category: .core)
            }
            throw EntraAuthError.authenticationFailed("HTTP error: \(httpResponse.statusCode)")
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                return accessToken
            } else {
                throw EntraAuthError.authenticationFailed("Failed to retrieve access token from response")
            }
            
        } catch {
            Logger.error("JSON parsing error: \(error)", category: .core)
            throw EntraAuthError.authenticationFailed("JSON parsing error")
        }
    }
    
    // MARK: - Validate Credentials
    
    /// Validates that the configured credentials can successfully authenticate and have required permissions
    /// - Returns: True if credentials are valid and have DeviceManagementApps.ReadWrite.All permission
    /// - Throws: Various errors for validation failures
    func ValidateCredentials() async throws -> Bool {
        do {
            // Step 1: Authenticate and get the token
            let authToken = try await self.getEntraIDToken()

            // Step 2: Decode the JWT and verify permissions
            let claims = try decodeJWT(authToken)
            let requiredPermissions = [
                "DeviceManagementApps.ReadWrite.All",
                "DeviceManagementConfiguration.ReadWrite.All",
                "DeviceManagementManagedDevices.Read.All",
                //"DeviceManagementScripts.ReadWrite.All", // Add later when Script Management is added.
                "Group.Read.All"
            ]

            if let roles = claims["roles"] as? [String] {
                let grantedRoles = Set(roles)
                let (satisfiedPermissions, missingSummary) = validatePermissions(required: requiredPermissions, granted: grantedRoles)
                
                if satisfiedPermissions.count == requiredPermissions.count {
                    Logger.info("All required permissions satisfied: \(satisfiedPermissions)", category: .core)
                } else {
                    Logger.error("Missing required permissions: \(missingSummary)", category: .core)
                    throw NSError(domain: "GraphValidationError", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Token does not contain sufficient permissions. \(missingSummary)"
                    ])
                }
            } else {
                throw NSError(domain: "GraphValidationError", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Token does not contain a roles claim or is malformed."
                ])
            }

            // Step 3: Test the token with the Graph API
            try await validateGraphApiToken(authToken: authToken)

            return true
        } catch {
            Logger.error("Error validating credentials: \(error.localizedDescription)", category: .core)
            return false
        }
    }
    
    /// Tests the access token by making a request to Microsoft Graph API
    /// - Parameter authToken: Access token to validate
    /// - Throws: NSError if the token is invalid or API request fails
    private func validateGraphApiToken(authToken: String) async throws {
        let url = URL(string: "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseData = String(data: data, encoding: .utf8) ?? "No response data"
            throw NSError(domain: "GraphValidationError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to validate token with Graph API. Response: \(responseData)"
            ])
        }
    }

    
    /// Decodes a JWT token to extract claims without signature verification
    /// - Parameter token: JWT token string
    /// - Returns: Dictionary containing JWT payload claims
    /// - Throws: NSError for JWT parsing failures
    private func decodeJWT(_ token: String) throws -> [String: Any] {
        // Split the token into its parts (header, payload, signature)
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw NSError(domain: "JWTError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JWT structure."])
        }
        
        // Decode the payload (second part) from Base64URL
        let payload = parts[1]
        var base64 = String(payload)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let payloadData = Data(base64Encoded: base64) else {
            throw NSError(domain: "JWTError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JWT payload."])
        }
        
        // Parse the payload as JSON
        guard let json = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
            throw NSError(domain: "JWTError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JWT payload."])
        }
        
        return json
    }
    
    // MARK: - Permission Validation Helper
    
    /// Validates that granted permissions satisfy required permissions, accounting for over-permissions
    /// - Parameters:
    ///   - required: Array of required permission strings
    ///   - granted: Set of granted permission strings from the JWT token
    /// - Returns: Tuple containing (satisfied permissions array, missing permissions summary string)
    private func validatePermissions(required: [String], granted: Set<String>) -> ([String], String) {
        var satisfiedPermissions: [String] = []
        var missingPermissions: [String] = []
        
        for requiredPermission in required {
            if isPermissionSatisfied(required: requiredPermission, granted: granted) {
                satisfiedPermissions.append(requiredPermission)
            } else {
                missingPermissions.append(requiredPermission)
            }
        }
        
        let missingSummary = missingPermissions.isEmpty ? 
            "All permissions satisfied" : 
            "Missing: \(missingPermissions.joined(separator: ", "))"
        
        return (satisfiedPermissions, missingSummary)
    }
    
    /// Checks if a specific required permission is satisfied by any of the granted permissions
    /// Handles over-permissions where ReadWrite.All satisfies Read.All requirements
    /// - Parameters:
    ///   - required: The required permission string
    ///   - granted: Set of all granted permissions
    /// - Returns: True if the requirement is satisfied by any granted permission
    private func isPermissionSatisfied(required: String, granted: Set<String>) -> Bool {
        // Direct match
        if granted.contains(required) {
            return true
        }
        
        // Check for over-permissions (ReadWrite.All satisfies Read.All)
        if required.hasSuffix(".Read.All") {
            let basePermission = String(required.dropLast(9)) // Remove ".Read.All"
            let writePermission = basePermission + ".ReadWrite.All"
            if granted.contains(writePermission) {
                Logger.info("Permission '\(required)' satisfied by higher permission '\(writePermission)'", category: .core)
                return true
            }
        }
        
        // Special case: Check for broad permissions that might cover specific ones
        // For example, "Application.ReadWrite.All" might cover more specific app permissions
        let permissionComponents = required.split(separator: ".")
        if permissionComponents.count >= 3 {
            let resource = permissionComponents[0] // e.g., "DeviceManagementApps"
            
            // Look for broader permissions on the same resource
            for grantedPermission in granted {
                let grantedComponents = grantedPermission.split(separator: ".")
                if grantedComponents.count >= 3 &&
                   grantedComponents[0] == resource && // Same resource
                   grantedPermission.hasSuffix(".ReadWrite.All") && // Broader write permission
                   (required.hasSuffix(".Read.All") || required.hasSuffix(".ReadWrite.All")) {
                    Logger.info("Permission '\(required)' satisfied by broader permission '\(grantedPermission)'", category: .core)
                    return true
                }
            }
        }
        
        return false
    }
}

extension String {
    /// Converts a hexadecimal string to Base64URL-safe encoding
    /// Used for converting certificate thumbprints to the x5t JWT header format
    /// - Returns: Base64URL-encoded string
    func fromBase16ToBase64URLSafe() -> String {
        // Convert from hex string to data
        var data = Data()
        var hex = self
        
        // Ensure even number of characters
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }
        
        // Convert pairs of hex digits to bytes
        var index = hex.startIndex
        while index < hex.endIndex {
            let byteString = String(hex[index..<hex.index(index, offsetBy: 2)])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = hex.index(index, offsetBy: 2)
        }
        
        // Convert to base64url encoding
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
