import Foundation
import Testing
@testable import LumaWall

@Test
func appFallbackVersionMatchesRepositoryVersion() throws {
  let testFile = URL(fileURLWithPath: #filePath)
  let repositoryRoot = testFile
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

  let versionFile = repositoryRoot.appendingPathComponent("VERSION")
  let version = try String(contentsOf: versionFile, encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)

  #expect(!version.isEmpty)
  #expect(AppVersion.fallbackVersion == version)
}
