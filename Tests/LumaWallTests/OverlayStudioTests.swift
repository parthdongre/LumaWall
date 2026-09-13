import CoreGraphics
import Foundation
import Testing
@testable import LumaWall

@Test
func overlayCustomPointUsesNormalizedPreviewCoordinates() {
  let point = ClockOverlayLayout.customPoint(
    fromPreviewLocation: CGPoint(x: 300, y: 150),
    previewSize: CGSize(width: 600, height: 300)
  )

  #expect(abs(point.x - 0.5) < 0.0001)
  #expect(abs(point.y - 0.5) < 0.0001)
}

@Test
func overlayCustomPointClampsToSafePreviewRange() {
  let topLeft = ClockOverlayLayout.customPoint(
    fromPreviewLocation: CGPoint(x: -100, y: -100),
    previewSize: CGSize(width: 600, height: 300)
  )

  let bottomRight = ClockOverlayLayout.customPoint(
    fromPreviewLocation: CGPoint(x: 900, y: 500),
    previewSize: CGSize(width: 600, height: 300)
  )

  #expect(topLeft.x == 0.04)
  #expect(topLeft.y == 0.04)
  #expect(bottomRight.x == 0.96)
  #expect(bottomRight.y == 0.96)
}

@Test
func overlayAppKitPlacementConvertsTopDownCoordinates() {
  var settings = TimeDateOverlaySettings()
  settings.horizontalInset = 0
  settings.verticalInset = 0
  settings.customNormalizedX = 0.25
  settings.customNormalizedY = 0.25

  let origin = ClockOverlayLayout.appKitOrigin(
    boundsSize: CGSize(width: 1000, height: 800),
    overlaySize: CGSize(width: 200, height: 100),
    settings: settings
  )

  #expect(abs(origin.x - 150) < 0.001)
  #expect(abs(origin.y - 550) < 0.001)
}

@Test
func overlayFixedAnchorStillWorksWithoutCustomCoordinates() {
  var settings = TimeDateOverlaySettings()
  settings.position = .bottomRight
  settings.horizontalInset = 40
  settings.verticalInset = 30

  let origin = ClockOverlayLayout.appKitOrigin(
    boundsSize: CGSize(width: 1000, height: 800),
    overlaySize: CGSize(width: 200, height: 100),
    settings: settings
  )

  #expect(origin.x == 760)
  #expect(origin.y == 30)
}

@Test
func oldOverlaySettingsDecodeWithoutCustomPositionKeys() throws {
  let json = """
  {
    "enabled": true,
    "hourFormat": "twentyFourHour",
    "showSeconds": false,
    "dateStyle": "medium",
    "showWeekday": true,
    "additionalTimeZoneIdentifiers": [],
    "position": "topRight",
    "horizontalInset": 56,
    "verticalInset": 52,
    "timeFontSize": 64,
    "dateFontSize": 18,
    "fontWeight": "medium",
    "colorHex": "#FFFFFF",
    "opacity": 1,
    "shadow": true,
    "glassEnabled": true,
    "glassOpacity": 0.45,
    "backgroundOpacity": 0.08,
    "cornerRadius": 24,
    "uppercaseDate": false
  }
  """

  let decoded = try JSONDecoder().decode(
    TimeDateOverlaySettings.self,
    from: Data(json.utf8)
  )

  #expect(decoded.enabled)
  #expect(decoded.customNormalizedX == nil)
  #expect(decoded.customNormalizedY == nil)
}
