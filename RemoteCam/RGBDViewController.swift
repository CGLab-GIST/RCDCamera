/* BSD 3-Clause License

Copyright (c) 2022, GIST CGLAB
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//
//  ViewController.swift
//  RemoteCam
//
//  Created by Jino Park on 2021/01/12.
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
    @IBOutlet weak var IPAddrView: UITextView!
    
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
                
        IPAddrView.text = getIPAddress()+":12345"
        
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

// https://stackoverflow.com/a/56342010
func getIPAddress() -> String {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { return "" }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // wifi = ["en0"]
                // wired = ["en2", "en3", "en4"]
                // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]

                let name: String = String(cString: (interface.ifa_name))
                if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return address ?? ""
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

