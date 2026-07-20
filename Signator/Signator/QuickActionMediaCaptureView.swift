import SwiftUI
import CoreLocation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct QuickActionMediaCaptureView: View {
    let title: String

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @EnvironmentObject private var personaManager: PersonaManager
    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var cameraManager = CameraSessionManager()
    @State private var photos: [CapturedMedia] = []
    @State private var videos: [CapturedMedia] = []
    @State private var errorMessage: String?
    @State private var showPermissionAlert = false
    @State private var hasCameraAccess = false
    @State private var now = Date()
    @State private var videoWindowEndsAt: Date?
    @State private var currentCaptureSessionId = UUID().uuidString
    @State private var capturePairIndex = 0
    @State private var isCapturingKeystone = false

    private var isVideoWindowActive: Bool {
        guard let endsAt = videoWindowEndsAt else { return false }
        return now <= endsAt
    }

    private var videoWindowRemainingString: String {
        guard let endsAt = videoWindowEndsAt else { return "Closed" }
        let remaining = max(0, Int(endsAt.timeIntervalSince(now)))
        guard remaining > 0 else { return "Closed" }
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topOverlay
                cameraStage
                bottomOverlay
            }
        }
        .onAppear {
            locationProvider.requestAuthorizationIfNeeded()
            checkCameraPermission()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                #if canImport(UIKit)
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
                #endif
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to capture witness media.")
        }
        .onReceive(ticker) { value in
            now = value
        }
    }

    private var topOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "bolt.slash")
                    .foregroundColor(.white.opacity(0.8))
            }

            HStack(spacing: 16) {
                statusPill(label: "Photos", value: "\(photos.count)/2", isReady: photos.count >= 2)
                statusPill(label: "Video", value: videos.isEmpty ? "Optional" : "Added", isReady: !videos.isEmpty)
                statusPill(label: "GPS", value: locationProvider.location == nil ? "Searching" : "Locked", isReady: locationProvider.location != nil)
                statusPill(label: "Window", value: videoWindowRemainingString, isReady: isVideoWindowActive)
                statusPill(label: "REC", value: cameraManager.recordingDurationString, isReady: cameraManager.isRecording)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var cameraStage: some View {
        ZStack(alignment: .bottomLeading) {
            CameraPreviewView(session: cameraManager.session)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                captureInfoRow(title: "Timestamp", value: formattedNow())
                captureInfoRow(title: "Latitude", value: formattedCoordinate(locationProvider.location?.coordinate.latitude))
                captureInfoRow(title: "Longitude", value: formattedCoordinate(locationProvider.location?.coordinate.longitude))
                captureInfoRow(title: "Altitude", value: formattedValue(locationProvider.location?.altitude, suffix: "m"))
                captureInfoRow(title: "Accuracy", value: formattedValue(locationProvider.location?.horizontalAccuracy, suffix: "m"))
            }
            .padding(20)
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            HStack(spacing: 16) {
                Button {
                    captureKeystonePair()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Capture")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCapturingKeystone || cameraManager.isRecording)

                Button {
                    toggleVideoRecording()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cameraManager.isRecording ? "stop.fill" : "video.fill")
                            .font(.title2)
                        Text(cameraManager.isRecording ? "Stop" : "Video")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(!isVideoWindowActive || photos.count < 2 || isCapturingKeystone)
            }

            if !photos.isEmpty {
                mediaSection(title: "Photos", items: photos)
            }

            if !videos.isEmpty {
                mediaSection(title: "Video", items: videos)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func mediaSection(title: String, items: [CapturedMedia]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(items.count))")
                .font(.headline)
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            mediaThumbnail(for: item)
                            Text(item.filename)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func statusPill(label: String, value: String, isReady: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.caption)
                .foregroundColor(isReady ? .green : .white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func captureInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    private func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm:ss a"
        return formatter.string(from: Date())
    }

    private func formattedCoordinate(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.6f", value)
    }

    private func formattedValue(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f %@", value, suffix)
    }

    private func mediaThumbnail(for item: CapturedMedia) -> some View {
        ZStack {
            if let image = item.image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else if item.type == .video {
                ZStack {
                    Color.black.opacity(0.1)
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                }
            } else {
                Color.black.opacity(0.05)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func appendPhotos(_ newPhotos: [PlatformImage]) {
        guard !newPhotos.isEmpty else { return }
        let timestamp = fileTimestamp()
        for (index, image) in newPhotos.enumerated() {
            let filename = "PhotoAttachment_\(timestamp)_\(index + photos.count + 1).jpg"
            let metadata = buildMetadata(filename: filename, type: .photo)
            let item = CapturedMedia(
                type: .photo,
                image: image,
                videoURL: nil,
                filename: filename,
                metadata: metadata
            )
            photos.append(item)
        }
    }

    private func appendVideos(_ newVideos: [URL]) {
        guard !newVideos.isEmpty else { return }
        let timestamp = fileTimestamp()
        for (index, url) in newVideos.enumerated() {
            let filename = "VideoAttachment_\(timestamp)_\(index + videos.count + 1).mov"
            let metadata = buildMetadata(filename: filename, type: .video)
            let item = CapturedMedia(
                type: .video,
                image: nil,
                videoURL: url,
                filename: filename,
                metadata: metadata
            )
            videos.append(item)
        }
    }

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            guard let image else {
                errorMessage = "Unable to capture photo."
                return
            }
            appendPhotos([image])
        }
    }

    private func captureKeystonePair() {
        guard hasCameraAccess else {
            errorMessage = "Camera access is required to capture photos."
            showPermissionAlert = true
            return
        }
        guard !isCapturingKeystone else { return }
        errorMessage = nil
        isCapturingKeystone = true
        let sessionId = UUID().uuidString
        currentCaptureSessionId = sessionId
        captureKeystonePhoto(sessionId: sessionId, remaining: 2)
    }

    private func captureKeystonePhoto(sessionId: String, remaining: Int) {
        cameraManager.capturePhoto { image in
            guard sessionId == currentCaptureSessionId else { return }
            guard let image else {
                errorMessage = "Unable to capture photo."
                isCapturingKeystone = false
                return
            }

            appendPhotos([image])

            if remaining > 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    captureKeystonePhoto(sessionId: sessionId, remaining: remaining - 1)
                }
            } else {
                isCapturingKeystone = false
                capturePairIndex += 1
                videoWindowEndsAt = Date().addingTimeInterval(60)
            }
        }
    }

    private func toggleVideoRecording() {
        guard hasCameraAccess else {
            errorMessage = "Camera access is required to capture video."
            showPermissionAlert = true
            return
        }
        if cameraManager.isRecording {
            cameraManager.stopRecording()
        } else {
            cameraManager.startRecording { url in
                appendVideos([url])
            }
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraAccess = true
            cameraManager.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    hasCameraAccess = granted
                    if granted {
                        cameraManager.start()
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
            hasCameraAccess = false
        @unknown default:
            break
        }
    }

    private func buildMetadata(filename: String, type: CapturedMediaType) -> CaptureMediaMetadata {
        let now = Date()
        let location = locationProvider.location
        let locationSnapshot = CaptureLocationSnapshot(location: location, timestamp: now)
        return CaptureMediaMetadata(
            type: type,
            timestamp: now,
            location: locationSnapshot,
            filename: filename
        )
    }

    private func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return formatter.string(from: Date())
    }
}

enum CapturedMediaType: String, Codable {
    case photo
    case video
}

struct CapturedMedia: Identifiable {
    let id = UUID()
    let type: CapturedMediaType
    let image: PlatformImage?
    let videoURL: URL?
    let filename: String
    let metadata: CaptureMediaMetadata
}

struct CaptureMediaMetadata: Codable {
    let type: CapturedMediaType
    let timestamp: Date
    let location: CaptureLocationSnapshot
    let filename: String
}

struct CaptureLocationSnapshot: Codable {
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let altitude: Double?
    let speed: Double?
    let course: Double?
    let timestamp: Date

    init(location: CLLocation?, timestamp: Date) {
        latitude = location?.coordinate.latitude
        longitude = location?.coordinate.longitude
        horizontalAccuracy = location?.horizontalAccuracy
        verticalAccuracy = location?.verticalAccuracy
        altitude = location?.altitude
        speed = location?.speed
        course = location?.course
        self.timestamp = timestamp
    }
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorizationIfNeeded() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized(status) {
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isAuthorized(manager.authorizationStatus) {
            manager.startUpdatingLocation()
        }
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorizedAlways
        #else
        return status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}

final class CameraSessionManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var isConfigured = false
    private var photoDelegates: [PhotoCaptureDelegate] = []
    private var pendingVideoCompletion: ((URL) -> Void)?
    private var recordingTimer: Timer?

    func start() {
        sessionQueue.async {
            self.configureIfNeeded()
            guard !self.session.isRunning else { return }
            self.configureAudioSession()
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (PlatformImage?) -> Void) {
        sessionQueue.async {
            self.configureIfNeeded()
            let settings = AVCapturePhotoSettings()
            var delegate: PhotoCaptureDelegate?
            delegate = PhotoCaptureDelegate { [weak self] image in
                DispatchQueue.main.async {
                    completion(image)
                }
                if let delegate {
                    self?.photoDelegates.removeAll { $0 === delegate }
                }
            }
            if let delegate {
                self.photoDelegates.append(delegate)
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    func startRecording(completion: @escaping (URL) -> Void) {
        sessionQueue.async {
            self.configureIfNeeded()
            guard !self.movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            self.pendingVideoCompletion = completion
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                self.startTimer()
            }
        }
    }

    func stopRecording() {
        sessionQueue.async {
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func startTimer() {
        recordingDuration = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            // Ignore audio session errors; video can still record silently.
        }
        #endif
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }

    var recordingDurationString: String {
        let totalSeconds = Int(recordingDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension CameraSessionManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimer()
        }
        guard error == nil else { return }
        if let completion = pendingVideoCompletion {
            DispatchQueue.main.async {
                completion(outputFileURL)
            }
        }
        pendingVideoCompletion = nil
    }
}

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (PlatformImage?) -> Void

    init(completion: @escaping (PlatformImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = PlatformImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}

#if canImport(UIKit)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer()
    }
}
#elseif canImport(AppKit)
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}
}

final class PreviewView: NSView {
    let videoPreviewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = videoPreviewLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
