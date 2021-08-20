//
//  ViewController.swift
//  RemoteCam
//
//  Created by jino on 2021/01/12.
//

import UIKit
import ARKit
import Network

class RGBDViewController: UIViewController {

    @IBOutlet weak var colorImageView: UIImageView!
    @IBOutlet weak var depthImageView: UIImageView!
    @IBOutlet weak var intrinsicTitleView: UITextView!
    @IBOutlet weak var intrinsicMatView: UITextView!
    @IBOutlet weak var fovView: UITextView!
    @IBOutlet weak var temperatureView: UITextField!
    @IBOutlet weak var rgbModeButton: UIButton!
    
    @IBOutlet weak var warnTextViewer: UITextView!
    
    private var session : ARSession!
    
    private var listener : NWListener!
    private var nwConnection : NWConnection!
    private var connectionQueue : DispatchQueue!
    private var networkQueue : DispatchQueue!
        
    private var colorImage : UIImage!
    private var depthImage : UIImage!
    private var depthData : CVPixelBuffer!
    
    // Resolution of the output color images. Note that this will affect to intrinsic parameters.
    private let targetColorWidth = 640
    private let targetColorHeight = 480
    
    // It'll works like EOF
    let tailData = "__TAIL_TAIL_TAIL__".data(using: .utf8)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rgbModeButton.setRGBModeButtonUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        UIApplication.shared.isIdleTimerDisabled = true
        
        session = ARSession()

        listener  = try! NWListener(using: .tcp, on:12345)
        connectionQueue = DispatchQueue(label: "connectionQueue")
        networkQueue = DispatchQueue(label: "networkQueue")
        
        session.delegate = self
    
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
                        imgData = self.colorImage.pngData()
                        
                    }
                    else if(receivedString == "depth"){
                        
                        CVPixelBufferLockBaseAddress(self.depthData, CVPixelBufferLockFlags(rawValue: 0))
                    
                        var byteBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self.depthData), to: UnsafeMutablePointer<Float32>.self)
                        var depthArray = [Float32](repeating: -1, count: 256*192)
                        
                        for row in 0...191{
                            for col in 0...255{
                                depthArray[row*256 + col] = byteBuffer.pointee
                                byteBuffer = byteBuffer.successor()
                            }
                        }
                        CVPixelBufferUnlockBaseAddress(self.depthData, CVPixelBufferLockFlags(rawValue: 0))
                    
                        imgData = Data(bytes: &depthArray, count: depthArray.count * MemoryLayout<Float32>.stride)
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
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        configuration.isLightEstimationEnabled = true;
        
        // Check supported video format as below
        // print(ARWorldTrackingConfiguration.supportedVideoFormats)
        // configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats[2]
        
        intrinsicTitleView.text = "Intrinsic with target resolution " + String(targetColorWidth) + ", " + String(targetColorHeight)
        
        if(UIApplication.shared.isIdleTimerDisabled == true){
            warnTextViewer.text = "This app is ignoring device's auto lock setting, device will be kept awake in both RGB / RGBD modes."
        }
        
        
        session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        listener.cancel()
    }
    
    @IBAction func ToRGBBtnClick(_ sender: Any) {
        let nextVC = storyboard?.instantiateViewController(withIdentifier: "RGBViewController")
        let sceneDelegate = UIApplication.shared.connectedScenes
               .first!.delegate as! SceneDelegate
        sceneDelegate.window?.rootViewController = nextVC
    }
}

extension RGBDViewController: ARSessionDelegate{
    
    func session(_ session: ARSession, didUpdate frame: ARFrame){
    
        var intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        
        // Camera intrinsic must be converted as image resolution is changed
        
        // Target resolution ratio must be equal to original resolution ratio
        let ratio1 = Float(resolution.width) / Float(resolution.height)
        let ratio2 = Float(targetColorWidth) / Float(targetColorHeight)
        assert(abs(ratio1 - ratio2) < Float.ulpOfOne)
        
        let multiply = Float(targetColorWidth) / Float(resolution.width)
        
        intrinsics[0][0] *= multiply;
        intrinsics[1][1] *= multiply;
        intrinsics[2][0] *= multiply;
        intrinsics[2][1] *= multiply;
        
        var intrinsicMatStr = ""
        for i in 0..<3 {
            for j in 0..<3{
                let val = String(intrinsics[j,i])
                intrinsicMatStr += val.leftPadding(toLength: 10, withPad: " ")
            }
            intrinsicMatStr += "\n"
        }
        intrinsicMatView.text = intrinsicMatStr
        
        let xFovDegrees = 2 * atan(Float(targetColorWidth)/(2 * intrinsics[0,0])) * 180/Float.pi
        let yFovDegrees = 2 * atan(Float(targetColorHeight)/(2 * intrinsics[1,1])) * 180/Float.pi
        fovView.text = String(xFovDegrees) + "\n" + String(yFovDegrees)
        
        temperatureView.text = frame.lightEstimate?.ambientColorTemperature.description
    
        let colorImage = UIImage(ciImage: CIImage(cvPixelBuffer: frame.capturedImage))
        colorImageView.image = colorImage
        // Original resolution depends on configuration set before
        self.colorImage = colorImage.resize(to: CGSize(width: targetColorWidth, height: targetColorHeight))
        
        // format : kCVPixelFormatType_DepthFloat32
        // width  : 256
        // height : 192
        let depthData = frame.sceneDepth?.depthMap
        if(depthData != nil){
            let depthImage = UIImage(ciImage: CIImage(cvPixelBuffer: depthData!))
            
            depthImageView.image = depthImage
            self.depthImage = depthImage
            self.depthData = depthData
        }
    }
}

