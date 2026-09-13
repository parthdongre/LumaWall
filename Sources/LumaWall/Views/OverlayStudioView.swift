import SwiftUI

struct OverlayStudioView: View {
  @EnvironmentObject private var model: AppModel

  private var wallpaper: Wallpaper? {
    if let id = model.selectedWallpaperID {
      return model.wallpapers.first(where: { $0.id == id })
    }
    return model.wallpapers.first
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header

        if let wallpaper {
          wallpaperPicker

          overlayPreview(wallpaper)
            .frame(maxWidth: 1040)
            .aspectRatio(16 / 9, contentMode: .fit)

          controls(for: wallpaper)
        } else {
          ContentUnavailableView(
            "No Wallpapers",
            systemImage: "clock.badge.exclamationmark",
            description: Text("Import or create a wallpaper before designing an overlay.")
          )
        }
      }
      .padding(24)
    }
    .navigationTitle("Overlay Studio")
    .onAppear {
      if model.selectedWallpaperID == nil {
        model.selectedWallpaperID = model.wallpapers.first?.id
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Time & Date Overlay Studio")
        .font(.system(size: 26, weight: .bold))

      Text(
        "Design one native overlay and attach it to any image, video, WebGL or Metal wallpaper. Drag the clock directly on the preview for free placement."
      )
      .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        studioBadge("Native", symbol: "apple.logo")
        studioBadge("Resolution independent", symbol: "display")
        studioBadge("Per wallpaper", symbol: "square.stack.3d.up")
      }
    }
  }

  private var wallpaperPicker: some View {
    GroupBox("Target wallpaper") {
      HStack {
        Picker(
          "Wallpaper",
          selection: Binding(
            get: { model.selectedWallpaperID },
            set: { model.selectedWallpaperID = $0 }
          )
        ) {
          ForEach(model.wallpapers) { wallpaper in
            Text(wallpaper.name)
              .tag(Optional(wallpaper.id))
          }
        }
        .frame(maxWidth: 420)

        Spacer()

        if let id = model.selectedWallpaperID {
          Button {
            model.applyWallpaper(id: id, to: model.selectedTargetDisplayID)
          } label: {
            Label("Apply to Desktop", systemImage: "play.fill")
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func overlayPreview(_ wallpaper: Wallpaper) -> some View {
    GeometryReader { geometry in
      let settings = model.timeDateSettings(for: wallpaper.id)
      let point = ClockOverlayLayout.normalizedPoint(for: settings)

      ZStack {
        WallpaperThumbnail(wallpaper: wallpaper)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())

        LinearGradient(
          colors: [
            .black.opacity(0.03),
            .clear,
            .black.opacity(0.08),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .allowsHitTesting(false)

        if settings.enabled {
          TimelineView(
            .periodic(
              from: .now,
              by: settings.showSeconds ? 1 : 15
            )
          ) { context in
            previewClock(
              date: context.date,
              settings: settings,
              previewWidth: geometry.size.width
            )
          }
          .position(
            x: point.x * geometry.size.width,
            y: point.y * geometry.size.height
          )
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                setCustomPosition(
                  value.location,
                  previewSize: geometry.size,
                  wallpaperID: wallpaper.id
                )
              }
          )
        } else {
          Button {
            var updated = settings
            updated.enabled = true
            model.updateTimeDateSettings(updated, for: wallpaper.id)
          } label: {
            Label("Enable Time & Date", systemImage: "clock.badge.plus")
              .padding(.horizontal, 14)
              .padding(.vertical, 9)
          }
          .buttonStyle(.borderedProminent)
        }

        VStack {
          HStack {
            Label(
              settings.customNormalizedX != nil ? "FREE POSITION" : settings.position.displayName.uppercased(),
              systemImage: settings.customNormalizedX != nil ? "move.3d" : "scope"
            )
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()
          }

          Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
      }
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(.white.opacity(0.1))
      }
    }
  }

  private func previewClock(
    date: Date,
    settings: TimeDateOverlaySettings,
    previewWidth: CGFloat
  ) -> some View {
    OverlayClockPreview(
      date: date,
      settings: settings,
      previewWidth: previewWidth
    )
  }

  private func controls(for wallpaper: Wallpaper) -> some View {
    let settings = model.timeDateSettings(for: wallpaper.id)

    return VStack(spacing: 18) {
      GroupBox("Layout & presets") {
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            Toggle(
              "Show Time & Date",
              isOn: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.enabled },
                set: { $0.enabled = $1 }
              )
            )

            Spacer()

            presetButton("Glass", systemImage: "rectangle.on.rectangle.angled") {
              model.applyTimeDatePreset(.glass, to: wallpaper.id)
            }

            presetButton("Minimal", systemImage: "textformat") {
              model.applyTimeDatePreset(.minimal, to: wallpaper.id)
            }

            presetButton("Bold", systemImage: "bold") {
              model.applyTimeDatePreset(.bold, to: wallpaper.id)
            }
          }

          Divider()

          HStack {
            Picker(
              "Anchor",
              selection: Binding(
                get: { settings.position },
                set: { position in
                  var updated = model.timeDateSettings(for: wallpaper.id)
                  updated.position = position
                  updated.customNormalizedX = nil
                  updated.customNormalizedY = nil
                  model.updateTimeDateSettings(updated, for: wallpaper.id)
                }
              )
            ) {
              ForEach(ClockOverlayPosition.allCases) { position in
                Text(position.displayName)
                  .tag(position)
              }
            }

            if settings.customNormalizedX != nil {
              Button("Use Anchor Position") {
                var updated = model.timeDateSettings(for: wallpaper.id)
                updated.customNormalizedX = nil
                updated.customNormalizedY = nil
                model.updateTimeDateSettings(updated, for: wallpaper.id)
              }
            }

            Spacer()

            if
              let x = settings.customNormalizedX,
              let y = settings.customNormalizedY
            {
              Text(
                "Free: \(Int(x * 100))%, \(Int(y * 100))%"
              )
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
            }
          }

          Text("Tip: drag the clock directly in the preview for pixel-independent free placement.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }

      HStack(alignment: .top, spacing: 18) {
        GroupBox("Typography") {
          VStack(alignment: .leading, spacing: 13) {
            Picker(
              "Hour format",
              selection: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.hourFormat },
                set: { $0.hourFormat = $1 }
              )
            ) {
              ForEach(ClockHourFormat.allCases) { format in
                Text(format.displayName)
                  .tag(format)
              }
            }

            Picker(
              "Date style",
              selection: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.dateStyle },
                set: { $0.dateStyle = $1 }
              )
            ) {
              ForEach(ClockDateStyle.allCases) { style in
                Text(style.displayName)
                  .tag(style)
              }
            }

            Picker(
              "Weight",
              selection: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.fontWeight },
                set: { $0.fontWeight = $1 }
              )
            ) {
              ForEach(ClockFontWeight.allCases) { weight in
                Text(weight.displayName)
                  .tag(weight)
              }
            }

            slider(
              "Clock size",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.timeFontSize },
                set: { $0.timeFontSize = $1 }
              ),
              range: 28...160,
              step: 2,
              suffix: " pt"
            )

            slider(
              "Date size",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.dateFontSize },
                set: { $0.dateFontSize = $1 }
              ),
              range: 11...40,
              step: 1,
              suffix: " pt"
            )

            ColorPicker(
              "Text color",
              selection: Binding(
                get: { Color(hex: settings.colorHex) },
                set: { color in
                  var updated = model.timeDateSettings(for: wallpaper.id)
                  updated.colorHex = color.hexString
                  model.updateTimeDateSettings(updated, for: wallpaper.id)
                }
              )
            )

            HStack {
              Toggle(
                "Seconds",
                isOn: overlayBinding(
                  wallpaperID: wallpaper.id,
                  get: { $0.showSeconds },
                  set: { $0.showSeconds = $1 }
                )
              )

              Toggle(
                "Weekday",
                isOn: overlayBinding(
                  wallpaperID: wallpaper.id,
                  get: { $0.showWeekday },
                  set: { $0.showWeekday = $1 }
                )
              )

              Toggle(
                "Uppercase date",
                isOn: overlayBinding(
                  wallpaperID: wallpaper.id,
                  get: { $0.uppercaseDate },
                  set: { $0.uppercaseDate = $1 }
                )
              )
            }
          }
          .padding(.vertical, 4)
        }

        GroupBox("Glass & environment") {
          VStack(alignment: .leading, spacing: 13) {
            Toggle(
              "Glass card",
              isOn: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.glassEnabled },
                set: { $0.glassEnabled = $1 }
              )
            )

            Toggle(
              "Text shadow",
              isOn: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.shadow },
                set: { $0.shadow = $1 }
              )
            )

            slider(
              "Text opacity",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.opacity },
                set: { $0.opacity = $1 }
              ),
              range: 0.2...1,
              step: 0.05,
              percent: true
            )

            slider(
              "Glass strength",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.glassOpacity },
                set: { $0.glassOpacity = $1 }
              ),
              range: 0...1,
              step: 0.05,
              percent: true
            )

            slider(
              "Background",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.backgroundOpacity },
                set: { $0.backgroundOpacity = $1 }
              ),
              range: 0...0.8,
              step: 0.05,
              percent: true
            )

            slider(
              "Corner radius",
              value: overlayBinding(
                wallpaperID: wallpaper.id,
                get: { $0.cornerRadius },
                set: { $0.cornerRadius = $1 }
              ),
              range: 0...50,
              step: 1,
              suffix: " pt"
            )

            TextField(
              "Timezone — e.g. Asia/Kolkata",
              text: Binding(
                get: { settings.timezoneIdentifier ?? "" },
                set: { text in
                  var updated = model.timeDateSettings(for: wallpaper.id)
                  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                  updated.timezoneIdentifier = trimmed.isEmpty ? nil : trimmed
                  model.updateTimeDateSettings(updated, for: wallpaper.id)
                }
              )
            )

            TextField(
              "World clocks — comma separated",
              text: Binding(
                get: { settings.additionalTimeZoneIdentifiers.joined(separator: ", ") },
                set: { text in
                  var updated = model.timeDateSettings(for: wallpaper.id)
                  updated.additionalTimeZoneIdentifiers = text
                    .split(separator: ",")
                    .map {
                      $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    .filter { !$0.isEmpty }
                  model.updateTimeDateSettings(updated, for: wallpaper.id)
                }
              )
            )

            Text("Examples: Europe/London, America/New_York, Asia/Tokyo")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
    }
  }

  private func setCustomPosition(
    _ location: CGPoint,
    previewSize: CGSize,
    wallpaperID: UUID
  ) {
    let point = ClockOverlayLayout.customPoint(
      fromPreviewLocation: location,
      previewSize: previewSize
    )

    var updated = model.timeDateSettings(for: wallpaperID)
    updated.customNormalizedX = Double(point.x)
    updated.customNormalizedY = Double(point.y)
    model.updateTimeDateSettings(updated, for: wallpaperID)
  }

  private func overlayBinding<Value>(
    wallpaperID: UUID,
    get: @escaping (TimeDateOverlaySettings) -> Value,
    set: @escaping (inout TimeDateOverlaySettings, Value) -> Void
  ) -> Binding<Value> {
    Binding(
      get: {
        get(model.timeDateSettings(for: wallpaperID))
      },
      set: { newValue in
        var updated = model.timeDateSettings(for: wallpaperID)
        set(&updated, newValue)
        model.updateTimeDateSettings(updated, for: wallpaperID)
      }
    )
  }

  private func slider(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double,
    suffix: String = "",
    percent: Bool = false
  ) -> some View {
    HStack {
      Text(title)
        .frame(width: 105, alignment: .leading)

      Slider(value: value, in: range, step: step)

      Text(
        percent
        ? "\(Int(value.wrappedValue * 100))%"
        : "\(Int(value.wrappedValue))\(suffix)"
      )
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
      .frame(width: 58, alignment: .trailing)
    }
  }

  private func presetButton(
    _ title: String,
    systemImage: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
    }
    .buttonStyle(.bordered)
  }

  private func studioBadge(_ title: String, symbol: String) -> some View {
    Label(title, systemImage: symbol)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(.quaternary, in: Capsule())
  }


}

