import Testing
@testable import LumaWall

@Test @MainActor
func systemSuspensionStartsActive() {
  let coordinator = SystemSuspensionCoordinator()

  #expect(!coordinator.isSuspended)
  #expect(coordinator.activeReasons.isEmpty)
}

@Test @MainActor
func oneSuspensionReasonPausesAndClearsOnce() {
  let coordinator = SystemSuspensionCoordinator()
  var states: [Bool] = []
  coordinator.onChanged = { states.append($0) }

  coordinator.set(.systemSleep, active: true)
  #expect(coordinator.isSuspended)
  #expect(coordinator.activeReasons == [.systemSleep])

  coordinator.set(.systemSleep, active: false)
  #expect(!coordinator.isSuspended)
  #expect(states == [true, false])
}

@Test @MainActor
func overlappingSuspensionReasonsDoNotResumeEarly() {
  let coordinator = SystemSuspensionCoordinator()
  var states: [Bool] = []
  coordinator.onChanged = { states.append($0) }

  coordinator.set(.systemSleep, active: true)
  coordinator.set(.screensSleep, active: true)
  coordinator.set(.sessionInactive, active: true)

  coordinator.set(.systemSleep, active: false)
  #expect(coordinator.isSuspended)

  coordinator.set(.screensSleep, active: false)
  #expect(coordinator.isSuspended)

  coordinator.set(.sessionInactive, active: false)
  #expect(!coordinator.isSuspended)

  #expect(states == [true, false])
}

@Test @MainActor
func repeatedSuspensionEventsAreIdempotent() {
  let coordinator = SystemSuspensionCoordinator()
  var states: [Bool] = []
  coordinator.onChanged = { states.append($0) }

  coordinator.set(.screensSleep, active: true)
  coordinator.set(.screensSleep, active: true)
  coordinator.set(.screensSleep, active: false)
  coordinator.set(.screensSleep, active: false)

  #expect(states == [true, false])
}

@Test @MainActor
func clearingSuspensionResumesExactlyOnce() {
  let coordinator = SystemSuspensionCoordinator()
  var states: [Bool] = []
  coordinator.onChanged = { states.append($0) }

  coordinator.set(.systemSleep, active: true)
  coordinator.set(.sessionInactive, active: true)
  coordinator.clear()
  coordinator.clear()

  #expect(!coordinator.isSuspended)
  #expect(coordinator.activeReasons.isEmpty)
  #expect(states == [true, false])
}
