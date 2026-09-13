import SwiftUI

struct DiscoverView: View {
  @EnvironmentObject private var model: AppModel
  @State private var endpointText = ""
  @State private var searchText = ""
  @State private var selectedCategory = "All"

  private var categories: [String] {
    ["All"] + Array(
      Set(model.discover.items.map(\.category))
    ).sorted()
  }

  private var visibleItems: [DiscoverWallpaperListing] {
    model.discover.items.filter { item in
      let categoryMatches =
        selectedCategory == "All"
        || item.category == selectedCategory

      let query = searchText
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

      return categoryMatches
        && (query.isEmpty || item.searchableText.contains(query))
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        header
        catalogControls

        if model.discover.isLoading {
          HStack {
            ProgressView()
            Text("Refreshing curated catalog…")
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 24)
        } else if model.discover.items.isEmpty {
          emptyCatalog
        } else {
          filters
          catalogGrid
        }
      }
      .padding(24)
    }
    .navigationTitle("Discover")
    .onAppear {
      endpointText = model.discover.endpointString
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Discover")
        .font(.system(size: 28, weight: .bold))

      Text(
        "Your curated LumaWall collection. The catalog is empty by default so only wallpapers you choose to publish appear here."
      )
      .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        badge("HTTPS only", symbol: "lock")
        badge("SHA-256 verification", symbol: "checkmark.shield")
        badge("Secure .wall importer", symbol: "shippingbox")
      }
    }
  }

  private var catalogControls: some View {
    GroupBox("Catalog source") {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          TextField(
            "HTTPS catalog JSON URL",
            text: $endpointText
          )

          Button("Save & Refresh") {
            model.setDiscoverEndpoint(endpointText)
            model.refreshDiscover()
          }
          .buttonStyle(.borderedProminent)

          Button("Open JSON…") {
            model.chooseLocalDiscoverCatalog()
          }
        }

        if let updated = model.discover.lastUpdated {
          Text(
            "Last refreshed "
              + updated.formatted(date: .abbreviated, time: .shortened)
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        if let error = model.discover.lastError {
          Label(error, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var emptyCatalog: some View {
    ContentUnavailableView {
      Label(
        "Your Catalog Is Empty",
        systemImage: "sparkles.rectangle.stack"
      )
    } description: {
      Text(
        "When your Canva wallpapers are ready, publish a LumaWall catalog JSON or open one locally. No random wallpapers are inserted automatically."
      )
    } actions: {
      HStack {
        Button("Open Local Catalog") {
          model.chooseLocalDiscoverCatalog()
        }

        if !endpointText.isEmpty {
          Button("Refresh") {
            model.setDiscoverEndpoint(endpointText)
            model.refreshDiscover()
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 70)
  }

  private var filters: some View {
    HStack {
      TextField("Search catalog", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 360)

      Picker("Category", selection: $selectedCategory) {
        ForEach(categories, id: \.self) { category in
          Text(category).tag(category)
        }
      }
      .frame(maxWidth: 260)

      Spacer()

      Text("\(visibleItems.count) wallpaper(s)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var catalogGrid: some View {
    LazyVGrid(
      columns: [
        GridItem(
          .adaptive(minimum: 260, maximum: 360),
          spacing: 18
        )
      ],
      spacing: 18
    ) {
      ForEach(visibleItems) { item in
        catalogCard(item)
      }
    }
  }

  private func catalogCard(
    _ item: DiscoverWallpaperListing
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack(alignment: .topLeading) {
        AsyncImage(url: item.previewURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          default:
            Rectangle()
              .fill(.black.gradient)
              .overlay {
                Image(systemName: typeSymbol(item.type))
                  .font(.system(size: 40))
                  .foregroundStyle(.white.opacity(0.8))
              }
          }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))

        HStack(spacing: 5) {
          if item.featured {
            capsule("FEATURED", symbol: "sparkles")
          }

          capsule(
            item.type.rawValue.uppercased(),
            symbol: typeSymbol(item.type)
          )
        }
        .padding(8)
      }

      Text(item.name)
        .font(.headline)
        .lineLimit(1)

      Text(item.author)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if let description = item.description, !description.isEmpty {
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      HStack {
        Label(item.category, systemImage: "tag")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Spacer()

        if let checksum = item.sha256, !checksum.isEmpty {
          Label("Verified", systemImage: "checkmark.shield")
            .font(.caption2)
            .foregroundStyle(.green)
        }
      }

      Button {
        model.installDiscoverWallpaper(item)
      } label: {
        if model.discoverInstallingWallpaperID == item.id {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text("Installing…")
          }
          .frame(maxWidth: .infinity)
        } else {
          Label("Install", systemImage: "arrow.down.circle")
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(model.discoverInstallingWallpaperID != nil)
    }
    .padding(10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private func badge(_ text: String, symbol: String) -> some View {
    Label(text, systemImage: symbol)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(.quaternary, in: Capsule())
  }

  private func capsule(_ text: String, symbol: String) -> some View {
    Label(text, systemImage: symbol)
      .font(.system(size: 9, weight: .semibold))
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(.black.opacity(0.66), in: Capsule())
      .foregroundStyle(.white)
  }

  private func typeSymbol(_ type: WallpaperType) -> String {
    switch type {
    case .image: return "photo"
    case .video: return "film"
    case .web: return "globe"
    case .metal: return "cpu"
    }
  }
}
