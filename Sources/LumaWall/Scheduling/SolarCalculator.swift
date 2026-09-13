import Foundation

enum SolarCalculator {
  static func event(
    on date: Date,
    location: SolarLocation,
    sunrise: Bool,
    calendar: Calendar = .current
  ) -> Date? {
    let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    let lngHour = location.longitude / 15
    let t = Double(day) + ((sunrise ? 6 : 18) - lngHour) / 24
    let m = 0.9856 * t - 3.289
    var l = m + 1.916 * sin(m.degreesToRadians) + 0.020 * sin(2 * m.degreesToRadians) + 282.634
    l = normalize(l)
    var ra = atan(0.91764 * tan(l.degreesToRadians)).radiansToDegrees
    ra = normalize(ra)
    let lq = floor(l / 90) * 90
    let raq = floor(ra / 90) * 90
    ra += lq - raq
    ra /= 15
    let sinDec = 0.39782 * sin(l.degreesToRadians)
    let cosDec = cos(asin(sinDec))
    let cosH =
      (cos(90.833.degreesToRadians) - sinDec * sin(location.latitude.degreesToRadians))
      / (cosDec * cos(location.latitude.degreesToRadians))
    guard cosH >= -1, cosH <= 1 else { return nil }
    let h = (sunrise ? 360 - acos(cosH).radiansToDegrees : acos(cosH).radiansToDegrees) / 15
    let localMean = h + ra - 0.06571 * t - 6.622
    let utc = normalizeHours(localMean - lngHour)
    let timezoneOffset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600
    let local = normalizeHours(utc + timezoneOffset)
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = Int(local)
    components.minute = Int((local - floor(local)) * 60)
    return calendar.date(from: components)
  }

  private static func normalize(_ value: Double) -> Double {
    var result = value.truncatingRemainder(dividingBy: 360)
    if result < 0 { result += 360 }
    return result
  }

  private static func normalizeHours(_ value: Double) -> Double {
    var result = value.truncatingRemainder(dividingBy: 24)
    if result < 0 { result += 24 }
    return result
  }
}

extension Double {
  fileprivate var degreesToRadians: Double { self * .pi / 180 }
  fileprivate var radiansToDegrees: Double { self * 180 / .pi }
}
