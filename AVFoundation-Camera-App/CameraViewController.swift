//
//  ViewController.swift
//  AVFoundation-Camera-App
//
//  Created by N. M on 2021/07/11.
//

import UIKit
import Photos
import AVFoundation

final class CameraViewController: UIViewController {
    
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var changeModeSegmentControl: UISegmentedControl!
    
    private let captureSession = AVCaptureSession()
    private var captureVideoLayer: AVCaptureVideoPreviewLayer!
    private let photoOutput = AVCapturePhotoOutput()
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    private var currentDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var settingsForMonitoring =  AVCapturePhotoSettings()
    
    private let sessionQueue = DispatchQueue(label: "session_queue")
    
    private var setupResult: SessionSetupResult = .success // Session Setup Result
    enum SessionSetupResult {
        case success // Success
        case notAuthorized // No permisson to Camera device or Photo album
        case configurationFailed // Failed
    }
    
    private var shootingMode: ShootingMode = .photo // Shooting Mode
    enum ShootingMode: Int {
        case photo
        case video
    }
    
    private var captureState: captureState = .wait // VideoCapture State
    enum captureState: Int {
        case wait
        case capturing
    }
    
    private var compressedData: Data?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.checkPermission()
        
        self.sessionQueue.async {
            self.configureSession()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.captureSession.startRunning()
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "AVFoundation-Camera-App",
                                                            message: "AVFoundation-Camera-App doesn't have permission to use the camera.",
                                                            preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "OK",
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: "Settings",
                                                            style: .default,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "AVFoundation-Camera-App",
                                                            message: "AVFoundation-Camera-App doesn't have permission to use the photo album",
                                                            preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "OK",
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
    }
    
    
    /**
     @brief Check camera and photo library permission.
     */
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
            
        case .notDetermined:
            self.sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                  self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            self.setupResult = .notAuthorized
            break
        }
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            break
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ photoAuthStatus in
                if photoAuthStatus ==  PHAuthorizationStatus.authorized {
                }
            })
            
        default :
            break
        }
    }
    
    
    /**
     @brief Configure session for launch the app.
     */
    private func configureSession() {
        guard setupResult == .success else {
            DispatchQueue.main.async {
                self.shutterButton.isEnabled = false
                self.changeModeSegmentControl.isEnabled = false
            }
            return
        }
        
        self.captureSession.beginConfiguration()
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                self.setupResult = .configurationFailed
                self.captureSession.commitConfiguration()
                return
            }
            
            self.currentDevice = videoDevice
            
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.videoDeviceInput = input
                
                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                    
                    self.captureVideoLayer = AVCaptureVideoPreviewLayer.init(session: self.captureSession)
                    self.captureVideoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                    
                    DispatchQueue.main.async {
                        self.captureVideoLayer.frame = self.previewImageView.bounds
                        self.previewImageView.contentMode = .scaleAspectFill
                        self.previewImageView.layer.addSublayer(self.captureVideoLayer)
                    }
                }
                self.captureSession.sessionPreset = AVCaptureSession.Preset.photo
            }
        } catch {
            print("Error configure capture session : \(error)")
            
            self.setupResult = .configurationFailed
            self.captureSession.commitConfiguration()
            return
        }
        self.captureSession.commitConfiguration()
    }
    
    
    /**
     @brief Change session for capturing photo.
     */
    private func chagePhotoMode() {
        self.captureSession.beginConfiguration()

        if let input = self.audioDeviceInput {
            self.captureSession.removeInput(input)
        }

        if self.captureSession.canAddOutput(self.photoOutput) {
            self.captureSession.addOutput(self.photoOutput)
        }

        self.captureSession.removeOutput(self.movieFileOutput)
        
        self.captureSession.commitConfiguration()
    }
    
    
    /**
     @brief Change session for capturing video.
     */
    private func chageVideoMode() {
        self.captureSession.beginConfiguration()
        
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let input = try AVCaptureDeviceInput(device: audioDevice)

                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.audioDeviceInput = input
                }
            } catch {
                print("Error input audio device to capture session : \(error)")
            }
        }
        
        if self.captureSession.canAddOutput(self.movieFileOutput) {
            self.captureSession.addOutput(self.movieFileOutput)
        }

        self.captureSession.removeOutput(self.photoOutput)
        
        self.captureSession.commitConfiguration()
    }
    
    
    /**
     @brief Take photo or recording or finish recording video.
     */
    @IBAction func shutterButtonTUP(_ sender: Any) {
        switch self.shootingMode {
        case.photo:
            self.settingsForMonitoring = AVCapturePhotoSettings()
            self.settingsForMonitoring.embeddedThumbnailPhotoFormat = [AVVideoCodecKey : AVVideoCodecType.jpeg]
            self.settingsForMonitoring.isHighResolutionPhotoEnabled = false
            self.photoOutput.capturePhoto(with: self.settingsForMonitoring, delegate: self)
            
        case .video:
            switch self.captureState {
            case .wait:
                AudioServicesPlaySystemSound(1117)
                
                let fileURL: URL = self.makeUniqueTempFileURL(extension: "mov")
                
                self.movieFileOutput.startRecording(to: fileURL, recordingDelegate: self)
                self.captureState = .capturing
                
                self.changeModeSegmentControl.isEnabled = false
                
            case .capturing:
                AudioServicesPlaySystemSound(1118)
                
                self.movieFileOutput.stopRecording()
                self.captureState = .wait
                
                self.shutterButton.isEnabled = false
            }
        }
    }
    
    
    /**
     @brief Change shooting mode.
     */
    @IBAction func changeShootingMode(_ sender: UISegmentedControl) {
        guard let mode = ShootingMode(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        
        self.shootingMode = mode
        
        switch self.shootingMode {
        case .photo:
            self.chagePhotoMode()
            
        case .video:
            self.chageVideoMode()

        @unknown default:
            print("Insufficient case definitione.")
        }
    }
    
    
    /**
     @brief Create unique url string.
     - parameter type : extension type
     */
    private func makeUniqueTempFileURL(extension type: String) -> URL {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let uniqueFilename = ProcessInfo.processInfo.globallyUniqueString
        let urlNoExt = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
        let url = urlNoExt.appendingPathExtension(type)
        return url
    }
    
}


extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard error == nil else {
            print("Error broken photo data: \(error!)")
            return
        }
        
        guard let photoData = photo.fileDataRepresentation() else {
            print("No photo data to write.")
            return
        }
        
        self.compressedData = photoData

    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        
        guard error == nil else {
            self.shutterButton.isEnabled = true
            print("Error capture photo: \(error!)")
            return
        }
        
        guard let compressedData = self.compressedData else {
            self.shutterButton.isEnabled = true
            print("The expected photo data isn't available.")
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: compressedData, options: nil)

                
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self.shutterButton.isEnabled = true
                }
                
                if let _ = error {
                    print("Error save photo: \(error!)")
                }
            }
        }
    }
    
}


extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { _, error in
            DispatchQueue.main.async {
                self.shutterButton.isEnabled = true
                self.changeModeSegmentControl.isEnabled = true
            }

            if let error = error {
                print(error)
            }
            
            cleanup()
        }
        
        // Clean file path.
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Error clean up: \(error)")
                }
            }
        }
    }
    
}
