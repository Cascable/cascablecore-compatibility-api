# CascableCore Compatibility API

The CascableCore Compatibility API is a JSON REST API for getting camera compatibility information for CascableCore. If your app uses CascableCore, you can use this API to build a camera compatibility table in your app.

The dataset that backs this API is the same data that's used by the [Cascable Camera Compatibility website](https://compatibility.cascable.se/). You can also this this [SUPER SECRET LINK](https://compatibility.cascable.se/?enable-developer-mode=1) to enable "developer mode" on that website to display CascableCore versions on each camera's compatibility page, which can be handy for a quick compatibility check without having to use the API.

**Important:** The compatibility list is updated relatively infrequently. Please respect the `Cache-Control` headers in the responses from this API. We may impose rate limits on clients that don't.

### Contents

- [Swift SDK](#swift-sdk)
- [HTTP Requests](#http-requests)
    - [Endpoint](#endpoint)
    - [Query Parameters](#query-parameters)
    - [An Important Note About Versions](#an-important-note-about-versions)
    - [Example Request](#example-request)
- [HTTP Responses](#http-responses)
    - [Error Responses](#error-responses)
    - [Successful Responses](#successful-responses)
    - [Example Response](#example-response)
    - [Valid Features](#valid-features)
    
## Swift SDK

This repository is a Swift package that contains helpers for using this API. If you're building an in-app compatibility guide for your users, we highly recommend you use this SDK. Since the Swift code is just a wrapper around the this API, the documentation here applies to the Swift code too.

The package includes runnable sample code in the form of a unit test in [CascableCoreCompatibilityAPITests.swift](https://github.com/Cascable/cascablecore-compatibility-api/blob/main/Tests/CascableCoreCompatibilityAPITests/CascableCoreCompatibilityAPITests.swift).

``` swift
// Which version are using?
let installedVersion = try CascableCoreVersion(stringValue: "10.0.0")

// Construct a URL to call the API.
let apiUrl: URL = .cascableCoreCompatibilityAPI(apiKey: "api-key", 
                                                highestCascableCoreVersion: installedVersion)

// Use URLSession to call the API then JSONDecoder to decode the response into an array
// of camera objects.
let supportedCameras: [CascableCoreSupportedCamera] = …

for camera in supportedCameras {
    // See "An Important Note About Versions" for details on why you'd want to check this.
    let supportedViaUSB = camera.supportedVia(.usb, by: installedVersion)
    let supportedViaNetwork = camera.supportedVia(.network, by: installedVersion)
    
    let supportsLiveViewViaUSB = camera.allFeatures(for: .usb).contains(.liveView)
    let supportsLiveViewViaNetwork = camera.allFeatures(for: .network).contains(.liveView)
}
```

## HTTP Requests

### Endpoint

The endpoint is a `GET` request to the following URL:

`https://compatibility.cascable.se/api/v1/supported-cameras`

### Query Parameters

- `auth`: **Required.** Your API key, which can be found in your account in the [Cascable Developer Portal](https://developer.cascable.se/).

- `max-version`: Optional version string in the format `major.minor` (i.e., `12.1`) or `major.minor.bugfix` (i.e., `12.1.4`). The highest version of CascableCore to include in the results. Pass the version of CascableCore currently in your app to avoid showing cameras to your users that your app might not be compatible with yet.

### An Important Note About Versions

The API takes a `max-version` parameter to exclude cameras added in CascableCore versions newer than the one you're using. However, it's important to be aware that some cameras have multiple versions depending on connection method, and the API will apply the `max-version` parameter to the *lowest* added version.

For example: The Sony α6000 was added via WiFi in CascableCore 2.0, and via USB in CascableCore 12.0. If you pass a `max-version` of `10.0` to the API, the α6000 will be included in the response. If your app connects to cameras via USB, you'll need to do some additional filtering to show the correct information to your users.

The Swift code contains various helper methods on the `CascableCoreSupportedCamera` object to assist with filtering and working with the data.

### Example Request

To request cameras supported by CascableCore 12.1.4 or *earlier*:

`GET https://compatibility.cascable.se/api/v1/supported-cameras?auth=api-key&max-version=12.1.4`

To request all cameras supported by the latest version of CascableCore:

`GET https://compatibility.cascable.se/api/v1/supported-cameras?auth=api-key`


## HTTP Responses

### Error Responses

Error responses will have a HTTP response code of `400` and above. The response content will be a JSON object with the following keys: 

- `error`: A boolean, set to `true`.

- `reason`: A string explaining the failure.

An example response may look like:

``` json
{
    "error": true,
    "reason": "Invalid version"
}
```

### Successful Responses

A successful response will contain an array of camera objects. Camera objects have the following keys:

- `modelName`: A string containing the camera's model name (i.e., the "EOS R5" in "Canon EOS R5").

- `manufacturer`: A string containing the camera's manufacturer (i.e., the "Canon" in "Canon EOS R5").

- `additionalSearchTerms`: **Optional.** An array of strings containing search terms users are likely to enter when searching for the camera. Can include model identifiers (like "ILCE-7R" for an α7R) and simplified model names (like "a7R" for an α7R - note the "a" instead of the "α").

- `cascableCoreVersionsRequired`: A dictionary of CascableCore version strings keyed on connection method. Valid connection methods are `usb` and `network`. If a key is missing, the camera is not supported by that connection method. This dictionary is guaranteed to contain at least one connection method/version pair, and may contain two if the camera is supported via both network and USB.

- `features`: A set of strings representing the "base" set of features this camera supports. See below for potential values. The total set of features over a given connection method is a union between this set and `connectionSpecificFeatures` for that connection method.

- `connectionSpecificFeatures`: A dictionary of features keyed on connection method. Valid connection methods are `usb` and `network`. This dictionary is populated with features *only* available via a specific connection method in the case the camera otherwise supports more than one. For example, the Sony α6000 supports live view via WiFi but not USB - in that case, the `features` property won't contain `live-view`, but the `network` key in this dictionary will. If the camera has no connection-specific features, this dictionary will be empty.

### Example Response

This example shows the Sony α6000. Support for this camera was added via WiFi in CascableCore 2.0, and via USB in 12.0. It supports live view via WiFi, but not USB.

``` json
[{
    "modelName": "α6000",
    "manufacturer": "Sony",
    "additionalSearchTerms": ["a6000","ILCE-6000"],
    "cascableCoreVersionsRequired": {
        "network": "2.0.0",
        "usb": "12.0.0"
    },
    "features": ["exposure-control", "camera-initiated-transfer", "tethering"],
    "connectionSpecificFeatures": {
        "network": ["live-view"]
    }
}]
```

### Valid Features

Camera objects can contain the following feature values:

- `live-view`: The camera supports live view.

- `exposure-control`: The camera supports setting exposure settings (shutter speed, aperture, etc).

- `tethering`: The camera supports tethering - that is, the user shooting photos with the camera body while it's connected. If supported, this is usually enabled by turning off live view.

- `camera-initiated-transfer`: The camera supports camera-initiated transfer of files and/or previews.

- `video-recording`: The camera supports video recording.

- `storage-access`: The camera supports access to the camera's storage for browsing and transferring images.

- `raw-image-access`: The camera supports access to RAW images. It's possible for a camera to support this via `camera-initiated-transfer` even if it doesn't support `storage-access`.