private struct OverlayClockPreview: View {
  let date: Date
  let settings: TimeDateOverlaySettings
  let previewWidth: CGFloat

  private var scale: CGFloat {
    min(
      max(previewWidth / 1500, CGFloat(0.20)),
      CGFloat(0.62)
    )
  }

  private var textColor: Color {
    Color(hex: settings.colorHex)
      .opacity(settings.opacity)
  }

  private var cornerRadius: CGFloat {
    max(CGFloat(8), CGFloat(settings.cornerRadius) * scale)
  }

  var body: some View {
    VStack(spacing: max(CGFloat(2), CGFloat(5) * scale)) {
      timeText
      dateText
      worldClocks
    }
    .foregroundStyle(textColor)
    .padding(.horizontal, max(CGFloat(10), CGFloat(24) * scale))
    .padding(.vertical, max(CGFloat(8), CGFloat(18) * scale))
    .background(glassBackground)
    .background(
      Color.black.opacity(settings.backgroundOpacity),
      in: RoundedRectangle(cornerRadius: cornerRadius)
    )
    .shadow(
      color: settings.shadow ? .black.opacity(0.55) : .clear,
      radius: settings.shadow ? max(CGFloat(4), CGFloat(12) * scale) : 0,
      y: settings.shadow ? max(CGFloat(1), CGFloat(3) * scale) : 0
    )
    .contentShape(Rectangle())
    .help("Drag to position")
  }

