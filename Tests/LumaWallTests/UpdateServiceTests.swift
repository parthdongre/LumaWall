import Foundation
import Testing
@testable import LumaWall

@Test
func updateVersionComparisonUsesSemanticComponents() {
  #expect(UpdateService.compareVersions("0.5.0", "0.4.9") == .orderedDescending)
  #expect(UpdateService.compareVersions("0.4.0", "0.4") == .orderedSame)
  #expect(UpdateService.compareVersions("0.4.0", "0.4.1") == .orderedAscending)
}

@Test
func updateChecksumParserFindsExactInstaller() {
  let manifest = """
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  LumaWall-0.5.0-macOS.zip
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  LumaWall-0.5.0.dmg
  cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc  LumaWall-0.5.0.pkg
  """

  #expect(
    UpdateService.checksum(named: "LumaWall-0.5.0.dmg", from: manifest)
      == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  )
  #expect(UpdateService.checksum(named: "LumaWall-0.6.0.dmg", from: manifest) == nil)
}

@Test
func updateSHA256HashesFilesInChunks() throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }

  let file = directory.appendingPathComponent("payload.txt")
  try Data("abc".utf8).write(to: file)

  #expect(
    try UpdateService.sha256Hex(of: file)
      == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
}
