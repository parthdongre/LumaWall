import Foundation

enum WallpaperError: LocalizedError {
  case unsupportedFileType(String)
  case unreadableAsset(URL)
  case invalidManifest(String)
  case invalidMetalShader
  case unsafeArchivePath(String)
  case packageOperationFailed(String)
  case permissionDenied(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedFileType(let ext): return "Unsupported wallpaper file type: .\(ext)"
    case .unreadableAsset(let url): return "Could not read wallpaper asset at \(url.path)."
    case .invalidManifest(let reason): return "Invalid wallpaper manifest: \(reason)"
    case .invalidMetalShader: return "The Metal wallpaper must define lumawall_fragment."
    case .unsafeArchivePath(let path):
      return "The wallpaper archive contains an unsafe path: \(path)"
    case .packageOperationFailed(let reason): return "Wallpaper package operation failed: \(reason)"
    case .permissionDenied(let reason): return "Permission denied: \(reason)"
    }
  }
}