  private var timeText: some View {
    Text(OverlayClockText.time(date, settings: settings))
      .font(
        .system(
          size: max(CGFloat(16), CGFloat(settings.timeFontSize) * scale),
          weight: settings.fontWeight.swiftUIWeight,
          design: .monospaced
        )
      )
      .monospacedDigit()
      .lineLimit(1)
  }

  @ViewBuilder
  private var dateText: some View {
    if settings.dateStyle != .none {
      Text(OverlayClockText.date(date, settings: settings))
        .font(
          .system(
            size: max(CGFloat(9), CGFloat(settings.dateFontSize) * scale),
            weight: .medium
          )
        )
        .lineLimit(1)
    }
  }

  private var worldClocks: some View {
    VStack(spacing: 2) {
      ForEach(Array(settings.additionalTimeZoneIdentifiers.prefix(3)), id: \.self) { identifier in
        if TimeZone(identifier: identifier) != nil {
          Text(
            OverlayClockText.worldClock(
              date,
              identifier: identifier,
              settings: settings
            )
          )
          .font(
            .system(
              size: max(CGFloat(8), CGFloat(settings.dateFontSize - 2) * scale),
              weight: .regular,
              design: .monospaced
            )
          )
          .opacity(0.8)
        }
      }
    }
  }

  @ViewBuilder
  private var glassBackground: some View {
    if settings.glassEnabled {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
        .opacity(settings.glassOpacity)
    }
  }
}

