import AppKit

@MainActor
final class TimeDateOverlayView: NSView {
  private let container = NSView()
  private let glassView = NSVisualEffectView()
  private let timeLabel = NSTextField(labelWithString: "")
  private let dateLabel = NSTextField(labelWithString: "")
  private let secondaryStack = NSStackView()

  private var timer: Timer?
  private var settings = TimeDateOverlaySettings()
  private var lastRenderedSecond = -1

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    wantsLayer = true

    container.wantsLayer = true
    addSubview(container)

    glassView.material = .hudWindow
    glassView.blendingMode = .withinWindow
    glassView.state = .active
    glassView.wantsLayer = true
    container.addSubview(glassView)

    timeLabel.isBezeled = false
    timeLabel.isEditable = false
    timeLabel.drawsBackground = false
    timeLabel.alignment = .center
    timeLabel.maximumNumberOfLines = 1
    timeLabel.lineBreakMode = .byClipping
    container.addSubview(timeLabel)

    dateLabel.isBezeled = false
    dateLabel.isEditable = false
    dateLabel.drawsBackground = false
    dateLabel.alignment = .center
    dateLabel.maximumNumberOfLines = 1
    dateLabel.lineBreakMode = .byClipping
    container.addSubview(dateLabel)

    secondaryStack.orientation = .vertical
    secondaryStack.alignment = .centerX
    secondaryStack.spacing = 3
    container.addSubview(secondaryStack)

