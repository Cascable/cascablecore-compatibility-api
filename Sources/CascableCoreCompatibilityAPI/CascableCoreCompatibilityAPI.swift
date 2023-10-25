import Foundation

extension URL {
    /// Generate a URL for calling the CascableCore Camera Compatibility API with the given API key and
    ///
    /// - Parameters:
    ///   - apiKey: Your API key.
    ///   - highestCascableCoreVersion: The highest version of CascableCore you have access to. Will filter out cameras
    ///                                 introduced after this version. Optional.
    /// - Returns: Returns a URL you can use to call the API.
    public static func cascableCoreCompatibilityAPI(apiKey: String, highestCascableCoreVersion: CascableCoreVersion? = nil) -> URL {
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "auth", value: apiKey))
        queryItems.append(URLQueryItem(name: "max-version", value: highestCascableCoreVersion?.strictDisplayValue))

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "compatibility.cascable.se"
        urlComponents.path = "/api/v1/supported-cameras"
        urlComponents.queryItems = queryItems

        return urlComponents.url!
    }
}

/// A CascableCore version, semver-compatible [major.minor.bugfix].
public struct CascableCoreVersion: Hashable, Comparable, CustomStringConvertible {

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.major < rhs.major { return true }
        if lhs.major == rhs.major && lhs.minor < rhs.minor { return true }
        if lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.bugFix < rhs.bugFix { return true }
        return false
    }

    /// The major version component (the '5' in `5.2.1`).
    public let major: Int

    /// The minor version component (the '2' in `5.2.1`).
    public let minor: Int

    /// The bugfix version component (the '1' in `5.2.1`).
    public let bugFix: Int

    /// Create a version object from the given components.
    ///
    /// - Parameters:
    ///   - major: The major version number.
    ///   - minor: The minor version number.
    ///   - bugFix: The bugfix version number.
    public init(_ major: Int, _ minor: Int, _ bugFix: Int = 0) {
        self.major = major
        self.minor = minor
        self.bugFix = bugFix
    }

    /// Attempt to create a version object from the given string representation.
    ///
    /// - Parameter stringValue: The string representation. Must be in the form "[major].[minor]" or
    ///                          "[major].[minor].[bugfix]", where each component is an integer.
    ///
    /// - Returns: Returns the version object, or `nil` if the string representation isn't valid.
    public init(stringValue: String) throws {
        let split = stringValue.split(separator: ".")
        guard (1...3).contains(split.count), let major = Int(split[0]) else { throw DecodingError.invalidVersionString }

        self.major = major

        if split.count > 1 {
            guard let minor = Int(split[1]) else { throw DecodingError.invalidVersionString }
            self.minor = minor
        } else {
            self.minor = 0
        }

        if split.count > 2 {
            guard let bugFix = Int(split[2]) else { throw DecodingError.invalidVersionString }
            self.bugFix = bugFix
        } else {
            self.bugFix = 0
        }
    }

    /// Returns a display-appropriate string representation of the version (equivalent to the `displayValue` property).
    public var description: String {
        return displayValue
    }

    /// Returns a display-appropriate string representation of the version. Will drop the bugfix version if it's zero
    /// (so version 5.0.0 will return "5.0").
    var displayValue: String {
        if bugFix > 0 { return "\(major).\(minor).\(bugFix)" }
        return "\(major).\(minor)"
    }

    /// Returns a "strict" display-appropriate string representation of the version. Will always include all
    /// components (so version 5.0.0 will return "5.0.0").
    var strictDisplayValue: String {
        return "\(major).\(minor).\(bugFix)"
    }
}

/// A supported camera.
public struct CascableCoreSupportedCamera: Hashable, CustomStringConvertible {

    /// Manually initialise a camera object with the given values.
    public init(modelName: String, manufacturer: String,
         additionalSearchTerms: [String]? = nil,
         cascableCoreVersionsRequired: [ConnectionMethod: CascableCoreVersion],
         features: Set<Feature>,
         connectionSpecificFeatures: [ConnectionMethod: Set<Feature>] = [:]) {

        self.modelName = modelName
        self.manufacturer = manufacturer
        self.additionalSearchTerms = additionalSearchTerms
        self.cascableCoreVersionsRequired = cascableCoreVersionsRequired
        self.features = features
        self.connectionSpecificFeatures = connectionSpecificFeatures
    }

    /// A basic description of the camera.
    public var description: String { return "\(manufacturer) \(modelName)" }

    /// The camera's model name (The 'EOS R5' in 'Canon EOS R5').
    public let modelName: String

    /// The manufacturer name.
    public let manufacturer: String

    /// Additional search terms users might enter for the camera. May include things like model identifiers
    /// (like 'ILCE-7RM3') or easier-to-type model names (like 'a7' for α7 cameras) etc. Optional.
    public let additionalSearchTerms: [String]?

    /// Which version(s) of CascableCore added support for this camera, by connection method. If a value isn't
    /// present for the given connection method, that connection method isn't natively supported by CascableCore.
    /// Guaranteed to contain at least one entry.
    public let cascableCoreVersionsRequired: [ConnectionMethod: CascableCoreVersion]
    
