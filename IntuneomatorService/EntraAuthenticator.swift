//
//  EntraAuthenticator.swift
//  Intuneomator
//
//  Created by Gil Burns on 3/17/25.
//

import Foundation
import CommonCrypto

class EntraAuthenticator {
    
    // MARK: - Token Cache
    private var cachedToken: String?
    private var tokenExpiration: Date?
    
    private let logType = "EntraAuthenticator"
    
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
    func getEntraIDToken() async throws -> String {
        // Check if a valid token is cached
        if let token = cachedToken, let expiration = tokenExpiration, expiration > Date() {
            Logger.log("Returning cached Entra ID token.", logType: logType)
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
//            Logger.log("Using certificate-based authentication", logType: logType)
            newToken = try await authenticateWithCertificate(tenantId: tenantId, clientId: clientId)
        case "secret":
//            Logger.log("Using client secret-based authentication", logType: logType)
            newToken = try await authenticateWithSecretKey(tenantId: tenantId, clientId: clientId)
        default:
            Logger.log("Invalid authentication method: \(authMethod)", logType: logType)
            throw EntraAuthError.invalidConfiguration("Invalid authentication method: \(authMethod)")
        }
        
        // Cache the new token and expiration time
        cachedToken = newToken
        tokenExpiration = Date().addingTimeInterval(3500) // 3500 seconds (~58 min) for safety
        
        return newToken
    }
    
    // MARK: - Secret Key Based Auth
    func authenticateWithSecretKey(tenantId: String, clientId: String) async throws -> String {
        // Retrieve the secret key from the system keychain
        guard let secretKey = KeychainManager.retrieveEntraIDSecretKey() else {
            Logger.log("Failed to retrieve Entra ID secret key from keychain", logType: logType)
            throw EntraAuthError.keychainError(-1, "Secret key not found")
        }
        
//        Logger.log("authenticateWithSecretKey():", logType: logType)
//        Logger.log("tenantId: \(tenantId), clientId: \(clientId)", logType: logType)
        
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
            Logger.log("HTTP error: \(httpResponse.statusCode)", logType: logType)
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.log("Response: \(responseText)", logType: logType)
            }
            throw EntraAuthError.authenticationFailed("HTTP error: \(httpResponse.statusCode)")
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                Logger.log("Successfully obtained access token", logType: logType)
                return accessToken
            } else {
                throw EntraAuthError.authenticationFailed("Failed to retrieve access token from response")
            }
            
        } catch {
            Logger.log("JSON parsing error: \(error)", logType: logType)
            throw EntraAuthError.authenticationFailed("JSON parsing error")
        }
    }
    
    // MARK: - Certificate Based Auth
    func authenticateWithCertificate(tenantId: String, clientId: String) async throws -> String {
        
//        Logger.log("authenticateWithCertificate():", logType: logType)
//        Logger.log("tenantId: \(tenantId), clientId: \(clientId)", logType: logType)
        
        
        // 1. Get the private key from the keychain
        guard let privateKey = KeychainManager.getPrivateKeyFromKeychain() else {
            Logger.log("Failed to retrieve private key from keychain", logType: logType)
            throw EntraAuthError.privateKeyNotFound("Private key not found")
        }
        
        // 2. Get the certificate thumbprint from the saved plist
        let certificateManager = CertificateManager()
        guard let certInfo = certificateManager.loadCertificateInfoFromPlist() else {
            Logger.log("Failed to load certificate info", logType: logType)
            throw EntraAuthError.invalidConfiguration("Certificate info not found")
        }
        
        let thumbprint = certInfo.thumbprint
//        Logger.log("Using certificate with thumbprint: \(thumbprint)", logType: logType)
        
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
    
    
    // Helper function to create client assertion
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
            Logger.log("Failed to encode JWT parts", logType: logType)
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
            Logger.log("Failed to convert JWT to data", logType: logType)
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
                Logger.log("Signing error: \(error)", logType: logType)
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
    
    
    // Function to request Microsoft Graph token
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
            Logger.log("HTTP error: \(httpResponse.statusCode)", logType: logType)
            if let responseText = String(data: data, encoding: .utf8) {
                Logger.log("Response: \(responseText)", logType: logType)
            }
            throw EntraAuthError.authenticationFailed("HTTP error: \(httpResponse.statusCode)")
        }
        
        // Parse the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
//                Logger.log("Successfully obtained access token", logType: logType)
                return accessToken
            } else {
                throw EntraAuthError.authenticationFailed("Failed to retrieve access token from response")
            }
        } catch {
            Logger.log("JSON parsing error: \(error)", logType: logType)
            throw EntraAuthError.authenticationFailed("JSON parsing error")
        }
    }
    
// MARK: - Validate Credentials
    func ValidateCredentials() async throws -> Bool {
        do {
            // Step 1: Authenticate and get the token
            let authToken = try await self.getEntraIDToken()
            
            // Step 2: Decode the JWT and verify permissions
            let claims = try decodeJWT(authToken)
            if let roles = claims["roles"] as? [String], roles.contains("DeviceManagementApps.ReadWrite.All") {
                Logger.log("Token contains the required permission: DeviceManagementApps.ReadWrite.All", logType: logType)
            } else {
                throw NSError(domain: "GraphValidationError", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Token does not contain the required permission: DeviceManagementApps.ReadWrite.All"
                ])
            }
            
            // Step 3: Test the token with the Graph API
            try await validateGraphApiToken(authToken: authToken)
            
            return true
        } catch {
            Logger.log("Error validating credentials: \(error.localizedDescription)", logType: logType)
            return false
        }
    }
    
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
}

extension String {
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