private enum OverlayClockText {
  static func time(
    _ date: Date,
    settings: TimeDateOverlaySettings
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = settings.localeIdentifier
      .map(Locale.init(identifier:))
      ?? .autoupdatingCurrent
    formatter.timeZone = settings.timezoneIdentifier
      .flatMap(TimeZone.init(identifier:))
      ?? .autoupdatingCurrent

    switch settings.hourFormat {
    case .system:
      formatter.timeStyle = settings.showSeconds ? .medium : .short
      formatter.dateStyle = .none
    case .twelveHour:
      formatter.dateFormat = settings.showSeconds ? "h:mm:ss a" : "h:mm a"
    case .twentyFourHour:
      formatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"
    }

    return formatter.string(from: date)
  }

  static func date(
    _ date: Date,
    settings: TimeDateOverlaySettings
  ) -> String {
    let locale = settings.localeIdentifier
      .map(Locale.init(identifier:))
      ?? .autoupdatingCurrent
    let timezone = settings.timezoneIdentifier
      .flatMap(TimeZone.init(identifier:))
      ?? .autoupdatingCurrent

    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timezone
    formatter.timeStyle = .none
    formatter.dateStyle = settings.dateStyle.foundationDateStyle

    var text = formatter.string(from: date)

    if settings.showWeekday && settings.dateStyle != .full {
      let weekday = DateFormatter()
      weekday.locale = locale
      weekday.timeZone = timezone
      weekday.dateFormat = "EEEE"
      text = weekday.string(from: date) + " • " + text
    }

    return settings.uppercaseDate ? text.uppercased() : text
  }

  static func worldClock(
    _ date: Date,
    identifier: String,
    settings: TimeDateOverlaySettings
  ) -> String {
    guard let timezone = TimeZone(identifier: identifier) else {
      return identifier
    }

    let formatter = DateFormatter()
    formatter.locale = settings.localeIdentifier
      .map(Locale.init(identifier:))
      ?? .autoupdatingCurrent
    formatter.timeZone = timezone
    formatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"

    let city = identifier
      .split(separator: "/")
      .last
      .map(String.init)?
      .replacingOccurrences(of: "_", with: " ")
      ?? identifier

    return "\(city)  \(formatter.string(from: date))"
  }
}

private extension ClockFontWeight {
  var swiftUIWeight: Font.Weight {
    switch self {
    case .ultraLight: return .ultraLight
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    }
  }
}

private extension ClockDateStyle {
  var foundationDateStyle: DateFormatter.Style {
    switch self {
    case .none: return .none
    case .short: return .short
    case .medium: return .medium
    case .long: return .long
    case .full: return .full
    }
  }
}
