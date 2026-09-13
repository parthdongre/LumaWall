import SwiftUI

struct DisplaysView: View {
  @EnvironmentObject private var model: AppModel
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        ForEach(model.displays) { d in
          HStack {
            Image(systemName: "display").font(.largeTitle)
            VStack(alignment: .leading) {
              Text(d.name).font(.headline)
              Text(model.assignmentName(for: d)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Target") { model.selectedTargetDisplayID = d.id }
          }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
      }.padding(24)
    }.navigationTitle("Displays")
  }
}
