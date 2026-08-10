# Florien TestFlight setup

Florien uses the same Fastlane flow locally and in GitHub Actions. GitHub only
uploads when the `Mobile iOS` workflow is started manually with
`deploy_testflight` enabled. Pushes and pull requests run Flutter tests only.

## 1. Prepare Apple Developer

The Apple Developer Team ID is `65V5D6DTQ2`. The Xcode project and the example
Fastlane environment are configured with this value.

Create or verify these explicit App IDs:

- `com.florien.app`
- `com.florien.app.FlorienWidget`

Create the App Group `group.com.florien.app`, then enable it for both App IDs.
Create an App Store distribution provisioning profile for each App ID. The
widget does not need a separate App Store Connect app, but it does need its own
App ID and provisioning profile.

The main `com.florien.app` app must exist in App Store Connect.

Create:

- An Apple Distribution certificate, exported with its private key as `.p12`
- An App Store Connect API key with App Manager access

## 2. Run locally

```bash
cd mobile/ios
bundle install
bundle exec pod install
cp fastlane/.env.example fastlane/.env
```

Fill `fastlane/.env` with the Team ID, API key IDs, `.p8` path, and both
provisioning profile paths. Add the `.p12` path and password unless the matching
distribution certificate and private key are already installed in Keychain.

Upload without triggering GitHub Actions:

```bash
cd mobile/ios
bundle exec fastlane beta
```

Fastlane reads the latest TestFlight build number, increments it, builds the
IPA, signs the app and widget, and uploads it.

## 3. Configure GitHub secrets

Add these repository secrets:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY`
- `IOS_DIST_CERTIFICATE_BASE64`
- `IOS_DIST_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`

Text secrets:

```bash
gh secret set APPLE_TEAM_ID --body "65V5D6DTQ2"
gh secret set APP_STORE_CONNECT_KEY_ID --body "<KEY_ID>"
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "<ISSUER_UUID>"
gh secret set IOS_DIST_CERTIFICATE_PASSWORD --body "<P12_PASSWORD>"
```

Binary files must be base64 encoded:

```bash
base64 -i AuthKey_<KEY_ID>.p8 | tr -d '\n' | gh secret set APP_STORE_CONNECT_API_KEY
base64 -i FlorienDistribution.p12 | tr -d '\n' | gh secret set IOS_DIST_CERTIFICATE_BASE64
base64 -i Florien_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64
base64 -i FlorienWidget_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_WIDGET_PROVISIONING_PROFILE_BASE64
```

## 4. Trigger GitHub deployment

From GitHub, open Actions → Mobile iOS → Run workflow and enable
`deploy_testflight`.

Or run:

```bash
gh workflow run mobile-ios.yml -f deploy_testflight=true
```
