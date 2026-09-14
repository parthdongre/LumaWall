import Foundation
import Testing
@testable import LumaWall

@Test
func appInstallationRecognizesSystemApplicationsFolder() {
  let location = AppInstallationLocation(
    bundleURL: URL(fileURLWithPath: "/Applications/LumaWall.app")
  )

  #expect(location.isAppBundle)
  #expect(location.isInstalledInApplications)
  #expect(!location.isRunningFromDiskImage)
  #expect(!location.shouldRecommendInstallation)
}

@Test
func appInstallationRecognizesUserApplicationsFolder() {
  let location = AppInstallationLocation(
    bundleURL: URL(fileURLWithPath: "/Users/test/Applications/LumaWall.app")
  )

  #expect(location.isInstalledInApplications)
  #expect(!location.shouldRecommendInstallation)
}

@Test
func appInstallationDetectsMountedDiskImage() {
  let location = AppInstallationLocation(
    bundleURL: URL(fileURLWithPath: "/Volumes/LumaWall 0.4.0/LumaWall.app")
  )

  #expect(location.isAppBundle)
  #expect(location.isRunningFromDiskImage)
  #expect(!location.isInstalledInApplications)
  #expect(location.shouldRecommendInstallation)
}

@Test
func appInstallationRecommendsMovingDownloadsCopy() {
  let location = AppInstallationLocation(
    bundleURL: URL(fileURLWithPath: "/Users/test/Downloads/LumaWall.app")
  )

  #expect(location.isAppBundle)
  #expect(!location.isRunningFromDiskImage)
  #expect(!location.isInstalledInApplications)
  #expect(location.shouldRecommendInstallation)
}

@Test
func appInstallationIgnoresSwiftPMDevelopmentBundle() {
  let location = AppInstallationLocation(
    bundleURL: URL(fileURLWithPath: "/tmp/LumaWall/.build/debug")
  )

  #expect(!location.isAppBundle)
  #expect(!location.shouldRecommendInstallation)
}
