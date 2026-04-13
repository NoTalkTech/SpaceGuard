import SwiftUI

// MARK: - Supporting Views
struct AgeRuleInput: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    @State private var textValue: String = ""
    @State private var showingError = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(label)")
                .font(.system(size: 13, weight: .regular))
                .frame(width: 180, alignment: .leading)

            HStack(spacing: 8) {
                TextField("", text: $textValue)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: textValue) { newValue in
                        // Validate and update binding if valid
                        if let intValue = Int(newValue), range.contains(intValue) {
                            value = intValue
                            showingError = false
                        } else if newValue.isEmpty {
                            // Allow empty during editing
                            showingError = false
                        } else {
                            showingError = true
                        }
                    }
                    .onSubmit {
                        // On submit, reset to current value if invalid
                        if let intValue = Int(textValue), range.contains(intValue) {
                            value = intValue
                            showingError = false
                        } else {
                            textValue = String(value)
                            showingError = false
                        }
                    }

                Text(unit)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: "#86868b"))

                Stepper("", value: $value, in: range)
                    .labelsHidden()
                    .onChange(of: value) { _ in
                        // Update text when stepper changes
                        textValue = String(value)
                        showingError = false
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            textValue = String(value)
        }
        .onChange(of: value) { newValue in
            // Sync text when binding changes externally
            if textValue != String(newValue) {
                textValue = String(newValue)
            }
        }
        .alert("Invalid Value", isPresented: $showingError) {
            Button("OK") {
                textValue = String(value)
                showingError = false
            }
        } message: {
            Text("Please enter a value between \(range.lowerBound) and \(range.upperBound)")
        }
    }
}
