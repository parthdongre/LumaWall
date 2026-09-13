import Foundation

enum RendererLoadClass: String, Hashable, Sendable {
  case unknown
  case light
  case moderate
  case heavy
  case overloaded

  var displayName: String {
    rawValue.capitalized
  }
}

struct RendererFrameStatistics: Hashable, Sendable {
  var actualFPS: Double
  var averageFrameTimeMS: Double
  var droppedFrameRatio: Double
  var loadClass: RendererLoadClass
}

struct RendererFrameMeter {
  private var samples: [Double] = []
  private var lastTimestamp: TimeInterval?

  mutating func reset() {
    samples.removeAll(keepingCapacity: true)
    lastTimestamp = nil
  }

  mutating func recordFrame(at timestamp: TimeInterval) {
    defer { lastTimestamp = timestamp }

    guard let lastTimestamp else { return }

    let delta = timestamp - lastTimestamp
    guard delta > 0, delta < 1 else { return }

    samples.append(delta)

    if samples.count > 120 {
      samples.removeFirst(samples.count - 120)
    }
  }

  func statistics(targetFPS: Int) -> RendererFrameStatistics? {
    guard samples.count >= 8 else { return nil }

    let recent = Array(samples.suffix(90))
    let average = recent.reduce(0, +) / Double(recent.count)
    guard average > 0 else { return nil }

    let actualFPS = 1 / average
    let target = max(Double(targetFPS), 1)
    let droppedRatio = min(max(1 - (actualFPS / target), 0), 1)

    let loadClass: RendererLoadClass
    let ratio = actualFPS / target

    if ratio >= 0.97 {
      loadClass = targetFPS >= 100 ? .moderate : .light
    } else if ratio >= 0.88 {
      loadClass = .moderate
    } else if ratio >= 0.70 {
      loadClass = .heavy
    } else {
      loadClass = .overloaded
    }

    return RendererFrameStatistics(
      actualFPS: actualFPS,
      averageFrameTimeMS: average * 1000,
      droppedFrameRatio: droppedRatio,
      loadClass: loadClass
    )
  }
}

enum AdaptiveLoadPressure: Int, Codable, Hashable, Sendable {
  case normal
  case constrained
  case overloaded
}

struct AdaptiveLoadController {
  private(set) var pressure: AdaptiveLoadPressure = .normal
  private var weakSamples = 0
  private var healthySamples = 0

  mutating func ingest(
    actualFPS: Double,
    targetFPS: Int
  ) -> AdaptiveLoadPressure? {
    let ratio = actualFPS / max(Double(targetFPS), 1)

    if ratio < 0.72 {
      weakSamples += 1
      healthySamples = 0

      if weakSamples >= 2, pressure != .overloaded {
        pressure = .overloaded
        weakSamples = 0
        return pressure
      }
    } else if ratio < 0.90 {
      weakSamples += 1
      healthySamples = 0

      if weakSamples >= 3, pressure == .normal {
        pressure = .constrained
        weakSamples = 0
        return pressure
      }
    } else if ratio >= 0.97 {
      healthySamples += 1
      weakSamples = 0

      if healthySamples >= 5, pressure != .normal {
        pressure =
          pressure == .overloaded
          ? .constrained
          : .normal
        healthySamples = 0
        return pressure
      }
    } else {
      weakSamples = 0
      healthySamples = 0
    }

    return nil
  }

  mutating func reset() {
    pressure = .normal
    weakSamples = 0
    healthySamples = 0
  }
}
