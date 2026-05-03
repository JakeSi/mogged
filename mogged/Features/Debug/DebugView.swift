import SwiftUI
import PhotosUI

struct DebugView: View {
    let onComplete: (ScanResult) -> Void
    let onCancel: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var results: [ScanResult] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var processor: StaticImageProcessor?

    var body: some View {
        ZStack {
            Theme.Color.background.ignoresSafeArea()
            Theme.Gradient.pageBackdrop.ignoresSafeArea()

            VStack(spacing: 24) {
                header
                
                if results.isEmpty && !isProcessing {
                    Spacer()
                    uploadSection
                    Spacer()
                } else {
                    resultsList
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .onAppear {
            do {
                processor = try StaticImageProcessor()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            if !newItems.isEmpty {
                processSelectedItems(newItems)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DEBUG MODE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.yellow)
                
                Text("Batch Process")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Theme.Color.primaryText)
            }
            Spacer()
            
            if !results.isEmpty {
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.yellow)
                }
            }
        }
    }

    private var uploadSection: some View {
        PhotosPicker(selection: $selectedItems, matching: .images) {
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.Color.primaryText)
                
                Text("Select Photos")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                
                Text("Upload clear face photos to evaluate.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isProcessing {
                    HStack(spacing: 12) {
                        ProgressView().tint(Theme.Color.primaryText)
                        Text("Processing remaining...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                    .padding(.vertical, 8)
                }

                ForEach(Array(results.enumerated()).reversed(), id: \.element) { index, result in
                    Button {
                        onComplete(result)
                    } label: {
                        ResultRow(result: result, index: index + 1)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var footer: some View {
        Button("Cancel", action: onCancel)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.Color.secondaryText)
            .padding(.bottom, 20)
    }

    private func processSelectedItems(_ items: [PhotosPickerItem]) {
        isProcessing = true
        errorMessage = nil
        
        let itemsToProcess = items
        selectedItems = [] // Clear picker selection
        
        Task {
            for item in itemsToProcess {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        continue
                    }
                    
                    if let result = try await processor?.process(image: uiImage, index: results.count + 1) {
                        results.append(result)
                    }
                } catch {
                    errorMessage = "Error processing one or more images."
                }
            }
            isProcessing = false
        }
    }
}

private struct ResultRow: View {
    let result: ScanResult
    let index: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                if let data = result.thumbnail, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.gray
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Text("#\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .offset(x: 4, y: 4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.tier.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Color.primaryText)
                
                Text(Date.relativeShort(result.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", result.harmony))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.Color.primaryText)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Color.tertiaryText)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Color.border, lineWidth: 0.5))
    }
}

private extension Date {
    static func relativeShort(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
