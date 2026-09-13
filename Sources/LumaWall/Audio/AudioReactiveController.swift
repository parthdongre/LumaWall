import AudioToolbox
import CoreMedia
import Foundation
import ScreenCaptureKit

struct AudioFrame: Equatable, Sendable {
  var level: Float
  var bass: Float
  var mid: Float
  var treble: Float
  var spectrum: [Float]
  static let zero = AudioFrame(
    level: 0, bass: 0, mid: 0, treble: 0, spectrum: Array(repeating: 0, count: 32))
  var jsonObject: [String: Any] {
    ["level": level, "bass": bass, "mid": mid, "treble": treble, "spectrum": spectrum]
  }
}

final class AudioReactiveController: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable
{
  private let queue = DispatchQueue(label: "LumaWall.SystemAudio")
  private let analyzer = FFTAnalyzer(size: 2048)
  private var stream: SCStream?
  var onFrame: (@Sendable (AudioFrame) -> Void)?

  func startSystemAudio() async throws {
    let content = try await SCShareableContent.excludingDesktopWindows(
      false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
      throw WallpaperError.permissionDenied("No capturable display is available")
    }
    let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
    let config = SCStreamConfiguration()
    config.width = 2
    config.height = 2
    config.showsCursor = false
    config.capturesAudio = true
    config.excludesCurrentProcessAudio = true
    config.sampleRate = 48_000
    config.channelCount = 2
    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
    try await stream.startCapture()
    self.stream = stream
  }

  func stop() async {
    if let stream { try? await stream.stopCapture() }
    stream = nil
    onFrame?(.zero)
  }

  nonisolated func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .audio, sampleBuffer.isValid,
      let samples = Self.floatSamples(from: sampleBuffer), !samples.isEmpty
    else { return }
    let frame = analyzer.analyze(samples: samples, sampleRate: 48_000)
    onFrame?(frame)
  }

  private static func floatSamples(from sampleBuffer: CMSampleBuffer) -> [Float]? {
    var needed = 0
    var block: CMBlockBuffer?
    var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, bufferListSizeNeededOut: &needed, bufferListOut: nil, bufferListSize: 0,
      blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block)
    guard status == noErr, needed > 0 else { return nil }
    let raw = UnsafeMutableRawPointer.allocate(
      byteCount: needed, alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    let list = raw.assumingMemoryBound(to: AudioBufferList.self)
    status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: list, bufferListSize: needed,
      blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block)
    guard status == noErr else { return nil }
    let buffers = UnsafeMutableAudioBufferListPointer(list)
    guard let first = buffers.first, let data = first.mData else { return nil }
    let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size
    return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count))
  }
}
