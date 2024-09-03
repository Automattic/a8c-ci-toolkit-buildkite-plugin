# Integration tests for `install_swiftpm_dependencies`

This folder contains a variety of Xcode and Swift Package projects to test the behavior of the `install_swiftpm_dependencies` in various configurations.

Note that currently with "testing" we mean: making sure the CI build doesn't fail. There isn't yet an automated setup to verify the correct command behavior.

Also note that the tests are intentionally at the integration / end-to-end level. We could structure `install_swiftpm_dependencies` so that it spits out the `xcodebuild` or `swift` it plans to run and test that, but we would lose important feedback on how `xcodebuild` and `swift` themselves behave.
Feedback on Apple's tooling behavior is crucial to get, given their known quirks.

## Development

The integration tests use [XcodeGen](https://github.com/yonaskolb/XcodeGen) to code-generate the project files and keep the repository footprint small.

However, by code-generating the xcodeproj file we lose tracking of the `Package.resolved` Xcode generates at build time, which is particularly problematic in CI.
To compensate for this, we have dedicated automation that tracks a reference `Package.resolved` file for CI to use.

If resolved file format were to change in the future, you can update the reference file via `make regenerate_resolved_fixtures`.
