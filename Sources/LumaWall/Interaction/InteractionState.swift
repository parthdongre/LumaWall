import AppKit

struct InteractionState: Sendable {
  var normalizedMouse: CGPoint
  var primaryDown: Bool
  var secondaryDown: Bool
  var mouseVelocity: CGVector
  var scrollDelta: CGVector
  var timestamp: TimeInterval

  init(
    normalizedMouse: CGPoint,
    primaryDown: Bool = false,
    secondaryDown: Bool = false,
    mouseVelocity: CGVector = .zero,
    scrollDelta: CGVector = .zero,
    timestamp: TimeInterval =
      ProcessInfo.processInfo.systemUptime
  ) {
    self.normalizedMouse =
      normalizedMouse

    self.primaryDown =
      primaryDown

    self.secondaryDown =
      secondaryDown

    self.mouseVelocity =
      mouseVelocity

    self.scrollDelta =
      scrollDelta

    self.timestamp =
      timestamp
  }

  static func forScreen(
    _ screen: NSScreen,
    previous:
      InteractionState? = nil,
    scrollDelta:
      CGVector = .zero
  ) -> InteractionState {
    let mouse =
      NSEvent.mouseLocation

    let frame =
      screen.frame

    let x =
      (
        mouse.x
          - frame.minX
      )
      / max(
        frame.width,
        1
      )

    let y =
      (
        mouse.y
          - frame.minY
      )
      / max(
        frame.height,
        1
      )

    let buttons =
      NSEvent
        .pressedMouseButtons

    let now =
      ProcessInfo
        .processInfo
        .systemUptime

    let normalized =
      CGPoint(
        x:
          min(
            max(
              x,
              0
            ),
            1
          ),
        y:
          min(
            max(
              y,
              0
            ),
            1
          )
      )

    let velocity:
      CGVector

    if let previous {
      let dt =
        max(
          now
            - previous
              .timestamp,
          1.0 / 240.0
        )

      velocity =
        CGVector(
          dx:
            (
              normalized.x
                - previous
                  .normalizedMouse
                  .x
            )
            / dt,
          dy:
            (
              normalized.y
                - previous
                  .normalizedMouse
                  .y
            )
            / dt
        )
    } else {
      velocity = .zero
    }

    return InteractionState(
      normalizedMouse:
        normalized,
      primaryDown:
        buttons & 1 != 0,
      secondaryDown:
        buttons & 2 != 0,
      mouseVelocity:
        velocity,
      scrollDelta:
        scrollDelta,
      timestamp:
        now
    )
  }
}
