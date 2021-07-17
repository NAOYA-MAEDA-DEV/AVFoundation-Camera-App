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
    
    private let captureSession = AVCaptureSession()
    private var captureVideoLayer: AVCaptureVideoPreviewLayer!
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private var currentDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var settingsForMonitoring =  AVCapturePhotoSettings()
    
    private let sessionQueue = DispatchQueue(label: "session_queue")
    
    private var setupResult: SessionSetupResult = .success // Session Setup Result
    enum SessionSetupResult {
        case success // Success
        case notAuthorized // No permisson to Camera device or Photo album
        case configurationFailed // Failed
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
    
    
    func checkPermission() {
        // Camera
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
        
        // Photo album
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
    
    
    func configureSession() {
        guard setupResult == .success else { return }
        self.captureSession.beginConfiguration()
        // 入力ソースの生成
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
            
            currentDevice = videoDevice
            // 入力ソースをキャプチャセッションにセット
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
                self.videoDeviceInput = input
                // 出力タイプをキャプチャセッションにセット
                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                    // カメラのプレビュー映像を表示するViewの指定
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
            self.setupResult = .configurationFailed
            self.captureSession.commitConfiguration()
            return
        }
        captureSession.commitConfiguration()
    }
    
    
    /**
     @brief Capture photo
     */
    @IBAction func shutterButtonTUP(_ sender: Any) {
        self.settingsForMonitoring = AVCapturePhotoSettings()
        self.settingsForMonitoring.embeddedThumbnailPhotoFormat = [AVVideoCodecKey : AVVideoCodecType.jpeg]
        self.settingsForMonitoring.isHighResolutionPhotoEnabled = false
        self.photoOutput.capturePhoto(with: self.settingsForMonitoring, delegate: self)
    }
    
    
    /**
     @brief ChangeShooting mode
     */
    @IBAction func changeShootingMode(_ sender: Any) {
        
        
    }
    
    

}


extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        // Access the file data representation of this photo.
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
            print("Error capturing photo: \(error!)")
            return
        }
        
        // Ensure the RAW and processed photo data exists.
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
            }
        }
    }
    
}
