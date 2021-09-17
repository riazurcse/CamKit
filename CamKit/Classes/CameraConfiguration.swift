//
//  CameraConfiguration.swift
//  CamKit
//
//  Created by Mohammad Riajur Rahman on 16/9/21.
//

import Foundation
import AVFoundation
import UIKit

public enum VideoMode: String {
    case p_720 = "720p"
    case p_1080 = "1080p"
    case p_2160 = "4K"
}

public class CameraConfiguration: NSObject {
    
    public enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    public enum OutputType {
        case photo
        case video
    }

    var videoMode: VideoMode = .p_720
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var audioDevice: AVCaptureDevice?
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var flashMode: AVCaptureDevice.FlashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var videoRecordCompletionBlock: ((URL?, Error?) -> Void)?
    
    var videoOutput: AVCaptureMovieFileOutput?
    var audioInput: AVCaptureDeviceInput?
    var outputType: OutputType?
}

public extension CameraConfiguration {

    func setup(handler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.videoMode = .p_720
            self.captureSession = AVCaptureSession()
            self.captureSession?.beginConfiguration()
            self.captureSession?.sessionPreset = .hd1280x720
            self.captureSession?.commitConfiguration()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
            
            let cameras = (session.devices.compactMap{$0})

            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
            self.audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        }
        
        //Configure inputs with capture session
        //only allows one camera-based input per capture session at a time.
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                    self.currentCameraPosition = .rear
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
            }
                
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                    self.currentCameraPosition = .front
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
            }
                
            else {
                throw CameraControllerError.noCamerasAvailable
            }
            
            if let audioDevice = self.audioDevice {
                self.audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if captureSession.canAddInput(self.audioInput!) {
                    captureSession.addInput(self.audioInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
            }
        }
        
        //Configure outputs with capture session
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg ])], completionHandler: nil)
            if captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addOutput(self.photoOutput!)
            }
            self.outputType = .photo
            captureSession.startRunning()
        }
        
        func configureVideoOutput() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }

            self.videoOutput = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(self.videoOutput!) {
                captureSession.addOutput(self.videoOutput!)
                if let connection = videoOutput?.connection(with: .video) {
                    if  connection.isVideoMirroringSupported {
                        if self.currentCameraPosition == .front {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = true
                        } else {
                            connection.automaticallyAdjustsVideoMirroring = true
                        }
                    }
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
            }
        }
        
        DispatchQueue(label: "setup").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
                try configureVideoOutput()
            } catch {
                DispatchQueue.main.async {
                    handler(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                handler(nil)
            }
        }
    }
    
    func displayPreview(_ view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: view.frame.width , height: view.frame.height)
    }
    
    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        captureSession.beginConfiguration()
        let inputs = captureSession.inputs
        
        func switchToFrontCamera() throws {
            guard let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            captureSession.removeInput(rearCameraInput)
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                self.currentCameraPosition = .front
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        
        func switchToRearCamera() throws {
            guard let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput), let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            captureSession.removeInput(frontCameraInput)
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            if captureSession.canAddInput(rearCameraInput!) {
                captureSession.addInput(rearCameraInput!)
                self.currentCameraPosition = .rear
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        captureSession.commitConfiguration()
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = self.captureSession, captureSession.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing)
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
    func recordVideo(completion: @escaping (URL?, Error?)-> Void) {
        guard let captureSession = self.captureSession, captureSession.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing)
            return
        }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("recording_output.mp4")
        try? FileManager.default.removeItem(at: fileUrl)
        videoOutput!.startRecording(to: fileUrl, recordingDelegate: self)
        self.videoRecordCompletionBlock = completion
    }
    
    func stopRecording(completion: @escaping (Error?)->Void) {
        guard let captureSession = self.captureSession, captureSession.isRunning else {
            completion(CameraControllerError.captureSessionIsMissing)
            return
        }
        self.videoOutput?.stopRecording()
    }

    func setFlashMode(isOn: Bool? = nil) {
        if let currentDevice = AVCaptureDevice.default(for: .video), currentDevice.hasTorch {
            do {
                try currentDevice.lockForConfiguration()
                let torchOn = !currentDevice.isTorchActive
                try currentDevice.setTorchModeOn(level: 1.0)
                if let isOn = isOn {
                    currentDevice.torchMode = isOn ? .on : .off
                } else {
                    currentDevice.torchMode = torchOn ? .on : .off
                }
                currentDevice.unlockForConfiguration()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    func changeVideo(mode: VideoMode) {
        self.videoMode = mode
        self.captureSession?.beginConfiguration()
        switch mode {
        case .p_720:
            self.captureSession?.sessionPreset = .hd1280x720
        case .p_1080:
            self.captureSession?.sessionPreset = .hd1920x1080
        case .p_2160:
            self.captureSession?.sessionPreset = .hd4K3840x2160
        }
        self.captureSession?.commitConfiguration()
    }

    func updateVideoOutput() {
        if self.videoOutput != nil {
            if let connection = videoOutput?.connection(with: .video) {
                if  connection.isVideoMirroringSupported {
                    if self.currentCameraPosition == .front {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    } else {
                        connection.automaticallyAdjustsVideoMirroring = true
                    }
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
    }
}

extension CameraConfiguration: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        if let data = photo.fileDataRepresentation() {
            let image = UIImage(data: data)
            self.photoCaptureCompletionBlock?(image, nil)
        }
        else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }

    func convert(cImage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cImage, from: cImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
}

extension CameraConfiguration: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            self.videoRecordCompletionBlock?(outputFileURL, nil)
        } else {
            self.videoRecordCompletionBlock?(nil, error)
        }
    }
}
