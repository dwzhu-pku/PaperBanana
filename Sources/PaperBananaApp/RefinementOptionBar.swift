import SwiftUI

struct RefinementOptionBar: View {
    @Binding var model: ImageModelChoice
    @Binding var resolution: String
    @Binding var aspectRatio: String
    let resolutions: [String]
    let aspectRatios: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppDesignSystem.Spacing.md) {
                modelPicker
                    .frame(minWidth: 220)
                resolutionPicker
                    .frame(width: 116)
                aspectRatioPicker
                    .frame(width: 136)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                modelPicker
                HStack(spacing: AppDesignSystem.Spacing.md) {
                    resolutionPicker
                    aspectRatioPicker
                }
            }
        }
    }

    private var modelPicker: some View {
        WorkbenchOptionField("Model") {
            Picker("Model", selection: $model) {
                ForEach(ImageModelChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Image model")
        }
    }

    private var resolutionPicker: some View {
        WorkbenchOptionField("Resolution") {
            Picker("Resolution", selection: $resolution) {
                ForEach(resolutions, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Resolution")
        }
    }

    private var aspectRatioPicker: some View {
        WorkbenchOptionField("Aspect Ratio") {
            Picker("Aspect Ratio", selection: $aspectRatio) {
                ForEach(aspectRatios, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Aspect ratio")
        }
    }
}
