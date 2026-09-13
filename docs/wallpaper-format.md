# `.wall` format v1

`wallpaper.json` example:

```json
{
  "formatVersion": 1,
  "id": "com.example.nebula",
  "name": "Nebula",
  "author": "Creator",
  "type": "web",
  "entry": "assets/index.html",
  "thumbnail": "thumbnail.jpg",
  "permissions": ["mouse", "systemAudio"],
  "properties": [
    {"id":"speed","name":"Speed","kind":"slider","defaultValue":1.0,"minValue":0.1,"maxValue":3.0,"step":0.05},
    {"id":"reactive","name":"Audio Reactive","kind":"toggle","defaultValue":true},
    {"id":"accent","name":"Accent","kind":"color","defaultValue":"#6C63FF"},
    {"id":"mode","name":"Mode","kind":"dropdown","defaultValue":"waves","options":["waves","rings"]}
  ]
}
```

Supported types: `image`, `video`, `web`, `metal`.

Current permissions: `mouse`, `network`, `microphone`, `systemAudio`. `microphone` is reserved in the schema; v0.2 implements system-audio FFT capture rather than microphone capture.
