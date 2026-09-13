import SwiftUI

struct DisplaysView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        GroupBox("Detected Mac") {
          HStack(spacing: 16) {
            Image(systemName: model.hardwareProfile.isPortable ? "laptopcomputer" : "desktopcomputer")
              .font(.system(size: 34))
              .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
              Text(model.hardwareProfile.deviceFamily)
                .font(.headline)
              Text(model.hardwareProfile.chipName)
                .foregroundStyle(.secondary)
              Text(
                "\(model.hardwareProfile.modelIdentifier) • \(model.hardwareProfile.memoryGB) GB unified/system memory • \(model.hardwareProfile.processorCount) CPU cores"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Optimize for This Mac") {
              model.applyHardwareRecommendation()
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(.vertical, 4)
        }

        ForEach(model.displays) { display in
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .font(.largeTitle)
                .frame(width: 48)

              VStack(alignment: .leading, spacing: 3) {
                HStack {
                  Text(display.name)
                    .font(.headline)
                  if display.isBuiltIn {
                    Text("BUILT-IN")
                      .font(.system(size: 9, weight: .semibold))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 3)
                      .background(.quaternary, in: Capsule())
                  }
                }

                Text(model.assignmentName(for: display))
                  .foregroundStyle(.secondary)
              }

              Spacer()

              if model.selectedTargetDisplayID == display.id {
                Label("Target", systemImage: "scope")
                  .foregroundStyle(.green)
              } else {
                Button("Target") {
                  model.selectedTargetDisplayID = display.id
                }
              }
            }

            Divider()

            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
              alignment: .leading,
              spacing: 10
            ) {
              displayMetric(
                "Native pixels",
                display.nativeResolutionLabel,
                "rectangle.inset.filled"
              )
              displayMetric(
                "macOS layout",
                display.logicalResolutionLabel,
                "macwindow"
              )
              displayMetric(
                "Retina scale",
                String(format: "%.1f×", display.backingScaleFactor),
                "arrow.up.left.and.arrow.down.right"
              )
              displayMetric(
                "Refresh",
                display.refreshLabel,
                "gauge.with.dots.needle.67percent"
              )
            }

            if model.maximumResolutionEnabled {
              Label(
                "Maximum Resolution is enabled. Wallpapers target \(display.nativeResolutionLabel) pixels.",
                systemImage: "checkmark.seal.fill"
              )
              .font(.caption)
              .foregroundStyle(.green)
            }
          }
          .padding()
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
      }
      .padding(24)
    }
    .navigationTitle("Displays")
  }

  private func displayMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text(value)
          .font(.callout.bold())
        Text(title)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
}
