import AppKit
import SwiftUI

struct CreatorStudioView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header

        HStack(alignment: .top, spacing: 20) {
          sourcePanel
            .frame(maxWidth: 420)

          VStack(spacing: 18) {
            metadataPanel
            presentationPanel
            outputPanel
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(24)
    }
    .navigationTitle("Creator Studio")
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Canva → LumaWall")
        .font(.system(size: 26, weight: .bold))

      Text(
        "Turn your Canva image or video exports into native LumaWall wallpapers without editing JSON or using Terminal."
      )
      .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        badge("PNG / JPG / HEIC / WebP", symbol: "photo")
        badge("MP4 / MOV / M4V", symbol: "film")
        badge(".wall export", symbol: "shippingbox")
      }
    }
  }

  private var sourcePanel: some View {
    GroupBox("Artwork") {
      VStack(alignment: .leading, spacing: 14) {
        sourcePreview
          .frame(maxWidth: .infinity)
          .aspectRatio(16 / 10, contentMode: .fit)

        if let summary = model.creatorAssetSummary {
          HStack {
            Label(summary.filename, systemImage: typeSymbol(summary.type))
              .lineLimit(1)

            Spacer()

            Text(summary.fileSizeLabel)
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }

          Text(summary.type == .video ? "Video wallpaper" : "Image wallpaper")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Choose the final image or video exported from Canva.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        HStack {
          Button {
            model.chooseCreatorAsset()
          } label: {
            Label(
              model.creatorDraft.sourceURL == nil ? "Choose Artwork" : "Replace Artwork",
              systemImage: "plus.rectangle.on.folder"
            )
          }
          .buttonStyle(.borderedProminent)

          if model.creatorDraft.sourceURL != nil {
            Button("Reset") {
              model.resetCreatorStudio()
            }
          }
        }

        Divider()

        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Custom thumbnail")
              .font(.headline)
            Text(
              model.creatorDraft.thumbnailURL?.lastPathComponent
                ?? "Optional. Images automatically use the artwork itself."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          }

          Spacer()

          Button("Choose") {
            model.chooseCreatorThumbnail()
          }

          if model.creatorDraft.thumbnailURL != nil {
            Button {
              model.clearCreatorThumbnail()
            } label: {
              Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  @ViewBuilder
  private var sourcePreview: some View {
    if
      let url = model.creatorDraft.sourceURL,
      model.creatorAssetSummary?.type == .image,
      let image = NSImage(contentsOf: url)
    {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14))
    } else if model.creatorAssetSummary?.type == .video {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(.black.gradient)

        VStack(spacing: 10) {
          Image(systemName: "play.rectangle.fill")
            .font(.system(size: 52))
          Text("Video wallpaper")
            .font(.headline)
          Text(model.creatorAssetSummary?.filename ?? "")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .foregroundStyle(.white)
      }
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(.quaternary)

        VStack(spacing: 10) {
          Image(systemName: "photo.on.rectangle.angled")
            .font(.system(size: 48))
          Text("Your Canva artwork")
            .font(.headline)
          Text("Choose an image or video to begin")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var metadataPanel: some View {
    GroupBox("Wallpaper details") {
      VStack(alignment: .leading, spacing: 12) {
        TextField(
          "Wallpaper name",
          text: binding(
            get: { model.creatorDraft.name },
            set: { model.creatorDraft.name = $0 }
          )
        )

        TextField(
          "Creator / studio",
          text: binding(
            get: { model.creatorDraft.author },
            set: { model.creatorDraft.author = $0 }
          )
        )

        TextField(
          "Category",
          text: binding(
            get: { model.creatorDraft.category },
            set: { model.creatorDraft.category = $0 }
          )
        )

        TextField(
          "Tags — comma separated",
          text: binding(
            get: { model.creatorDraft.tagsText },
            set: { model.creatorDraft.tagsText = $0 }
          )
        )

        TextField(
          "Description",
          text: binding(
            get: { model.creatorDraft.description },
            set: { model.creatorDraft.description = $0 }
          ),
          axis: .vertical
        )
        .lineLimit(3...6)
      }
      .padding(.vertical, 4)
    }
  }

  private var presentationPanel: some View {
    GroupBox("Presentation") {
      VStack(alignment: .leading, spacing: 14) {
        Picker(
          "Fit",
          selection: binding(
            get: { model.creatorDraft.fitMode },
            set: { model.creatorDraft.fitMode = $0 }
          )
        ) {
          ForEach(WallpaperFitMode.allCases) { mode in
            Text(mode.displayName)
              .tag(mode)
          }
        }

        Picker(
          "Time & Date preset",
          selection: binding(
            get: { model.creatorDraft.clockPreset },
            set: { model.creatorDraft.clockPreset = $0 }
          )
        ) {
          ForEach(CreatorClockPreset.allCases) { preset in
            Text(preset.displayName)
              .tag(preset)
          }
        }

        if model.creatorAssetSummary?.type == .video {
          Divider()

          Toggle(
            "Loop continuously",
            isOn: binding(
              get: { model.creatorDraft.videoLoop },
              set: { model.creatorDraft.videoLoop = $0 }
            )
          )

          Toggle(
            "Mute video audio",
            isOn: binding(
              get: { model.creatorDraft.videoMuted },
              set: { model.creatorDraft.videoMuted = $0 }
            )
          )

          HStack {
            Text("Playback speed")

            Slider(
              value: binding(
                get: { model.creatorDraft.videoPlaybackRate },
                set: { model.creatorDraft.videoPlaybackRate = $0 }
              ),
              in: 0.25...2,
              step: 0.05
            )

            Text(String(format: "%.2f×", model.creatorDraft.videoPlaybackRate))
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .frame(width: 52)
          }
        }

        Text(
          "These presentation settings are stored by LumaWall for the created wallpaper. The original Canva file is copied into LumaWall-owned storage and never modified."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
  }

  private var outputPanel: some View {
    GroupBox("Create") {
      VStack(alignment: .leading, spacing: 12) {
        if model.creatorIsCreating {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text("Building wallpaper package…")
              .foregroundStyle(.secondary)
          }
        }

        HStack {
          Button {
            model.createCreatorWallpaper()
          } label: {
            Label("Create in Library", systemImage: "sparkles.rectangle.stack")
          }
          .buttonStyle(.borderedProminent)
          .disabled(!model.creatorDraft.isReadyToCreate || model.creatorIsCreating)

          Button {
            model.createCreatorWallpaper(exportAfterCreation: true)
          } label: {
            Label("Create & Export .wall", systemImage: "square.and.arrow.up")
          }
          .disabled(!model.creatorDraft.isReadyToCreate || model.creatorIsCreating)
        }

        if !model.creatorDraft.isReadyToCreate {
          Text("Choose artwork, then provide a wallpaper name and creator name.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text(
            "The new wallpaper will appear in your Library immediately and can be applied to any connected display."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func badge(_ title: String, symbol: String) -> some View {
    Label(title, systemImage: symbol)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(.quaternary, in: Capsule())
  }

  private func typeSymbol(_ type: WallpaperType) -> String {
    switch type {
    case .image: return "photo"
    case .video: return "film"
    case .web: return "globe"
    case .metal: return "cpu"
    }
  }

  private func binding<Value>(
    get: @escaping () -> Value,
    set: @escaping (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: get, set: set)
  }
}
