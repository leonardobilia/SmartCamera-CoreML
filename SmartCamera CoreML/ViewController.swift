//
//  ViewController.swift
//  SmartCamera CoreML
//
//  Created by Leonardo Bilia on 1/19/19.
//  Copyright © 2019 Leonardo Bilia. All rights reserved.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController {
    
    private lazy var objectsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var confidenceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutHandler()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.configureVideoOrientation()
    }
    
    //MARK: - Functions
    fileprivate func setupCaptureSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        guard let cameraLayer = previewLayer else { return }
        view.layer.addSublayer(cameraLayer)
        cameraLayer.videoGravity = .resizeAspectFill
    }
    
    fileprivate func configureVideoOrientation() {
        if let previewLayer = previewLayer, let connection = previewLayer.connection {
            let orientation = UIDevice.current.orientation
            
            if connection.isVideoOrientationSupported, let videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue) {
                previewLayer.frame = view.bounds
                previewLayer.connection?.videoOrientation = videoOrientation
            }
        }
    }
    
    fileprivate func layoutHandler() {
        view.addSubview(confidenceLabel)
        confidenceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        confidenceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        confidenceLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16).isActive = true
        
        view.addSubview(objectsLabel)
        objectsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        objectsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        objectsLabel.bottomAnchor.constraint(equalTo: confidenceLabel.topAnchor, constant: -8).isActive = true
    }
}


// MARK: - AVCapture Video Data Output Sample Buffer Delegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { (finishRequest, error) in
            if error != nil {
                print(error?.localizedDescription ?? "unexpected error")
            } else {
                
                guard let results = finishRequest.results as? [VNClassificationObservation] else { return }
                guard let firstObservation = results.first else { return }
                
                DispatchQueue.main.async {
                    self.view.bringSubviewToFront(self.confidenceLabel)
                    self.view.bringSubviewToFront(self.objectsLabel)
                    
                    self.objectsLabel.text = firstObservation.identifier
                    self.confidenceLabel.text = String(firstObservation.confidence)
                }
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}

