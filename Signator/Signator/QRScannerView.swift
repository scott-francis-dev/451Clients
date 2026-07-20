// QRScannerView.swift
// QR code scanner using AVFoundation for camera access

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = true
    @State private var showPermissionAlert = false

    var onCodeScanned: ((String) -> Void)?

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(onCodeScanned: { code in
                isScanning = false
                onCodeScanned?(code)
                dismiss()
            }, isScanning: $isScanning)
                .edgesIgnoringSafeArea(.all)

            // Scanning frame overlay
            VStack {
                Spacer()

                // Viewfinder rectangle
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .overlay {
                        // Corner accents
                        GeometryReader { geo in
                            let size = geo.size
                            Path { path in
                                // Top-left
                                path.move(to: CGPoint(x: 0, y: 30))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 30, y: 0))

                                // Top-right
                                path.move(to: CGPoint(x: size.width - 30, y: 0))
                                path.addLine(to: CGPoint(x: size.width, y: 0))
                                path.addLine(to: CGPoint(x: size.width, y: 30))

                                // Bottom-right
                                path.move(to: CGPoint(x: size.width, y: size.height - 30))
                                path.addLine(to: CGPoint(x: size.width, y: size.height))
                                path.addLine(to: CGPoint(x: size.width - 30, y: size.height))

                                // Bottom-left
                                path.move(to: CGPoint(x: 30, y: size.height))
                                path.addLine(to: CGPoint(x: 0, y: size.height))
                                path.addLine(to: CGPoint(x: 0, y: size.height - 30))
                            }
                            .stroke(Color.blue, lineWidth: 4)
                        }
                    }

                Text("Point camera at QR code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .navigationTitle("Scan QR Code")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please allow camera access in Settings to scan QR codes.")
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    @Binding var isScanning: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let captureSession = AVCaptureSession()
        context.coordinator.captureSession = captureSession

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ Failed to get video capture device")
            return view
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("❌ Failed to create video input")
            return view
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("❌ Failed to add video input to session")
            return view
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            print("❌ Failed to add metadata output to session")
            return view
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }

        context.coordinator.isScanning = isScanning
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, isScanning: isScanning)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.captureSession?.stopRunning()
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        var isScanning: Bool
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?

        init(onCodeScanned: @escaping (String) -> Void, isScanning: Bool) {
            self.onCodeScanned = onCodeScanned
            self.isScanning = isScanning
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard isScanning else { return }

            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }

                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                print("📷 QR Code scanned: \(stringValue)")
                onCodeScanned(stringValue)
            }
        }
    }
}

#else

// MARK: - Fallback (macOS, visionOS)
// Camera-based QR scanning relies on AVFoundation's capture pipeline, which is
// only available on iPhone and iPad. macOS lacks UIKit's camera preview layer,
// and visionOS doesn't expose general-purpose camera capture to apps. This
// fallback keeps the exact same `QRScannerView(onCodeScanned:)` API so every
// call site compiles on all platforms the Signator app ships to; users on these
// platforms enter the access code / token manually instead.
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var onCodeScanned: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Scanning Not Available")
                .font(.title2.weight(.semibold))

            Text("QR code scanning requires the camera on an iPhone or iPad. Please enter the code manually instead.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Scan QR Code")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#endif
