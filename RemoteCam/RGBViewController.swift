//
//  ViewController.swift
//  RemoteCam
//
//  Created by jino on 2021/01/12.
//

import UIKit
import AVFoundation
import Network

class RGBViewController: UIViewController {

    @IBOutlet weak var colorImageView: UIImageView!
    @IBOutlet weak var ISOTextViewer: UITextField!
    @IBOutlet weak var ISOSlider: UISlider!
    @IBOutlet weak var exposureSlider: UISlider!
    @IBOutlet weak var exposureTextViewer: UITextField!
    
    @IBOutlet weak var RGainTextViewer: UITextField!
    @IBOutlet weak var GGainTextViewer: UITextField!
    @IBOutlet weak var BGainTextViewer: UITextField!
    
    @IBOutlet weak var RGainSlider: UISlider!
    @IBOutlet weak var GGainSlider: UISlider!
    @IBOutlet weak var BGainSlider: UISlider!
    
    @IBOutlet weak var rgbdModeButton: UIButton!
    
    
    private var ISO = 120
    private var exposureTime = 120
    
    private var rGain = Float(1.0)
    private var gGain = Float(1.0)
    private var bGain = Float(1.0)
    
    private var session : AVCaptureSession!
    private var captureOutput : AVCaptureVideoDataOutput!
    private var captureDevice : AVCaptureDevice!
    
    private var listener : NWListener!
    private var nwConnection: NWConnection!
    private var connectionQueue : DispatchQueue!
    private var networkQueue : DispatchQueue!
        
    private var colorImage : UIImage!
    
    // It'll works like EOF
    let tailData = "__TAIL_TAIL_TAIL__".data(using: .utf8)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rgbdModeButton.setRGBModeButtonUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        session = AVCaptureSession()
        captureOutput = AVCaptureVideoDataOutput()

        listener = try! NWListener(using: .tcp, on:12345)
        connectionQueue = DispatchQueue(label: "connectionQueue")
        networkQueue = DispatchQueue(label: "networkQueue")
                    
    
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
                    else{
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
        
        self.captureDevice = discoverySession.devices.first
        
        // Set resolution
        self.session.sessionPreset = .vga640x480
        // Set expossure time, ISO, white balance, focus mode

        adjustCamera()
    
        
        self.captureDevice?.unlockForConfiguration()
        
        ISOSlider.minimumValue = (captureDevice?.activeFormat.minISO)!
        ISOSlider.maximumValue = 300
        ISOSlider.setValue(Float(self.ISO), animated: true)
        ISOTextViewer.text = String(self.ISO)
        
        exposureSlider.minimumValue = Float(CMTimeGetSeconds((captureDevice?.activeFormat.maxExposureDuration)!))
        exposureSlider.maximumValue = 1000
        exposureSlider.setValue(Float(self.exposureTime), animated: true)
        exposureTextViewer.text = "1 / "+String(self.exposureTime)
        
        
        RGainSlider.minimumValue = 1.0;
        RGainSlider.maximumValue = self.captureDevice.maxWhiteBalanceGain
        RGainSlider.setValue(self.captureDevice.deviceWhiteBalanceGains.redGain, animated: true)
        self.rGain = self.captureDevice.deviceWhiteBalanceGains.redGain
        RGainTextViewer.text = String(self.captureDevice.deviceWhiteBalanceGains.redGain)
        
        GGainSlider.minimumValue = 1.0;
        GGainSlider.maximumValue = self.captureDevice.maxWhiteBalanceGain
        GGainSlider.setValue(self.captureDevice.deviceWhiteBalanceGains.greenGain, animated: true)
        self.gGain = self.captureDevice.deviceWhiteBalanceGains.greenGain
        GGainTextViewer.text = String(self.captureDevice.deviceWhiteBalanceGains.greenGain)
        
        BGainSlider.minimumValue = 1.0;
        BGainSlider.maximumValue = self.captureDevice.maxWhiteBalanceGain
        BGainSlider.setValue(self.captureDevice.deviceWhiteBalanceGains.blueGain, animated: true)
        self.bGain = self.captureDevice.deviceWhiteBalanceGains.blueGain
        BGainTextViewer.text = String(self.captureDevice.deviceWhiteBalanceGains.blueGain)
        
        adjustCamera()
        
        let captureInput = try! AVCaptureDeviceInput(device: captureDevice!)
        self.session.addInput(captureInput)
        
        let bounds = self.view.bounds
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: bounds.height))
        previewLayer.videoGravity = .resize
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight;
        
        colorImageView.layer.addSublayer(previewLayer)
    
        print(self.captureDevice.maxWhiteBalanceGain)
        print(self.captureDevice.deviceWhiteBalanceGains)
    
        
        self.captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AVCaptureOutputQueue", attributes: []))
        self.session.addOutput(self.captureOutput)
        
        self.session.commitConfiguration()
        self.session.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.session.stopRunning()
        listener.cancel()
    }
    
    
    @IBAction func ISOSliderChanged(_ sender: UISlider) {
        self.ISO = Int(sender.value)
        ISOTextViewer.text = String(self.ISO)
        adjustCamera()
    }
    
    @IBAction func exposureSliderChanged(_ sender: UISlider) {
        self.exposureTime = Int(sender.value)
        exposureTextViewer.text = "1 / "+String(self.exposureTime)
        adjustCamera()
    }

    @IBAction func RGainSliderChanged(_ sender: UISlider) {
        self.rGain = Float(sender.value)
        RGainTextViewer.text = String(rGain)
        adjustCamera()
    }
    
    @IBAction func GGainSliderChanged(_ sender: UISlider) {
        self.gGain = Float(sender.value)
        GGainTextViewer.text = String(gGain)
        adjustCamera()
    }
    
    @IBAction func BGainSliderChanged(_ sender: UISlider) {
        self.bGain = Float(sender.value)
        BGainTextViewer.text = String(bGain)
        adjustCamera()
    }
    
    func adjustCamera(){
        do {
            // captureDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported
            // returns false
            try self.captureDevice!.lockForConfiguration()
            self.captureDevice!.setExposureModeCustom(duration: CMTimeMake(value: 1,timescale: Int32(self.exposureTime)), iso: Float(self.ISO), completionHandler: nil)
            self.captureDevice?.setWhiteBalanceModeLocked(with: AVCaptureDevice.WhiteBalanceGains(redGain: self.rGain, greenGain: self.gGain, blueGain: self.bGain), completionHandler: nil)
            self.captureDevice!.unlockForConfiguration()
        } catch {
            debugPrint(error)
        }
    }
    
    @IBAction func ToRGBDBtnClick(_ sender: Any) {
        let nextVC = storyboard?.instantiateViewController(withIdentifier: "RGBDViewController")
        let sceneDelegate = UIApplication.shared.connectedScenes
               .first!.delegate as! SceneDelegate
        sceneDelegate.window?.rootViewController = nextVC
    }
    
}

extension RGBViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        self.colorImage = UIImage(ciImage: CIImage(cvPixelBuffer: imageBuffer)).resize(to: CGSize(width: 640, height: 480))
    }
}
