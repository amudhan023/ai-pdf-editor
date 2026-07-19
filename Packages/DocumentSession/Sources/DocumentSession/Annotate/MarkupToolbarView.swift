import SwiftUI
import PDFEngineAPI

/// Subtype + color picker plus delete, hosted in the viewer toolbar (P1-04).
/// Creation itself is triggered by the caller (a `TextRun` click) via
/// `markup.createMarkup(on:)`; this view only carries the pick-a-style state
/// and acts on whatever markup is currently selected.
struct MarkupToolbarView: View {
    @ObservedObject var markup: MarkupToolbarViewModel
    let page: PageIndex

    private static let swatches: [AnnotationColor] = [
        AnnotationColor(red: 1, green: 0.92, blue: 0.2),
        AnnotationColor(red: 0.4, green: 0.85, blue: 0.4),
        AnnotationColor(red: 0.4, green: 0.7, blue: 1.0),
        AnnotationColor(red: 1.0, green: 0.5, blue: 0.55)
    ]

    private static let subtypeLabels: [AnnotationSubtype: String] = [
        .highlight: "Highlight", .underline: "Underline", .strikeOut: "Strikeout", .squiggly: "Squiggly",
        .text: "Note", .freeText: "Free Text", .square: "Square", .circle: "Circle", .stamp: "Stamp"
    ]

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $markup.selectedSubtype) {
                ForEach(MarkupToolbarViewModel.pickerSubtypes, id: \.self) { subtype in
                    Text(Self.subtypeLabels[subtype] ?? subtype.rawValue).tag(subtype)
                }
            }
            .frame(width: 320)

            ForEach(Self.swatches.indices, id: \.self) { index in
                let swatch = Self.swatches[index]
                Button {
                    markup.selectedColor = swatch
                } label: {
                    Circle()
                        .fill(Color(red: swatch.red, green: swatch.green, blue: swatch.blue))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(.primary, lineWidth: markup.selectedColor == swatch ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
            }

            Slider(value: $markup.selectedOpacity, in: 0.1...1.0) {
                Text("Opacity")
            }
            .frame(width: 100)

            Button(role: .destructive) {
                Task { await markup.deleteSelected(page: page) }
            } label: {
                Image(systemName: "trash")
            }
            .disabled(markup.selectedAnnotationID == nil)

            Button {
                Task { await markup.undo(page: page) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!markup.canUndo)

            Button {
                Task { await markup.redo(page: page) }
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!markup.canRedo)
        }
        .task(id: page) {
            await markup.loadAnnotations(page: page)
        }
    }
}
