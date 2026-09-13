import SwiftUI

struct DisplaysView: View {
  @EnvironmentObject
  private var model:
    AppModel

  var body: some View {
    ScrollView {
      VStack(
        alignment: .leading,
        spacing: 20
      ) {
        GroupBox(
          "Detected Mac"
        ) {
          HStack(
            spacing: 16
          ) {
            Image(
              systemName:
                model
                  .hardwareProfile
                  .isPortable
                ? "laptopcomputer"
                : "desktopcomputer"
            )
            .font(
              .system(
                size: 34
              )
            )
            .frame(
              width: 48
            )

            VStack(
              alignment: .leading,
              spacing: 4
            ) {
              Text(
                model
                  .hardwareProfile
                  .deviceFamily
              )
              .font(
                .headline
              )

              Text(
                model
                  .hardwareProfile
                  .chipName
              )
              .foregroundStyle(
                .secondary
              )

              Text(
                "\(model.hardwareProfile.modelIdentifier) • \(model.hardwareProfile.memoryGB) GB memory • \(model.hardwareProfile.processorCount) CPU cores"
              )
              .font(
                .caption
              )
              .foregroundStyle(
                .secondary
              )
            }

            Spacer()

            Button(
              "Optimize for This Mac"
            ) {
              model
                .applyHardwareRecommendation()
            }
            .buttonStyle(
              .borderedProminent
            )
          }
          .padding(
            .vertical,
            4
          )
        }

        GroupBox(
          "Display arrangement"
        ) {
          displayArrangement
            .frame(
              minHeight: 180
            )
            .padding(
              8
            )
        }

        ForEach(
          model.displays
        ) {
          display in

          let profile =
            model
              .displayProfile(
                for: display
              )

          VStack(
            alignment: .leading,
            spacing: 14
          ) {
            HStack {
              Image(
                systemName:
                  display.isBuiltIn
                  ? "laptopcomputer"
                  : "display"
              )
              .font(
                .largeTitle
              )
              .frame(
                width: 48
              )

              VStack(
                alignment: .leading,
                spacing: 3
              ) {
                HStack {
                  Text(
                    display.name
                  )
                  .font(
                    .headline
                  )

                  if display.isBuiltIn {
                    Text(
                      "BUILT-IN"
                    )
                    .font(
                      .system(
                        size: 9,
                        weight:
                          .semibold
                      )
                    )
                    .padding(
                      .horizontal,
                      6
                    )
                    .padding(
                      .vertical,
                      3
                    )
                    .background(
                      .quaternary,
                      in:
                        Capsule()
                    )
                  }

                  if display.supportsEDR {
                    Text(
                      "EDR"
                    )
                    .font(
                      .system(
                        size: 9,
                        weight:
                          .semibold
                      )
                    )
                    .padding(
                      .horizontal,
                      6
                    )
                    .padding(
                      .vertical,
                      3
                    )
                    .background(
                      Color.orange
                        .opacity(
                          0.14
                        ),
                      in:
                        Capsule()
                    )
                  }
                }

                Text(
                  model
                    .assignmentName(
                      for:
                        display
                    )
                )
                .foregroundStyle(
                  .secondary
                )
              }

              Spacer()

              if model
                .selectedTargetDisplayID
                == display.id
              {
                Label(
                  "Target",
                  systemImage:
                    "scope"
                )
                .foregroundStyle(
                  .green
                )
              } else {
                Button(
                  "Target"
                ) {
                  model
                    .selectedTargetDisplayID =
                    display.id
                }
              }
            }

            if model
              .engine
              .fullscreenPausedDisplayIDs
              .contains(
                display.id
              )
            {
              Label(
                "Renderer paused — fullscreen app is using this display",
                systemImage:
                  "pause.circle.fill"
              )
              .font(
                .caption
              )
              .foregroundStyle(
                .orange
              )
            }

            Divider()

            LazyVGrid(
              columns: [
                GridItem(
                  .adaptive(
                    minimum: 160
                  ),
                  spacing: 12
                )
              ],
              alignment:
                .leading,
              spacing: 10
            ) {
              displayMetric(
                "Native pixels",
                display
                  .nativeResolutionLabel,
                "rectangle.inset.filled"
              )

              displayMetric(
                "macOS layout",
                display
                  .logicalResolutionLabel,
                "macwindow"
              )

              displayMetric(
                "Retina scale",
                String(
                  format:
                    "%.1f×",
                  display
                    .backingScaleFactor
                ),
                "arrow.up.left.and.arrow.down.right"
              )

              displayMetric(
                "Refresh",
                display
                  .refreshLabel,
                "gauge.with.dots.needle.67percent"
              )

              displayMetric(
                "Dynamic range",
                display
                  .edrLabel,
                "sun.max"
              )
            }

            Divider()

            Grid(
              alignment:
                .leading,
              horizontalSpacing:
                16,
              verticalSpacing:
                10
            ) {
              GridRow {
                Text(
                  "Display FPS"
                )

                Picker(
                  "",
                  selection:
                    Binding(
                      get: {
                        model
                          .displayProfile(
                            for:
                              display
                          )
                          .targetFPS
                      },
                      set: {
                        newValue in

                        var updated =
                          model
                            .displayProfile(
                              for:
                                display
                            )

                        updated
                          .targetFPS =
                          min(
                            newValue,
                            display
                              .maximumFPS
                          )

                        model
                          .updateDisplayProfile(
                            updated
                          )
                      }
                    )
                ) {
                  Text(
                    "30"
                  )
                  .tag(
                    30
                  )

                  Text(
                    "60"
                  )
                  .tag(
                    60
                  )

                  Text(
                    "120"
                  )
                  .tag(
                    120
                  )
                }
                .pickerStyle(
                  .segmented
                )
                .frame(
                  width: 220
                )
              }

              GridRow {
                Text(
                  "Fit"
                )

                Picker(
                  "",
                  selection:
                    Binding(
                      get: {
                        model
                          .displayProfile(
                            for:
                              display
                          )
                          .fitMode
                      },
                      set: {
                        mode in

                        var updated =
                          model
                            .displayProfile(
                              for:
                                display
                            )

                        updated
                          .fitMode =
                          mode

                        model
                          .updateDisplayProfile(
                            updated
                          )
                      }
                    )
                ) {
                  ForEach(
                    WallpaperFitMode
                      .allCases
                  ) {
                    mode in

                    Text(
                      mode.displayName
                    )
                    .tag(
                      mode
                    )
                  }
                }
              }
            }

            Toggle(
              "Maximum Resolution on this display",
              isOn:
                Binding(
                  get: {
                    model
                      .displayProfile(
                        for:
                          display
                      )
                      .maximumResolution
                  },
                  set: {
                    enabled in

                    var updated =
                      model
                        .displayProfile(
                          for:
                            display
                        )

                    updated
                      .maximumResolution =
                      enabled

                    if enabled {
                      updated
                        .renderScale = 1
                    }

                    model
                      .updateDisplayProfile(
                        updated
                      )
                  }
                )
            )

            VStack(
              alignment: .leading,
              spacing: 5
            ) {
              HStack {
                Text(
                  "Display render scale"
                )

                Spacer()

                Text(
                  "\(Int(profile.renderScale * 100))%"
                )
                .foregroundStyle(
                  .secondary
                )
              }

              Slider(
                value:
                  Binding(
                    get: {
                      model
                        .displayProfile(
                          for:
                            display
                        )
                        .renderScale
                    },
                    set: {
                      value in

                      var updated =
                        model
                          .displayProfile(
                            for:
                              display
                          )

                      updated
                        .renderScale =
                        value

                      model
                        .updateDisplayProfile(
                          updated
                        )
                    }
                  ),
                in: 0.25...1,
                step: 0.05
              )
              .disabled(
                profile
                  .maximumResolution
              )
            }

            if profile.maximumResolution {
              Label(
                "Rendering target: \(display.nativeResolutionLabel) native pixels",
                systemImage:
                  "checkmark.seal.fill"
              )
              .font(
                .caption
              )
              .foregroundStyle(
                .green
              )
            }
          }
          .padding()
          .background(
            .regularMaterial,
            in:
              RoundedRectangle(
                cornerRadius: 14
              )
          )
        }
      }
      .padding(
        24
      )
    }
    .navigationTitle(
      "Displays"
    )
  }

