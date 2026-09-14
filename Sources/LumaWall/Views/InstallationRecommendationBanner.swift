import SwiftUI

struct InstallationRecommendationBanner: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    if model.installationLocation.shouldRecommendInstallation {
      HStack(spacing: 12) {
        Image(systemName: "arrow.down.app.fill")
          .font(.title2)
          .foregroundStyle(Color.accentColor)

        VStack(alignment: .leading, spacing: 3) {
          Text(model.installationLocation.recommendationTitle)
            .font(.headline)
          Text(model.installationLocation.recommendationMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Button("Show LumaWall") {
          model.revealInstalledAppLocation()
        }

        Button("Open Applications") {
          model.openApplicationsFolder()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(12)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
      )
    }
  }
}
