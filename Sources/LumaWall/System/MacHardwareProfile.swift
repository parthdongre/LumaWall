import AppKit
import Darwin
import Foundation
import Metal

struct MacHardwareProfile: Equatable {
  let modelIdentifier: String
  let deviceFamily: String
  let chipName: String
  let memoryBytes: UInt64
  let processorCount: Int
  let isPortable: Bool
  let recommendedFPS: Int
  let recommendedRenderScale: Double
  let explanation: String

  var memoryGB: Int {
    Int((memoryBytes + 536_870_911) / 1_073_741_824)
  }

  var displayName: String {
    "\(deviceFamily) • \(chipName)"
  }

  @MainActor
  static func detect(displays: [DisplayDescriptor]) -> MacHardwareProfile {
    let identifier = sysctlString("hw.model") ?? "Unknown Mac"
    let chip = MTLCreateSystemDefaultDevice()?.name ?? Self.cpuBrandString ?? "Unknown GPU"
    let memory = ProcessInfo.processInfo.physicalMemory
    let cores = ProcessInfo.processInfo.processorCount
    let portable = displays.contains(where: \.isBuiltIn)
    let maxRefresh = displays.map(\.maximumFPS).max() ?? 60
    let appleSilicon = chip.localizedCaseInsensitiveContains("Apple")
    let enoughMemoryForHighRefresh = memory >= 16 * 1_073_741_824

    let fps: Int
    if appleSilicon && enoughMemoryForHighRefresh && maxRefresh >= 120 {
      fps = 120
    } else {
      fps = min(maxRefresh, 60)
    }

    let family = Self.deviceFamily(
      identifier: identifier,
      portable: portable
    )

    return MacHardwareProfile(
      modelIdentifier: identifier,
      deviceFamily: family,
      chipName: chip,
      memoryBytes: memory,
      processorCount: cores,
      isPortable: portable,
      recommendedFPS: max(30, fps),
      recommendedRenderScale: 1.0,
      explanation: Self.explanation(
        deviceName: family,
        chipName: chip,
        fps: max(30, fps)
      )
    )
  }

  func replacingMarketingName(_ name: String) -> MacHardwareProfile {
    MacHardwareProfile(
      modelIdentifier: modelIdentifier,
      deviceFamily: name,
      chipName: chipName,
      memoryBytes: memoryBytes,
      processorCount: processorCount,
      isPortable: isPortable,
      recommendedFPS: recommendedFPS,
      recommendedRenderScale: recommendedRenderScale,
      explanation: Self.explanation(
        deviceName: name,
        chipName: chipName,
        fps: recommendedFPS
      )
    )
  }

  static func resolveMarketingName() async -> String? {
    await Task.detached(priority: .utility) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
      process.arguments = ["SPHardwareDataType", "-json"]

      let output = Pipe()
      process.standardOutput = output
      process.standardError = Pipe()

      do {
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rows = object["SPHardwareDataType"] as? [[String: Any]],
          let first = rows.first,
          let modelName = first["machine_name"] as? String,
          !modelName.isEmpty
        else {
          return nil
        }

        return modelName
      } catch {
        return nil
      }
    }.value
  }

  private static func explanation(deviceName: String, chipName: String, fps: Int) -> String {
    if fps >= 120 {
      return "Native-pixel rendering with ProMotion-class refresh selected for this \(deviceName)."
    }
    if chipName.localizedCaseInsensitiveContains("Apple") {
      return "Native-pixel rendering with a \(fps) FPS target selected for this Apple silicon \(deviceName)."
    }
    return "Native-pixel rendering with a conservative \(fps) FPS target selected for this \(deviceName)."
  }

  private static func deviceFamily(identifier: String, portable: Bool) -> String {
    if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
    if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
    if identifier.hasPrefix("MacBook") { return "MacBook" }
    if identifier.hasPrefix("iMac") { return "iMac" }
    if identifier.hasPrefix("Macmini") { return "Mac mini" }
    if identifier.hasPrefix("MacPro") { return "Mac Pro" }
    if identifier.hasPrefix("MacStudio") { return "Mac Studio" }
    return portable ? "MacBook" : "Mac"
  }

  private static var cpuBrandString: String? {
    sysctlString("machdep.cpu.brand_string")
  }

  private static func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
      return nil
    }

    var value = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
      return nil
    }
    return String(cString: value)
  }
}