  private var displayArrangement:
    some View
  {
    GeometryReader {
      geometry in

      let frames =
        model
          .displays
          .map {
            $0.screen.frame
          }

      let union =
        frames
          .dropFirst()
          .reduce(
            frames.first
              ?? .zero
          ) {
            $0.union(
              $1
            )
          }

      ZStack(
        alignment:
          .topLeading
      ) {
        ForEach(
          model.displays
        ) {
          display in

          let frame =
            display
              .screen
              .frame

          let available =
            geometry.size

          let scale =
            min(
              available.width
                / max(
                  union.width,
                  1
                ),
              available.height
                / max(
                  union.height,
                  1
                )
            )
            * 0.88

          let width =
            frame.width
              * scale

          let height =
            frame.height
              * scale

          let x =
            (
              frame.minX
                - union.minX
            )
            * scale
            + (
              available.width
                - union.width
                  * scale
            ) / 2

          let y =
            (
              union.maxY
                - frame.maxY
            )
            * scale
            + (
              available.height
                - union.height
                  * scale
            ) / 2

          Button {
            model
              .selectedTargetDisplayID =
              display.id
          } label: {
            ZStack {
              RoundedRectangle(
                cornerRadius: 12
              )
              .fill(
                model
                  .selectedTargetDisplayID
                  == display.id
                ? Color
                  .accentColor
                  .opacity(
                    0.18
                  )
                : Color
                  .secondary
                  .opacity(
                    0.1
                  )
              )

              RoundedRectangle(
                cornerRadius: 12
              )
              .stroke(
                model
                  .selectedTargetDisplayID
                  == display.id
                ? Color
                  .accentColor
                : Color
                  .secondary
                  .opacity(
                    0.35
                  ),
                lineWidth:
                  model
                    .selectedTargetDisplayID
                    == display.id
                  ? 2
                  : 1
              )

              VStack(
                spacing: 4
              ) {
                Image(
                  systemName:
                    display
                      .isBuiltIn
                    ? "laptopcomputer"
                    : "display"
                )

                Text(
                  display.name
                )
                .font(
                  .caption
                    .bold()
                )

                Text(
                  display
                    .nativeResolutionLabel
                )
                .font(
                  .caption2
                    .monospacedDigit()
                )
                .foregroundStyle(
                  .secondary
                )
              }
            }
          }
          .buttonStyle(
            .plain
          )
          .frame(
            width:
              max(
                width,
                110
              ),
            height:
              max(
                height,
                70
              )
          )
          .position(
            x:
              x
              + max(
                width,
                110
              ) / 2,
            y:
              y
              + max(
                height,
                70
              ) / 2
          )
        }
      }
    }
  }

  private func displayMetric(
    _ title: String,
    _ value: String,
    _ symbol: String
  ) -> some View {
    HStack(
      spacing: 8
    ) {
      Image(
        systemName:
          symbol
      )
      .foregroundStyle(
        .secondary
      )

      VStack(
        alignment: .leading,
        spacing: 1
      ) {
        Text(
          value
        )
        .font(
          .callout
            .bold()
        )

        Text(
          title
        )
        .font(
          .caption2
        )
        .foregroundStyle(
          .secondary
        )
      }
    }
  }
}
