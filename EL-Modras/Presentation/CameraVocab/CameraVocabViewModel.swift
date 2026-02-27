//
//  CameraVocabViewModel.swift
//  EL-Modras
//
//  Created by Taher on 04/09/1447 AH.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class CameraVocabViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var recognizedObject: RecognizedObject?
    @Published var isProcessing = false
    @Published var isCapturing = false
    @Published var isCameraReady = false
    @Published var isSettingUpCamera = false
    @Published var error: String?
    @Published var capturedImage: Data?
    @Published var learnedWords: [Word] = []
    @Published var cameraPermissionGranted = false
    
    // MARK: - Camera Properties
    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Dependencies
    private let recognizeObjectUseCase: RecognizeObjectUseCase
    private let learnWordUseCase: LearnWordUseCase
    private let audioService: AudioService
    private let geminiService: GeminiService
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        recognizeObjectUseCase: RecognizeObjectUseCase,
        learnWordUseCase: LearnWordUseCase,
        audioService: AudioService,
        geminiService: GeminiService
    ) {
        self.recognizeObjectUseCase = recognizeObjectUseCase
        self.learnWordUseCase = learnWordUseCase
        self.audioService = audioService
        self.geminiService = geminiService
        super.init()
    }
    
    // MARK: - Camera Setup
    func setupCamera() async {
        isSettingUpCamera = true
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraPermissionGranted = true
            await setupCaptureSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionGranted = granted
            if granted {
                await setupCaptureSession()
            }
        default:
            cameraPermissionGranted = false
        }
        
        isSettingUpCamera = false
    }
    
    private func setupCaptureSession() async {
        // Create session on main thread
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Get camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = "Could not find camera"
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            // Configure session
            session.beginConfiguration()
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                error = "Could not add camera input"
                session.commitConfiguration()
                return
            }
            
            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                photoOutput = output
            } else {
                error = "Could not add photo output"
                session.commitConfiguration()
                return
            }
            
            session.commitConfiguration()
            
            // Set captureSession BEFORE starting
            captureSession = session
            
            // Start session on background thread and wait for it
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                    
                    // Small delay to ensure camera is fully ready
                    Thread.sleep(forTimeInterval: 0.3)
                    
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                }
            }
            
            isCapturing = true
            isCameraReady = true
            
        } catch {
            self.error = "Camera setup failed: \(error.localizedDescription)"
        }
    }
    
    func stopCamera() {
        isCameraReady = false
        isCapturing = false
        
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
    }
    
    // MARK: - Capture & Recognition
    func capturePhoto() {
        guard isCameraReady else {
            error = "Camera not ready yet"
            return
        }
        
        guard let photoOutput = photoOutput else {
            error = "Camera not configured"
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func recognizeObject(from imageData: Data) async {
        isProcessing = true
        error = nil
        capturedImage = imageData
        
        do {
            let result = try await recognizeObjectUseCase.execute(imageData: imageData)
            recognizedObject = result
            
            // Add to learned words if not already there
            let newWord = Word(
                english: result.englishName,
                arabic: result.arabicName,
                transliteration: result.transliteration,
                category: .household // Default category
            )
            
            if !learnedWords.contains(where: { $0.arabic == newWord.arabic }) {
                learnedWords.append(newWord)
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isProcessing = false
    }
    
    func learnWord(_ word: Word) async {
        do {
            try await learnWordUseCase.execute(
                wordId: word.id,
                userId: "current_user" // In production, get from auth
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func speakWord() async {
        guard let word = recognizedObject else { return }
        // Use Gemini's natural voice for speaking
        await audioService.speakNaturalArabic(word.arabicName, using: geminiService)
    }
    
    func clearRecognition() {
        recognizedObject = nil
        capturedImage = nil
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraVocabViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = error.localizedDescription
                return
            }
            
            guard let imageData = photo.fileDataRepresentation() else {
                self.error = "Could not process photo"
                return
            }
            
            await recognizeObject(from: imageData)
        }
    }
}
