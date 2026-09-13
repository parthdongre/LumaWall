import AppKit

struct InteractionState {
  var normalizedMouse: CGPoint
  var primaryDown: Bool
  var secondaryDown: Bool

  init(
    normalizedMouse: CGPoint,
    primaryDown: Bool = false,
    secondaryDown: Bool = false
  ) {
    self.normalizedMouse = normalizedMouse
    self.primaryDown = primaryDown
    self.secondaryDown = secondaryDown
  }

  static func forScreen(_ screen: NSScreen) -> InteractionState {
    let mouse = NSEvent.mouseLocation
    let frame = screen.frame
    let x = (mouse.x - frame.minX) / max(frame.width, 1)
    let y = (mouse.y - frame.minY) / max(frame.height, 1)
    let buttons = NSEvent.pressedMouseButtons
    return InteractionState(
      normalizedMouse: CGPoint(
        x: min(max(x, 0), 1),
        y: min(max(y, 0), 1)
      ),
      primaryDown: buttons & 1 != 0,
      secondaryDown: buttons & 2 != 0
    )
  }
}
