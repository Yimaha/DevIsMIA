import AVFoundation
import Vision

final class PresenceDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onFrame: ((Bool) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "PresenceLock.session")
    private let frameQueue = DispatchQueue(label: "PresenceLock.frames")
    private var input: AVCaptureDeviceInput?
    private var lastAnalysis = Date.distantPast

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        session.addOutput(output)
    }

    func start() {
        sessionQueue.async { [self] in
            let device = bestDevice()
            if device != input?.device {
                session.beginConfiguration()
                if let input { session.removeInput(input) }
                input = nil
                if let newInput = device.flatMap({ try? AVCaptureDeviceInput(device: $0) }), session.canAddInput(newInput) {
                    session.addInput(newInput)
                    input = newInput
                }
                if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
                session.commitConfiguration()
            }
            if input == nil {
                if session.isRunning { session.stopRunning() }
            } else if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func bestDevice() -> AVCaptureDevice? {
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices.filter { $0.isConnected && !$0.isSuspended }
        return cameras.first { $0.deviceType == .builtInWideAngleCamera } ?? cameras.first
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) >= 1, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now

        let faces = VNDetectFaceRectanglesRequest()
        let bodies = VNDetectHumanRectanglesRequest()
        bodies.upperBodyOnly = true
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixels, options: [:]).perform([faces, bodies])
        } catch {
            return
        }
        let personPresent = !(faces.results ?? []).isEmpty || !(bodies.results ?? []).isEmpty
        DispatchQueue.main.async { self.onFrame?(personPresent) }
    }
}
