//
//  CameraVocabView.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import SwiftUI
import AVFoundation

struct CameraVocabView: View {
    @StateObject private var viewModel: CameraVocabViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: CameraVocabViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Camera setup loading
                if viewModel.isSettingUpCamera {
                    cameraLoadingView
                }
                // Camera permission view
                else if !viewModel.cameraPermissionGranted {
                    cameraPermissionView
                }
                // Camera preview
                else if viewModel.isCameraReady, let session = viewModel.captureSession {
                    CameraPreviewView(session: session)
                        .ignoresSafeArea()
                }
                
                // Overlay UI (only show when camera is ready)
                if viewModel.isCameraReady {
                    VStack {
                        Spacer()
                        
                        // Recognition result card
                        if let result = viewModel.recognizedObject {
                            recognitionResultCard(result)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Capture button
                        captureControls
                    }
                }
                
                // Processing overlay
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Camera Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel.stopCamera()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.learnedWords.isEmpty {
                        Menu {
                            ForEach(viewModel.learnedWords) { word in
                                Text("\(word.arabic) - \(word.english)")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("\(viewModel.learnedWords.count)")
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                await viewModel.setupCamera()
            }
            .onDisappear {
                viewModel.stopCamera()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    // MARK: - Camera Loading View
    private var cameraLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Starting camera...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Camera Permission View
    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("Camera Access Required")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Point your camera at objects to learn their Arabic names")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    // MARK: - Recognition Result Card
    private func recognitionResultCard(_ result: RecognizedObject) -> some View {
        VStack(spacing: 16) {
            // Main word display
            VStack(spacing: 8) {
                Text(result.arabicName)
                    .font(.system(size: 48, weight: .bold))
                
                Text(result.transliteration)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text(result.englishName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Confidence indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(Int(result.confidence * 100))% confident")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.speakWord()
                    }
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    viewModel.clearRecognition()
                } label: {
                    Label("Scan Again", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Related words
            if !result.relatedWords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Related Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(result.relatedWords) { word in
                                RelatedWordChip(word: word)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }
    
    // MARK: - Capture Controls
    private var captureControls: some View {
        VStack(spacing: 20) {
            if viewModel.recognizedObject == nil {
                // Instructions
                Text("Point at an object and tap to capture")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                
                // Capture button
                Button {
                    viewModel.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 84, height: 84)
                    }
                }
                .disabled(viewModel.isProcessing || !viewModel.isCameraReady)
                .opacity(viewModel.isCameraReady ? 1.0 : 0.5)
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Recognizing object...")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Using Gemini Vision AI")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update session if needed
        if uiView.session !== session {
            uiView.session = session
        }
    }
}

class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPreviewLayer() {
        // Remove old layer
        previewLayer?.removeFromSuperlayer()
        
        guard let session = session else { return }
        
        let newLayer = AVCaptureVideoPreviewLayer(session: session)
        newLayer.videoGravity = .resizeAspectFill
        newLayer.frame = bounds
        layer.addSublayer(newLayer)
        previewLayer = newLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update preview layer frame when view layout changes
        previewLayer?.frame = bounds
    }
}

// MARK: - Related Word Chip
struct RelatedWordChip: View {
    let word: Word
    
    var body: some View {
        VStack(spacing: 4) {
            Text(word.arabic)
                .font(.subheadline.weight(.semibold))
            Text(word.english)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    CameraVocabView(viewModel: DependencyContainer.shared.makeCameraVocabViewModel())
}
