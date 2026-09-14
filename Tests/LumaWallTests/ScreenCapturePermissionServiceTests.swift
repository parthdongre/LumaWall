import Testing
@testable import LumaWall

private final class PermissionBox {
  var granted: Bool
  var requests = 0

  init(granted: Bool) {
    self.granted = granted
  }
}

@Test @MainActor
func screenCapturePermissionReadsInitialState() {
  let box = PermissionBox(granted: true)
  let service = ScreenCapturePermissionService(
    preflight: { box.granted },
    requestAccess: { false }
  )

  #expect(service.isGranted)
}

@Test @MainActor
func screenCapturePermissionRefreshesAfterExternalChange() {
  let box = PermissionBox(granted: false)
  let service = ScreenCapturePermissionService(
    preflight: { box.granted },
    requestAccess: { false }
  )

  #expect(!service.isGranted)

  box.granted = true
  service.refresh()

  #expect(service.isGranted)
}

@Test @MainActor
func screenCapturePermissionRequestUpdatesGrantedState() {
  let box = PermissionBox(granted: false)
  let service = ScreenCapturePermissionService(
    preflight: { box.granted },
    requestAccess: {
      box.requests += 1
      box.granted = true
      return true
    }
  )

  #expect(service.request())
  #expect(service.isGranted)
  #expect(box.requests == 1)
}

@Test @MainActor
func screenCapturePermissionRequestCanRemainDenied() {
  let box = PermissionBox(granted: false)
  let service = ScreenCapturePermissionService(
    preflight: { box.granted },
    requestAccess: {
      box.requests += 1
      return false
    }
  )

  #expect(!service.request())
  #expect(!service.isGranted)
  #expect(box.requests == 1)
}

@Test @MainActor
func screenCapturePermissionAcceptsPreflightAfterRequestReturnFalse() {
  let box = PermissionBox(granted: false)
  let service = ScreenCapturePermissionService(
    preflight: { box.granted },
    requestAccess: {
      box.requests += 1
      box.granted = true
      return false
    }
  )

  #expect(service.request())
  #expect(service.isGranted)
  #expect(box.requests == 1)
}
