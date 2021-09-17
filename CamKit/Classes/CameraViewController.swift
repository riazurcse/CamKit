//
//  CameraViewController.swift
//  CamKit
//
//  Created by Mohammad Riajur Rahman on 16/9/21.
//

import Foundation
import UIKit
import AVFoundation

public enum MediaType: String {
    case photo
    case video
    case unknown
}

public class CameraViewController: UIViewController {
    
    @IBOutlet weak var videoLengthCounter: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var hdrButton: UIButton!
    @IBOutlet weak var recorderButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var zoomLabel: UILabel!
    public var captureVideoCompletion: ((URL?) -> Void) = { _ in }
    public var capturePhotoCompletion: ((UIImage?) -> Void) = { _ in }

    public var mediaType: MediaType = .video
    var timer: Timer?
    var timeCounter = 0
    var cameraConfig: CameraConfiguration!
    var videoRecordingStarted: Bool = false {
        didSet {
            if videoRecordingStarted {
                self.recorderButton.setBackgroundImage(UIImage().getImage(named: "ic_recording_stop"), for: .normal)
            } else {
                self.recorderButton.setBackgroundImage(UIImage().getImage(named: "ic_recording_start"), for: .normal)
            }
        }
    }

    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 3.0
    var lastZoomFactor: CGFloat = 1.0

    public static func get(for type: MediaType) -> CameraViewController? {
        guard let storyboard = UIStoryboard().getStoryboard() else {
            return nil
        }
        guard let cameraVC = storyboard.instantiateViewController(withIdentifier: "CameraViewController") as? CameraViewController else {
            return nil
        }
        cameraVC.mediaType = type
        cameraVC.modalPresentationStyle = .fullScreen
        return cameraVC
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraConfig = CameraConfiguration()
        self.cameraConfig.outputType = mediaType == .video ? .video : .photo
        self.cameraConfig.flashMode = .off
        self.cameraConfig.setup { error in
            if error != nil {
                print(error!.localizedDescription)
            }
            try? self.cameraConfig.displayPreview(self.previewImageView)
        }
        if mediaType == .video {
            self.hdrButton.isHidden = false
            self.videoLengthCounter.isHidden = false
            self.updateVideoModeButton(title: VideoMode.p_720.rawValue)
            self.recorderButton.setBackgroundImage(UIImage().getImage(named: "ic_recording_start"), for: .normal)
        } else {
            self.hdrButton.isHidden = true
            self.videoLengthCounter.isHidden = true
            self.recorderButton.setBackgroundImage(UIImage().getImage(named: "ic_capture_image"), for: .normal)
        }
        self.updateZoomLabel(scaleFactor: lastZoomFactor)
        self.previewImageView.isUserInteractionEnabled = true
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(pinch(_:)))
                    self.previewImageView.addGestureRecognizer(pinchRecognizer)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    private func updateVideoModeButton(title: String?) {
        self.hdrButton.setTitle(title, for: .normal)
    }

    private func updateZoomLabel(scaleFactor: CGFloat) {
        self.zoomLabel.text = "\(Int(scaleFactor))x"
    }

    @objc func updateTime() {
        timeCounter += 1
        self.hoursMinsSecsFrom(seconds: timeCounter) { hours, minutes, seconds in
            let hours = self.getStringFrom(seconds: hours)
            let minutes = self.getStringFrom(seconds: minutes)
            let seconds = self.getStringFrom(seconds: seconds)
            self.videoLengthCounter.text = "\(hours): \(minutes): \(seconds)"
        }
    }
    
    func resetTimer() {
        timeCounter = 0
        self.timer?.invalidate()
        self.videoLengthCounter.text = "00: 00: 00"
    }
    
    func resetButtonState(enabled: Bool) {
        self.hdrButton.isEnabled = enabled
        self.flipButton.isEnabled = enabled
        self.hdrButton.alpha = enabled ? 1 : 0.5
        self.flipButton.alpha = enabled ? 1 : 0.5
    }

    func updateFlashButtonState() {
        var enabled = true
        if cameraConfig.currentCameraPosition == .front {
            enabled = false
        }
        self.flashButton.isEnabled = enabled
        self.flashButton.alpha = enabled ? 1 : 0.5
    }
    
