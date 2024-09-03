regenerate_fixtures:
	xcodegen generate --spec ./project/project.yml
	xcodebuild -resolvePackageDependencies -project ./project/Demo.xcodeproj
	cp ./project/Demo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved ./package_resolved_fixtures/valid.resolved
