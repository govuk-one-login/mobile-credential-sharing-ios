# mobile-credential-sharing-ios
Sharing - iOS SDK
This repository hosts the iOS Sharing Package and Demo Project for Wallet Sharing as part of Digital Identity. Details on our ways of working can be found on Confluence.

## How to consume the SDK
When consuming the SDK, some initial set-up is required:

In the Info.plist the relevant `UIBackgroundModes` must be set to enable bluetooth connections. 
- If using the Sharing SDK as a Holder, `bluetooth-peripheral` must be added.
- If consuming as a Verifier, the `bluetooth-central` must be added.

```swift
<key>UIBackgroundModes</key>
	<array>
		<string>bluetooth-central</string>
		<string>bluetooth-peripheral</string>
    <array>
```