    func updateFashMode(isOn: Bool? = nil) {
        if let isOn = isOn {
            if !isOn {
                cameraConfig.flashMode = .off
                self.flashButton.setImage(UIImage().getImage(named: "ic_flash_off"), for: .normal)
            } else {
                cameraConfig.flashMode = .on
                self.flashButton.setImage(UIImage().getImage(named: "ic_flash_on"), for: .normal)
            }
        } else {
            if cameraConfig.flashMode == .on {
                cameraConfig.flashMode = .off
                self.flashButton.setImage(UIImage().getImage(named: "ic_flash_off"), for: .normal)
            } else if cameraConfig.flashMode == .off {
                cameraConfig.flashMode = .on
                self.flashButton.setImage(UIImage().getImage(named: "ic_flash_on"), for: .normal)
            }
        }
    }

    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        if mediaType == .video {
            self.resetTimer()
            self.cameraConfig.stopRecording { error in
                if error == nil {
                    print("OK")
                }
            }
            self.captureVideoCompletion(nil)
        } else {
            self.capturePhotoCompletion(nil)
        }
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func toggleFlashButton(_ sender: UIButton) {
        self.updateFashMode()
        cameraConfig.setFlashMode()
    }

    @IBAction func captureButtonTapped(_ sender: UIButton) {
        if mediaType == .video {
            self.recorderButton.alpha = 0
            UIView.animate(withDuration: 1, delay: 0.1, options: .transitionCurlDown) {
                self.recorderButton.alpha = 1
                if self.videoRecordingStarted {
                    self.videoRecordingStarted = false
                    self.resetButtonState(enabled: true)
                    self.resetTimer()
                    self.cameraConfig.stopRecording { _ in }
                } else if !self.videoRecordingStarted {
                    self.videoRecordingStarted = true
                    self.resetButtonState(enabled: false)
                    self.startTimer()
                    self.cameraConfig.recordVideo { url, error in
                        self.captureVideoCompletion(url)
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        } else {
            self.cameraConfig.captureImage { image, error in
                if self.cameraConfig.currentCameraPosition == .front {
                    if let invertedImage = image {
                        self.capturePhotoCompletion(UIImage(cgImage: invertedImage.cgImage!, scale: invertedImage.scale, orientation: .leftMirrored))
                    } else {
                        self.capturePhotoCompletion(nil)
                    }
                } else {
                    self.capturePhotoCompletion(image)
                }
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBAction func cameraFlipButtonTapped(_ sender: UIButton) {
        do {
            self.updateFashMode(isOn: false)
            cameraConfig.setFlashMode(isOn: false)
            try cameraConfig.switchCameras()
            if mediaType == .video {
                cameraConfig.updateVideoOutput()
            }
            self.updateFlashButtonState()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @IBAction func toggleHDRButton(_ sender: UIButton) {
        switch cameraConfig.videoMode {
        case .p_720:
            self.cameraConfig.changeVideo(mode: .p_1080)
            self.updateVideoModeButton(title: VideoMode.p_1080.rawValue)
        case .p_1080:
            self.cameraConfig.changeVideo(mode: .p_2160)
            self.updateVideoModeButton(title: VideoMode.p_2160.rawValue)
        case .p_2160:
            self.cameraConfig.changeVideo(mode: .p_720)
            self.updateVideoModeButton(title: VideoMode.p_720.rawValue)
        }
    }

    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        guard let cameraPosition = cameraConfig.currentCameraPosition else {
            return
        }

        var device: AVCaptureDevice?
        if cameraPosition == .front {
            device = cameraConfig.frontCameraInput?.device
        } else {
            device = cameraConfig.rearCameraInput?.device
        }

        guard let inputDevice = device else { return }

        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), inputDevice.activeFormat.videoMaxZoomFactor)
        }

        func update(scale factor: CGFloat) {
            do {
                try inputDevice.lockForConfiguration()
                defer { inputDevice.unlockForConfiguration() }
                inputDevice.videoZoomFactor = factor
            } catch let error {
                print(error.localizedDescription)
            }
        }

        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        self.updateZoomLabel(scaleFactor: newScaleFactor)
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    func hoursMinsSecsFrom(seconds: Int, completion: @escaping (Int, Int, Int) -> Void) {
        completion(seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    func getStringFrom(seconds: Int) -> String {
        return seconds < 10 ? "0\(seconds)" : "\(seconds)"
    }
}

public extension Bundle {
    func getResourceBundle() -> Bundle? {
        let bundle = Bundle(for: CameraViewController.self)
        guard let path = bundle.path(forResource: "Resources", ofType: "bundle") else {
            return nil
        }
        return Bundle(url: URL(fileURLWithPath: path))
    }
}

public extension UIStoryboard {
    func getStoryboard() -> UIStoryboard? {
        guard let bundle = Bundle().getResourceBundle() else {
            return nil
        }
        return UIStoryboard(name: "CamKit", bundle: bundle)
    }
}

public extension UIImage {
    func getImage(named: String) -> UIImage? {
        guard let bundle = Bundle().getResourceBundle() else {
            return nil
        }
        return UIImage(named: named, in: bundle, compatibleWith: nil)
    }
}
