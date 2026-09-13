import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      Group {
        switch model.onboardingPage {
        case 0:
          welcome
        case 1:
          wallpaperTypes
        case 2:
          performance
        default:
          ready
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      HStack {
        if model.onboardingPage > 0 {
          Button("Back") {
            model.previousOnboardingPage()
          }
        }

        Spacer()

        Text("\(model.onboardingPage + 1) of 4")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        if model.onboardingPage < 3 {
          Button("Continue") {
            model.nextOnboardingPage()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        } else {
          Button("Open LumaWall") {
            model.finishOnboarding()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
      }
      .padding(18)
    }
    .frame(width: 720, height: 500)
    .interactiveDismissDisabled()
  }

  private var welcome: some View {
    VStack(spacing: 22) {
      Image(systemName: "sparkles.rectangle.stack.fill")
        .font(.system(size: 78))
        .symbolRenderingMode(.hierarchical)

      Text("Welcome to LumaWall")
        .font(.system(size: 34, weight: .bold))

      Text(
        "A native live-wallpaper engine built specifically for macOS. No Terminal commands are needed to use LumaWall."
      )
      .font(.title3)
      .multilineTextAlignment(.center)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 540)

      HStack(spacing: 26) {
        feature("display.2", "Per-display", "Different wallpaper on every monitor")
        feature("cpu", "Native Metal", "GPU-powered procedural wallpapers")
        feature("globe", "Web & WebGL", "HTML, Canvas and WebGL scenes")
      }
    }
    .padding(38)
  }

  private var wallpaperTypes: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("One app. Every wallpaper type.")
        .font(.largeTitle.bold())

      Text(
        "LumaWall supports native images and video as well as interactive creator wallpapers."
      )
      .foregroundStyle(.secondary)

      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 14
      ) {
        capability("photo", "Static images", "PNG, JPEG, HEIC, TIFF and WebP")
        capability("film", "Video", "Hardware-decoded MP4, MOV and M4V")
        capability("globe", "HTML / WebGL", "CSS, JavaScript, Canvas and WebGL")
        capability("cpu", "Metal", "Native Apple GPU shaders")
        capability("cursorarrow.motionlines", "Interactive", "Mouse-reactive creator scenes")
        capability("waveform", "Audio reactive", "System-audio FFT when you opt in")
      }

      Spacer()
    }
    .padding(38)
  }

  private var performance: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("Choose your default quality")
        .font(.largeTitle.bold())

      Text(
        "LumaWall can automatically lower rendering cost when your Mac is on Low Power Mode or under thermal pressure."
      )
      .foregroundStyle(.secondary)

      HStack(spacing: 14) {
        presetCard(.eco, subtitle: "30 FPS • 65% scale")
        presetCard(.balanced, subtitle: "60 FPS • 85% scale")
        presetCard(.ultra, subtitle: "120 FPS • 100% scale")
      }

      Toggle(
        "Automatically reduce quality for battery and thermal conditions",
        isOn: Binding(
          get: { model.governor.adaptiveQualityEnabled },
          set: { model.setAdaptiveQualityEnabled($0) }
        )
      )

      Toggle(
        "Pause wallpapers when another app is fullscreen",
        isOn: Binding(
          get: { model.governor.pauseForFullscreen },
          set: { model.setPauseForFullscreen($0) }
        )
      )

      Spacer()
    }
    .padding(38)
  }

  private var ready: some View {
    VStack(spacing: 22) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 74))
        .foregroundStyle(.green)

      Text("Ready")
        .font(.largeTitle.bold())

      Text(
        "Browse the built-in collection, import .wall packages, assign wallpapers to displays, create playlists, and change every setting from inside LumaWall."
      )
      .multilineTextAlignment(.center)
      .foregroundStyle(.secondary)
      .frame(maxWidth: 540)

      VStack(alignment: .leading, spacing: 12) {
        Label("System-audio permission is requested only if you enable audio reaction.", systemImage: "waveform")
        Label("Updates can be checked and downloaded from LumaWall Settings.", systemImage: "arrow.down.circle")
        Label("Recovery and diagnostics are available in-app if a wallpaper misbehaves.", systemImage: "stethoscope")
      }
      .frame(maxWidth: 520, alignment: .leading)
    }
    .padding(38)
  }

  private func feature(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.title)
      Text(title)
        .font(.headline)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(width: 165)
  }

  private func capability(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.title2)
        .frame(width: 34)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }

  private func presetCard(_ preset: RenderQualityPreset, subtitle: String) -> some View {
    Button {
      model.applyQualityPreset(preset)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(preset.displayName)
            .font(.headline)
          Spacer()
          if model.qualityPreset == preset {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
          }
        }
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        model.qualityPreset == preset ? Color.accentColor.opacity(0.14) : Color.clear,
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            model.qualityPreset == preset ? Color.accentColor : Color.secondary.opacity(0.2),
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
  }
}
