# Wallpaper security model

A wallpaper package is executable content when its type is web or Metal. LumaWall therefore treats imported packages as untrusted by default.

- Package entry/thumbnail paths must stay inside the package root.
- ZIP entries with absolute paths or `..` components are rejected before extraction.
- WebKit uses a non-persistent website data store.
- Network subresources are blocked unless `network` is requested and granted.
- Top-level remote navigation is always denied.
- Mouse data is delivered only when `mouse` is granted.
- System FFT/audio state is delivered only when `systemAudio` is granted.
- Creator-to-host messages currently expose no privileged native action.
- Metal source is compiled inside the app process; a future Workshop should add package signing/reputation and stronger isolation before accepting arbitrary public uploads.

The permission manifest is capability-oriented rather than based on wallpaper type, so future inputs such as microphone or location can be added without redesigning the renderer contract.
