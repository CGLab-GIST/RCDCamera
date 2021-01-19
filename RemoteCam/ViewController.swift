//
//  ViewController.swift
//  RemoteCam
//
//  Created by jino on 2021/01/12.
//

import UIKit
import AVFoundation
import Network

class ViewController: UIViewController {

    @IBOutlet weak var colorImageView: UIImageView!
    
    private let session = AVCaptureSession()
    private let captureOutput = AVCaptureVideoDataOutput()
    
    private var listener = try! NWListener(using: .tcp, on:12345)
    private var nwConnection: NWConnection!
    private var connectionQueue = DispatchQueue(label: "connectionQueue")
    private var networkQueue = DispatchQueue(label: "networkQueue")
        
    private var colorImage : UIImage!
    
    // It'll works like EOF
    let tailData = "__TAIL_TAIL_TAIL__".data(using: .utf8)
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        listener.newConnectionHandler = {
            connection in
            self.nwConnection = connection
            
            print("Connected!:", self.nwConnection.endpoint)
            
            self.nwConnection.start(queue: self.connectionQueue)
            print("connection started")
            
            func readData(){
                self.nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 1024){
                    data, context, isComplete, error in
                    guard error == nil, let data = data else {
                        print("close connection")
                        return self.nwConnection.cancel()
                    }
                    let receivedString = String(decoding: data, as: UTF8.self)
                    print("Received:", receivedString)
                    
                    var imgData : Data?
                    if(receivedString == "rgb"){
                        print(self.colorImage.size)
                        // FIXME : resolution increases in client
                        imgData = self.colorImage.pngData()
                        
                    }
                    else if(receivedString == "dummy"){
                        imgData = "DUMMY DATA".data(using: .utf8)
                    }
                    
                    var sendData = Data()
                    sendData.append(imgData!)
                    sendData.append(self.tailData!)
                    
                    print(sendData)
                    self.nwConnection.send(content : sendData, completion : .idempotent)
                }
            }
            while(true){
                readData()
                usleep(1000000) // 1sec, some delay is needed
                if(self.nwConnection.state == NWConnection.State.cancelled){
                    return;
                }
            }
        }
        
        listener.start(queue: DispatchQueue(label: "NWListener queue"))
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
            [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back)
        
        let captureDevice = discoverySession.devices.first
        
        // Set resolution
        session.sessionPreset = .vga640x480
        // Set expossure time, ISO, white balance, focus mode
        do {
            try captureDevice!.lockForConfiguration()
            captureDevice!.setExposureModeCustom(duration: CMTimeMake(value: 1,timescale: 80), iso: 120, completionHandler: nil)
            captureDevice?.setWhiteBalanceModeLocked(with: AVCaptureDevice.WhiteBalanceGains(), completionHandler: nil)
            captureDevice?.focusMode = .continuousAutoFocus
            captureDevice!.unlockForConfiguration()
        } catch {
            debugPrint(error)
        }

        captureDevice?.unlockForConfiguration()
        
        let captureInput = try! AVCaptureDeviceInput(device: captureDevice!)
        session.addInput(captureInput)
        
        let bounds = self.view.bounds
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: bounds.height))
        previewLayer.videoGravity = .resize
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        
        colorImageView.layer.addSublayer(previewLayer)
        
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AVCaptureOutputQueue", attributes: []))
        session.addOutput(captureOutput)
        
        session.commitConfiguration()
        session.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        self.colorImage = UIImage(ciImage: CIImage(cvPixelBuffer: imageBuffer)).resize(to: CGSize(width: 640, height: 480))
    }
}

// https://stackoverflow.com/a/55906075
extension UIImage {

    /// Resize image from given size.
    ///
    /// - Parameter newSize: Size of the image output.
    /// - Parameter resizeFramework: Technique for image resizing: UIKit / CoreImage / CoreGraphics / ImageIO / Accelerate.
    /// - Returns: Resized image.
    public func resize(to newSize: CGSize) -> UIImage? {
        return resizeWithUIKit(to: newSize)
    }

    // MARK: - UIKit

    /// Resize image from given size.
    ///
    /// - Parameter newSize: Size of the image output.
    /// - Returns: Resized image.
    private func resizeWithUIKit(to newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
