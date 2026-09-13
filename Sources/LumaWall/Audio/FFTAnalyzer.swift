import Foundation

final class FFTAnalyzer: @unchecked Sendable {
  private let size: Int
  private let window: [Float]
  init(size: Int) {
    self.size = size
    self.window = (0..<size).map { 0.5 - 0.5 * cos(2 * .pi * Float($0) / Float(size - 1)) }
  }

  func analyze(samples: [Float], sampleRate: Float) -> AudioFrame {
    var real = [Float](repeating: 0, count: size)
    var imag = [Float](repeating: 0, count: size)
    let start = max(0, samples.count - size)
    for i in 0..<min(size, samples.count) { real[i] = samples[start + i] * window[i] }
    var j = 0
    for i in 1..<size {
      var bit = size >> 1
      while j & bit != 0 {
        j ^= bit
        bit >>= 1
      }
      j ^= bit
      if i < j { real.swapAt(i, j) }
    }
    var len = 2
    while len <= size {
      let angle = -2 * Float.pi / Float(len)
      let wlenR = cos(angle)
      let wlenI = sin(angle)
      for i in stride(from: 0, to: size, by: len) {
        var wr: Float = 1
        var wi: Float = 0
        for k in 0..<(len / 2) {
          let uR = real[i + k]
          let uI = imag[i + k]
          let vR = real[i + k + len / 2] * wr - imag[i + k + len / 2] * wi
          let vI = real[i + k + len / 2] * wi + imag[i + k + len / 2] * wr
          real[i + k] = uR + vR
          imag[i + k] = uI + vI
          real[i + k + len / 2] = uR - vR
          imag[i + k + len / 2] = uI - vI
          let nwr = wr * wlenR - wi * wlenI
          wi = wr * wlenI + wi * wlenR
          wr = nwr
        }
      }
      len <<= 1
    }
    var mags = [Float]()
    mags.reserveCapacity(size / 2)
    for index in 0..<(size / 2) {
      let realPart = real[index]
      let imaginaryPart = imag[index]
      let magnitude = sqrt(realPart * realPart + imaginaryPart * imaginaryPart)
      let normalized = magnitude / Float(size) * 8
      mags.append(min(Float(1), normalized))
    }
    func band(_ low: Float, _ high: Float) -> Float {
      let a = max(1, Int(low * Float(size) / sampleRate))
      let b = min(mags.count - 1, Int(high * Float(size) / sampleRate))
      guard b >= a else { return 0 }
      return mags[a...b].reduce(0, +) / Float(b - a + 1)
    }
    let rms = sqrt(
      samples.suffix(min(samples.count, size)).reduce(Float(0)) { $0 + $1 * $1 }
        / Float(max(1, min(samples.count, size))))
    var spectrum = [Float]()
    let bins = 32
    for n in 0..<bins {
      let a = Int(pow(Float(n) / Float(bins), 2) * Float(mags.count - 1))
      let b = max(a, Int(pow(Float(n + 1) / Float(bins), 2) * Float(mags.count - 1)))
      spectrum.append(mags[a...min(b, mags.count - 1)].max() ?? 0)
    }
    return AudioFrame(
      level: min(1, rms * 4), bass: band(20, 250), mid: band(250, 4000), treble: band(4000, 16000),
      spectrum: spectrum)
  }
}
