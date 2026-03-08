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
    
    // Animations
    @State private var pulseCapture = false
    @State private var showResult = false
    @State private var bounceEmoji = false
    @State private var starRotation: Double = 0
    @State private var floatingOffset: [CGFloat] = [0, 0, 0, 0, 0, 0]
    
    init(viewModel: CameraVocabViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Camera background
            Color.black.ignoresSafeArea()
            
            // Camera setup loading
            if viewModel.isSettingUpCamera {
                kidsLoadingView
            }
            // Camera permission view
            else if !viewModel.cameraPermissionGranted {
                kidsPermissionView
            }
            // Camera preview
            else if viewModel.isCameraReady, let session = viewModel.captureSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
            }
            
            // Kids overlay frame (always on top of camera)
            if viewModel.isCameraReady {
                kidsFrameOverlay
            }
            
            // Floating emojis
            if viewModel.isCameraReady && viewModel.recognizedObject == nil {
                floatingEmojis
            }
            
            // Overlay UI
            if viewModel.isCameraReady {
                VStack {
                    // Top bar
                    kidsTopBar
                    
                    Spacer()
                    
                    // Recognition result card
                    if let result = viewModel.recognizedObject {
                        kidsResultCard(result)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Capture button area
                    if viewModel.recognizedObject == nil {
                        kidsCaptureControls
                    }
                }
            }
            
            // Processing overlay
            if viewModel.isProcessing {
                kidsProcessingOverlay
            }
        }
        .task {
            await viewModel.setupCamera()
            startFloatingAnimation()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .onChange(of: viewModel.recognizedObject != nil) { _, hasResult in
            if hasResult {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showResult = true
                }
                // Auto-speak the Arabic word
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // small delay for card to appear
                    await viewModel.speakWord()
                }
            } else {
                showResult = false
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
    
    // MARK: - Kids Top Bar
    private var kidsTopBar: some View {
        HStack {
            // Close button
            Button(action: {
                viewModel.stopCamera()
                dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 44, height: 44)
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
            
            // Title
            HStack(spacing: 6) {
                Text("📸")
                    .font(.title2)
                Text("!اكتشف")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            
            Spacer()
            
            // Learned words count
            if !viewModel.learnedWords.isEmpty {
                ZStack {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 44, height: 44)
                    Text("\(viewModel.learnedWords.count)")
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                }
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Kids Frame Overlay
    private var kidsFrameOverlay: some View {
        ZStack {
            // Corner decorations
            VStack {
                HStack {
                    cornerDecoration(rotation: 0)
                    Spacer()
                    cornerDecoration(rotation: 90)
                }
                Spacer()
                HStack {
                    cornerDecoration(rotation: 270)
                    Spacer()
                    cornerDecoration(rotation: 180)
                }
            }
            .padding(30)
            
            // Scanning frame in center
            if viewModel.recognizedObject == nil && !viewModel.isProcessing {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink, .purple, .blue, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 250, height: 250)
                    .opacity(pulseCapture ? 0.6 : 1.0)
                    .scaleEffect(pulseCapture ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseCapture)
                    .onAppear { pulseCapture = true }
            }
        }
    }
    
    private func cornerDecoration(rotation: Double) -> some View {
        ZStack {
            // L-shaped corner
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 30, y: 0))
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 30))
            }
            .stroke(
                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
        }
        .rotationEffect(.degrees(rotation))
        .frame(width: 30, height: 30)
    }
    
    // MARK: - Floating Emojis
    private var floatingEmojis: some View {
        let emojis = ["🌟", "🎯", "🔍", "✨", "🎨", "💡"]
        let positions: [(CGFloat, CGFloat)] = [
            (50, 200), (320, 150), (80, 500),
            (300, 450), (180, 120), (250, 550)
        ]
        
        return ZStack {
            ForEach(0..<6, id: \.self) { i in
                Text(emojis[i])
                    .font(.title)
                    .offset(x: positions[i].0 - 180, y: positions[i].1 - 350 + floatingOffset[i])
                    .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func startFloatingAnimation() {
        for i in 0..<6 {
            let delay = Double(i) * 0.3
            let duration = Double.random(in: 2.0...3.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    floatingOffset[i] = CGFloat.random(in: -20...20)
                }
            }
        }
    }
    
    // MARK: - Kids Capture Controls
    private var kidsCaptureControls: some View {
        VStack(spacing: 16) {
            // Instruction bubble
            HStack(spacing: 8) {
                Text("👆")
                    .font(.title2)
                Text("صوّر أي حاجة!")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .purple.opacity(0.5), radius: 10, y: 5)
            )
            
            // Big fun capture button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    viewModel.capturePhoto()
                }
            } label: {
                ZStack {
                    // Outer rainbow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            ),
                            lineWidth: 6
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(starRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                starRotation = 360
                            }
                        }
                    
                    // Inner white circle
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)
                    
                    // Camera icon
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(pulseCapture ? 1.0 : 1.05)
            }
            .disabled(viewModel.isProcessing || !viewModel.isCameraReady)
            .opacity(viewModel.isCameraReady ? 1.0 : 0.5)
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Kids Result Card
    private func kidsResultCard(_ result: RecognizedObject) -> some View {
        VStack(spacing: 20) {
            // Big bouncing emoji based on category
            Text(emojiForObject(result.englishName))
                .font(.system(size: 70))
                .scaleEffect(bounceEmoji ? 1.2 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.4).repeatCount(3), value: bounceEmoji)
                .onAppear { bounceEmoji = true }
                .onDisappear { bounceEmoji = false }
            
            // Arabic word - BIG
            Text(result.arabicName)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Transliteration
            Text(result.transliteration)
                .font(.title2)
                .foregroundStyle(.gray)
            
            // English name
            Text(result.englishName)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            // Stars for confidence
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < Int(result.confidence * 5) ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                // Listen again
                Button {
                    Task { await viewModel.speakWord() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                        Text("اسمع تاني")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                
                // Scan again
                Button {
                    withAnimation(.spring()) {
                        viewModel.clearRecognition()
                        showResult = false
                        bounceEmoji = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("صوّر تاني")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.white)
                .shadow(color: .purple.opacity(0.3), radius: 20, y: 10)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Kids Loading View
    private var kidsLoadingView: some View {
        VStack(spacing: 20) {
            Text("📸")
                .font(.system(size: 60))
                .scaleEffect(pulseCapture ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseCapture)
                .onAppear { pulseCapture = true }
            
            Text("!الكاميرا بتجهز")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.yellow)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Kids Permission View
    private var kidsPermissionView: some View {
        VStack(spacing: 24) {
            Text("📷")
                .font(.system(size: 80))
            
            Text("!محتاجين الكاميرا")
                .font(.title.bold())
                .foregroundStyle(.white)
            
            Text("عشان تتعلم كلمات جديدة\n!صوّر أي حاجة حواليك")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("افتح الإعدادات")
                }
                .font(.headline.bold())
                .foregroundStyle(.purple)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(.white)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Kids Processing Overlay
    private var kidsProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Spinning magnifying glass
                Text("🔍")
                    .font(.system(size: 60))
                    .rotationEffect(.degrees(starRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            starRotation = 360
                        }
                    }
                
                Text("...بدوّر")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("!ثانية واحدة")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
    }
    
    // MARK: - Helpers
    private func emojiForObject(_ name: String) -> String {
        let lowered = name.lowercased()
        let emojiMap: [(String, String)] = [
            ("cat", "🐱"), ("dog", "🐶"), ("bird", "🐦"), ("fish", "🐟"),
            ("car", "🚗"), ("bus", "🚌"), ("bike", "🚲"), ("plane", "✈️"),
            ("apple", "🍎"), ("banana", "🍌"), ("orange", "🍊"), ("food", "🍕"),
            ("book", "📚"), ("pen", "🖊️"), ("phone", "📱"), ("computer", "💻"),
            ("cup", "☕"), ("bottle", "🍶"), ("glass", "🥛"), ("water", "💧"),
            ("flower", "🌸"), ("tree", "🌳"), ("plant", "🌱"), ("leaf", "🍃"),
            ("house", "🏠"), ("door", "🚪"), ("window", "🪟"), ("chair", "🪑"),
            ("table", "🪑"), ("lamp", "💡"), ("clock", "🕐"), ("key", "🔑"),
            ("shoe", "👟"), ("shirt", "👕"), ("hat", "🎩"), ("bag", "👜"),
            ("ball", "⚽"), ("toy", "🧸"), ("game", "🎮"), ("star", "⭐"),
            ("sun", "☀️"), ("moon", "🌙"), ("cloud", "☁️"), ("rain", "🌧️"),
            ("hand", "✋"), ("eye", "👁️"), ("heart", "❤️"), ("face", "😊"),
            ("milk", "🥛"), ("bread", "🍞"), ("egg", "🥚"), ("rice", "🍚"),
            ("mouse", "🐭"), ("rabbit", "🐰"), ("bear", "🐻"), ("lion", "🦁"),
            ("keyboard", "⌨️"), ("screen", "🖥️"), ("camera", "📷"), ("tv", "📺"),
        ]
        
        for (keyword, emoji) in emojiMap {
            if lowered.contains(keyword) {
                return emoji
            }
        }
        return "🎯" // Default emoji
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
        previewLayer?.frame = bounds
    }
}

#Preview {
    CameraVocabView(viewModel: DependencyContainer.shared.makeCameraVocabViewModel())
}