    /// Returns `true` if the camera is supported via the given connection method by the given CascableCore version,
    /// otherwise `false`.
    public func supportedVia(_ connectionMethod: ConnectionMethod, by cascableCoreVersion: CascableCoreVersion) -> Bool {
        guard let requiredVersion = cascableCoreVersionsRequired[connectionMethod] else { return false }
        return cascableCoreVersion >= requiredVersion
    }

    /// A base list of features supported by the camera.
    public let features: Set<Feature>

    /// Additional features by connection method. The total available featureset for a camera on a given connection
    /// method is the union of the `features` property and any features contained in this property for the connection method.
    /// If a camera doesn't have extra features for a given connection method, that method will be missing from the
    /// dictionary. It's valid for the dictionary to be completely empty.
    ///
    /// See `allFeatures(for:)` for a convenience method to deal with this.
    public let connectionSpecificFeatures: [ConnectionMethod: Set<Feature>]

    /// Returns all of the features for the given connection method.
    public func allFeatures(for connectionMethod: ConnectionMethod) -> Set<Feature> {
        guard let additionalFeatures = connectionSpecificFeatures[connectionMethod] else { return features }
        return features.union(additionalFeatures)
    }

    /// A camera feature.
    public struct Feature: Hashable, Codable, ExpressibleByStringLiteral, RawRepresentable, CustomStringConvertible {
        public let rawValue: String

        public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
        public init(rawValue: String) { self.rawValue = rawValue }
        public var description: String { return rawValue }

        /// The camera supports live view.
        public static let liveView: Feature = "live-view"
        /// The camera supports setting exposure settings (shutter speed, aperture, etc).
        public static let exposureControl: Feature = "exposure-control"
        /// The camera supports tethering - that is, the user shooting photos with the camera body while it's connected.
        /// If supported, this is usually enabled by turning off live view.
        public static let tethering: Feature = "tethering"
        /// The camera supports camera-initiated transfer of files.
        public static let cameraInitiatedTransfer: Feature = "camera-initiated-transfer"
        /// The camera supports video recording.
        public static let videoRecording: Feature = "video-recording"
        /// The camera supports access to the camera's storage for browsing and transferring images.
        public static let storageAccess: Feature = "storage-access"
        // The camera supports access to RAW images.
        public static let rawImageAccess: Feature = "raw-image-access"
    }

    /// A camera connection method.
    public struct ConnectionMethod: Hashable, Codable, ExpressibleByStringLiteral, RawRepresentable, CustomStringConvertible {
        public let rawValue: String

        public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
        public init(rawValue: String) { self.rawValue = rawValue }
        public var description: String { return rawValue }

        /// Connecting via the network, usually via WiFi (but some cameras do support Ethernet).
        public static let network: ConnectionMethod = "network"
        /// Connecting via USB.
        public static let usb: ConnectionMethod = "usb"
    }
}

// MARK: - API Helpers

public struct CameraCompatibilityAPIErrorResponseBody: Hashable, Codable {
    public let reason: String
}

// MARK: - Custom Codable Implmentations

enum DecodingError: Error {
    case invalidVersionString
}

extension CascableCoreVersion: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(stringValue: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(strictDisplayValue)
    }
}

extension CascableCoreSupportedCamera: Codable {
   
    enum CodingKeys: String, CodingKey {
        case modelName
        case manufacturer
        case additionalSearchTerms
        case cascableCoreVersionsRequired
        case features
        case connectionSpecificFeatures
    }

    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

        modelName = try container.decode(String.self, forKey: .modelName)
        manufacturer = try container.decode(String.self, forKey: .manufacturer)
        additionalSearchTerms = try container.decodeIfPresent([String].self, forKey: .additionalSearchTerms)
        features = try container.decode(Set<Feature>.self, forKey: .features)

        // The default Codable implementation encodes non-string–keyed dictionaries as JSON arrays rather than objects.
        // We fixed this in the encode function, and we need to manually deal with it when decoding.
        let versions = try container.decode([String: CascableCoreVersion].self, forKey: .cascableCoreVersionsRequired)
        cascableCoreVersionsRequired = versions.reduce(into: [:], { partialResult, entry in
            partialResult[ConnectionMethod(rawValue: entry.key)] = entry.value
        })

        let features = try container.decode([String: Set<Feature>].self, forKey: .connectionSpecificFeatures)
        connectionSpecificFeatures = features.reduce(into: [:], { partialResult, entry in
            partialResult[ConnectionMethod(rawValue: entry.key)] = entry.value
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(modelName, forKey: .modelName)
        try container.encode(manufacturer, forKey: .manufacturer)
        try container.encodeIfPresent(additionalSearchTerms, forKey: .additionalSearchTerms)
        try container.encode(features, forKey: .features)

        // The default Codable implementation encodes non-string–keyed dictionaries as JSON arrays rather than objects.
        // Manually extrating the raw string value from the keys fixes this.
        try container.encode(cascableCoreVersionsRequired.reduce(into: [:], { partialResult, entry in
            partialResult[entry.key.rawValue] = entry.value
        }), forKey: .cascableCoreVersionsRequired)
        try container.encode(connectionSpecificFeatures.reduce(into: [:], { partialResult, entry in
            partialResult[entry.key.rawValue] = entry.value
        }), forKey: .connectionSpecificFeatures)
    }
}
