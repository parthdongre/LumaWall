import Foundation

enum AppVersion {
  static let fallbackVersion = "0.3.3"

  static var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? fallbackVersion
  }

  static var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
      ?? "development"
  }

  static var display: String {
    "\(version) (\(build))"
  }
}
