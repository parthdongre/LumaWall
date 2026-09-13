import Foundation
import Testing
@testable import LumaWall

@Test
func frameMeterMeasuresStableSixtyFPS() {
  var meter = RendererFrameMeter()
  var timestamp = 10.0

  for _ in 0..<100 {
    meter.recordFrame(at: timestamp)
    timestamp += 1.0 / 60.0
  }

  let stats = meter.statistics(targetFPS: 60)

  #expect(stats != nil)
  #expect(abs((stats?.actualFPS ?? 0) - 60) < 0.5)
  #expect(abs((stats?.averageFrameTimeMS ?? 0) - 16.666) < 0.3)
  #expect((stats?.droppedFrameRatio ?? 1) < 0.02)
}

@Test
func frameMeterClassifiesSevereUnderperformance() {
  var meter = RendererFrameMeter()
  var timestamp = 20.0

  for _ in 0..<100 {
    meter.recordFrame(at: timestamp)
    timestamp += 1.0 / 30.0
  }

  let stats = meter.statistics(targetFPS: 120)

  #expect(stats?.loadClass == .overloaded)
  #expect((stats?.droppedFrameRatio ?? 0) > 0.7)
}

@Test
func adaptiveLoadControllerUsesHysteresis() {
  var controller = AdaptiveLoadController()

  #expect(controller.ingest(actualFPS: 50, targetFPS: 60) == nil)
  #expect(controller.ingest(actualFPS: 50, targetFPS: 60) == nil)
  #expect(controller.ingest(actualFPS: 50, targetFPS: 60) == .constrained)

  for _ in 0..<4 {
    #expect(controller.ingest(actualFPS: 59.5, targetFPS: 60) == nil)
  }

  #expect(controller.ingest(actualFPS: 59.5, targetFPS: 60) == .normal)
}

@Test
func adaptiveLoadControllerEscalatesQuicklyWhenOverloaded() {
  var controller = AdaptiveLoadController()

  #expect(controller.ingest(actualFPS: 25, targetFPS: 60) == nil)
  #expect(controller.ingest(actualFPS: 25, targetFPS: 60) == .overloaded)
}