    apply(settings)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow == nil {
      timer?.invalidate()
      timer = nil
    }
    super.viewWillMove(toWindow: newWindow)
  }

  func apply(_ settings: TimeDateOverlaySettings) {
    self.settings = settings
    isHidden = !settings.enabled

    guard settings.enabled else {
      timer?.invalidate()
      timer = nil
      return
    }

    configureAppearance()
    rebuildSecondaryClocks()
    updateText(force: true)
    scheduleTimer()
    needsLayout = true
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  override func layout() {
    super.layout()

    guard settings.enabled else { return }

    let contentPaddingX: CGFloat = 24
    let contentPaddingY: CGFloat = 18

    timeLabel.sizeToFit()
    dateLabel.sizeToFit()
    secondaryStack.layoutSubtreeIfNeeded()

    let secondarySize = secondaryStack.fittingSize
    let width = max(
      timeLabel.frame.width,
      dateLabel.isHidden ? 0 : dateLabel.frame.width,
      secondarySize.width
    ) + contentPaddingX * 2

    let timeHeight = timeLabel.frame.height
    let dateHeight = dateLabel.isHidden ? 0 : dateLabel.frame.height + 4
    let secondaryHeight = secondarySize.height > 0 ? secondarySize.height + 8 : 0
    let height = timeHeight + dateHeight + secondaryHeight + contentPaddingY * 2

    let size = CGSize(width: width, height: height)
    let origin = originForContainer(size: size)

    container.frame = CGRect(origin: origin, size: size)
    container.layer?.cornerRadius = CGFloat(settings.cornerRadius)
    container.layer?.masksToBounds = false
    container.layer?.backgroundColor =
      NSColor.black.withAlphaComponent(CGFloat(settings.backgroundOpacity)).cgColor

    glassView.frame = container.bounds
    glassView.layer?.cornerRadius = CGFloat(settings.cornerRadius)
    glassView.layer?.masksToBounds = true

    var y = contentPaddingY + secondaryHeight + dateHeight

    timeLabel.frame = CGRect(
      x: contentPaddingX,
      y: y,
      width: width - contentPaddingX * 2,
      height: timeHeight
    )

    y -= dateHeight
    if !dateLabel.isHidden {
      dateLabel.frame = CGRect(
        x: contentPaddingX,
        y: y,
        width: width - contentPaddingX * 2,
        height: dateLabel.frame.height
      )
    }

    secondaryStack.frame = CGRect(
      x: contentPaddingX,
      y: contentPaddingY,
      width: width - contentPaddingX * 2,
      height: secondarySize.height
    )
  }

  private func configureAppearance() {
    let color = NSColor(hex: settings.colorHex)
      .withAlphaComponent(CGFloat(settings.opacity))

    timeLabel.textColor = color
    dateLabel.textColor = color.withAlphaComponent(CGFloat(settings.opacity) * 0.9)

    timeLabel.font = .monospacedDigitSystemFont(
      ofSize: CGFloat(settings.timeFontSize),
      weight: settings.fontWeight.nsWeight
    )

    dateLabel.font = .systemFont(
      ofSize: CGFloat(settings.dateFontSize),
      weight: .medium
    )

    if settings.shadow {
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
      shadow.shadowBlurRadius = 12
      shadow.shadowOffset = NSSize(width: 0, height: -2)
      timeLabel.shadow = shadow
      dateLabel.shadow = shadow
    } else {
      timeLabel.shadow = nil
      dateLabel.shadow = nil
    }

    glassView.isHidden = !settings.glassEnabled
    glassView.alphaValue = CGFloat(settings.glassOpacity)
  }

  private func rebuildSecondaryClocks() {
    secondaryStack.arrangedSubviews.forEach {
      secondaryStack.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }

    for identifier in settings.additionalTimeZoneIdentifiers.prefix(3) {
      guard let zone = TimeZone(identifier: identifier) else { continue }

      let label = NSTextField(labelWithString: "")
      label.tag = zone.secondsFromGMT()
      label.font = .monospacedDigitSystemFont(
        ofSize: max(CGFloat(12), CGFloat(settings.dateFontSize) - 2),
        weight: .regular
      )
      label.textColor = NSColor(hex: settings.colorHex)
        .withAlphaComponent(CGFloat(settings.opacity) * 0.8)
      label.alignment = .center
      label.identifier = NSUserInterfaceItemIdentifier(identifier)
      secondaryStack.addArrangedSubview(label)
    }
  }

  private func scheduleTimer() {
    timer?.invalidate()

    let interval = settings.showSeconds ? 0.25 : 1.0

    let timer = Timer(
      timeInterval: interval,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        self?.updateText(force: false)
      }
    }

    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func updateText(force: Bool) {
    let now = Date()
    let second = Calendar.current.component(.second, from: now)

    if !force && settings.showSeconds && second == lastRenderedSecond {
      return
    }
    lastRenderedSecond = second

    let locale = settings.localeIdentifier
      .flatMap(Locale.init(identifier:))
      ?? .autoupdatingCurrent

    let timezone = settings.timezoneIdentifier
      .flatMap(TimeZone.init(identifier:))
      ?? .autoupdatingCurrent

    let timeFormatter = DateFormatter()
    timeFormatter.locale = locale
    timeFormatter.timeZone = timezone

    switch settings.hourFormat {
    case .system:
      timeFormatter.timeStyle = settings.showSeconds ? .medium : .short
      timeFormatter.dateStyle = .none
    case .twelveHour:
      timeFormatter.dateFormat = settings.showSeconds ? "h:mm:ss a" : "h:mm a"
    case .twentyFourHour:
      timeFormatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"
    }

    timeLabel.stringValue = timeFormatter.string(from: now)

    if settings.dateStyle == .none {
      dateLabel.isHidden = true
    } else {
      dateLabel.isHidden = false

      let dateFormatter = DateFormatter()
      dateFormatter.locale = locale
      dateFormatter.timeZone = timezone
      dateFormatter.timeStyle = .none
      dateFormatter.dateStyle = settings.dateStyle.foundationStyle

      var text = dateFormatter.string(from: now)

      if settings.showWeekday && settings.dateStyle != .full {
        let weekday = DateFormatter()
        weekday.locale = locale
        weekday.timeZone = timezone
        weekday.dateFormat = "EEEE"
        text = weekday.string(from: now) + " • " + text
      }

      dateLabel.stringValue = settings.uppercaseDate ? text.uppercased() : text
    }

    for view in secondaryStack.arrangedSubviews {
      guard
        let label = view as? NSTextField,
        let identifier = label.identifier?.rawValue,
        let zone = TimeZone(identifier: identifier)
      else {
        continue
      }

      let formatter = DateFormatter()
      formatter.locale = locale
      formatter.timeZone = zone
      formatter.dateFormat = settings.showSeconds ? "HH:mm:ss" : "HH:mm"

      let city = identifier.split(separator: "/").last
        .map(String.init)?
        .replacingOccurrences(of: "_", with: " ")
        ?? identifier

      label.stringValue = "\(city)  \(formatter.string(from: now))"
    }

    needsLayout = true
  }

  private func originForContainer(size: CGSize) -> CGPoint {
    ClockOverlayLayout.appKitOrigin(
      boundsSize: bounds.size,
      overlaySize: size,
      settings: settings
    )
  }
}

private extension ClockFontWeight {
  var nsWeight: NSFont.Weight {
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
  var foundationStyle: DateFormatter.Style {
    switch self {
    case .none: return .none
    case .short: return .short
    case .medium: return .medium
    case .long: return .long
    case .full: return .full
    }
  }
}

private extension NSColor {
  convenience init(hex: String) {
    var value = hex
    if value.hasPrefix("#") {
      value.removeFirst()
    }

    let rgb = UInt64(value, radix: 16) ?? 0xFFFFFF
    self.init(
      red: CGFloat((rgb >> 16) & 255) / 255,
      green: CGFloat((rgb >> 8) & 255) / 255,
      blue: CGFloat(rgb & 255) / 255,
      alpha: 1
    )
  }
}
