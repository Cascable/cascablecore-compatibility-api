import XCTest
import CascableCoreCompatibilityAPI

final class CascableCoreCompatibilityAPITests: XCTestCase {

    func testAPIRequest() async throws {

        // To run this test, you must provide your API key. It's found in the Cascable developer portal.
        let apiKey: String? = nil

        // MARK: Performing The API Request

        // For convenience, you can provide your installed version of CascableCore in the request to the API to
        // filter out cameras not supported by your version. However, do see the caveat in the examples below.
        let highestVersion: CascableCoreVersion? = try CascableCoreVersion(stringValue: "13.0.0")

        let requestUrl = URL.cascableCoreCompatibilityAPI(apiKey: try XCTUnwrap(apiKey, "Please provide your API key!"),
                                                          highestCascableCoreVersion: highestVersion)

        let (responseBody, response) = try await URLSession.shared.data(from: requestUrl)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try JSONDecoder().decode(CameraCompatibilityAPIErrorResponseBody.self, from: responseBody)
            XCTFail("Got error response from API: \(errorResponse.reason)")
            return
        }

        let cameras = try JSONDecoder().decode([CascableCoreSupportedCamera].self, from: responseBody)
        XCTAssertFalse(cameras.isEmpty)

        print("Got \(cameras.count) cameras in response")

        guard let a6000 = cameras.first(where: { $0.modelName == "α6000" }) else {
            XCTFail("Response didn't contain the Sony α6000")
            return
        }

        // MARK: Example Uses Of The Data

        // The α6000 is a good example camera since it doesn't support every feature, and has different features
        // depending on the connection method. It also requires different CascableCore versions for network and USB.

        let networkFeatures = a6000.allFeatures(for: .network)
        let usbFeatures = a6000.allFeatures(for: .usb)

        print("Over the network, the \(a6000) supports: \(networkFeatures)")
        print("Over USB, the \(a6000) supports: \(usbFeatures)")

        XCTAssertTrue(networkFeatures.contains(.liveView))
        XCTAssertFalse(usbFeatures.contains(.liveView))

        // The α6000 requires CascableCore 2.0 for network connections, and 12.0 for USB connections. If you pass
        // a CascableCore version between these values to the `max-version` API parameter (i.e., version 10.0),
        // it'll still be included in the response.
        if let networkVersion = a6000.cascableCoreVersionsRequired[.network] {
            print("For network connections, the \(a6000) requires CascableCore version \(networkVersion).")
        } else {
            print("The \(a6000) isn't supported via the network.")
        }

        if let usbVersion = a6000.cascableCoreVersionsRequired[.usb] {
            print("For USB connections, the \(a6000) requires CascableCore version \(usbVersion).")
        } else {
            print("The \(a6000) isn't supported via USB.")
        }

        XCTAssertEqual(a6000.cascableCoreVersionsRequired[.network], CascableCoreVersion(2, 0))
        XCTAssertEqual(a6000.cascableCoreVersionsRequired[.usb], CascableCoreVersion(12, 0))

        // Since the response can contain cameras with different required CascableCore versions for different
        // connection methods, you may want to perform additional filtering if, for instance, you're interested
        // only in cameras that you can connect to via USB.
        let installedCascableCoreVersion = CascableCoreVersion(10, 0)

        let supportedNetworkCameras = cameras.filter({ $0.supportedVia(.network, by: installedCascableCoreVersion) })
        let supportedUSBCameras = cameras.filter({ $0.supportedVia(.usb, by: installedCascableCoreVersion) })

        print("With CascableCore version \(installedCascableCoreVersion), we can connect to \(supportedNetworkCameras.count) cameras via the network.")
        print("With CascableCore version \(installedCascableCoreVersion), we can connect to \(supportedUSBCameras.count) cameras via USB.")

        XCTAssertTrue(a6000.supportedVia(.network, by: installedCascableCoreVersion))
        XCTAssertFalse(a6000.supportedVia(.usb, by: installedCascableCoreVersion))
    }

    func testCodableRoundtrip() throws {
        var testCamera = CascableCoreSupportedCamera(
            modelName: "Foto XTREME",
            manufacturer: "Cascable",
            additionalSearchTerms: ["extreme", "extreem"],
            cascableCoreVersionsRequired: [.network: .init(5, 2, 6), .usb: .init(12, 0, 0)],
            features: [.exposureControl, .liveView, .storageAccess],
            connectionSpecificFeatures: [.usb: [.rawImageAccess]]
        )

        try testCamera.setUserInfoValue("Hello!", forKey: .comment)

        let data = try JSONEncoder().encode(testCamera)
        let string = String(data: data, encoding: .utf8)!
        print(string)
        let decodedCamera = try JSONDecoder().decode(CascableCoreSupportedCamera.self, from: data)
        XCTAssertEqual(testCamera, decodedCamera)
        XCTAssertEqual(try decodedCamera.userInfoValue(for: .comment), "Hello!")
    }
}

extension CascableCoreSupportedCamera.UserInfoKey where ValueType == String {
    static let comment = CascableCoreSupportedCamera.UserInfoKey<String>(key: "comment")
}
