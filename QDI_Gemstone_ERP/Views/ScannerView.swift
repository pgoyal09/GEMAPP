import SwiftUI
import SwiftData

/// Scanner UI: displays state and actions from ScannerViewModel only. No business logic.
struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScannerViewModel
    
    init(viewModel: ScannerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("RFID Scanner")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                Button(viewModel.isScanning ? "Stop Scanning" : "Start Scanning") {
                    if viewModel.isScanning {
                        viewModel.stopScanning()
                    } else {
                        viewModel.startScanning()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isScanning ? .red : .blue)
                
                if let tagID = viewModel.lastDiscoveredTagID {
                    Button("Process tag") {
                        viewModel.processScannedTag(tagID: tagID, modelContext: modelContext)
                    }
                }
                
                if !viewModel.discoveredTagIDs.isEmpty {
                    Button("Clear") {
                        viewModel.clearDiscoveredTags()
                    }
                }
            }
            
            if let result = viewModel.lastProcessResult {
                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.92))
                    .cornerRadius(6)
            }
            
            if viewModel.isScanning {
                Label("Listening for tags…", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let last = viewModel.lastDiscoveredTagID {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(last)
                        .font(.title2.monospaced())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.95))
                .cornerRadius(8)
            }
            
            if !viewModel.discoveredTagIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discovered (\(viewModel.discoveredTagIDs.count))")
                        .font(.headline)
                    List(viewModel.discoveredTagIDs, id: \.self) { tag in
                        Text(tag)
                            .font(.system(.body, design: .monospaced))
                    }
                    .listStyle(.inset)
                    .frame(maxHeight: 300)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { viewModel.attachScanHandler() }
        .onDisappear { viewModel.detachScanHandler() }
    }
}
