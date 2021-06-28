# RCDCamera : Remote Color Depth Camera
Simple iOS remote camera app to send color and depth images that can be received by the socket, without any 3rd-party dependencies. It is implemented to replace [Intel RealSense](https://github.com/IntelRealSense/librealsense) for my personal usage. 

### Dependencies and requirements
- [ARKit 4](https://developer.apple.com/documentation/arkit/), [AVFoundation](https://developer.apple.com/documentation/avfoundation), [Network](https://developer.apple.com/documentation/network)
- **LiDAR-embedded iOS device** (Considering only 12.9 iPad currently)

### Features

2 mode is available, `RGBD` and `RGB`. You can switch to each other in runtime.

- `RGBD`
    - Send color and depth image to socket. 
    - Intrinsic matrix viewer
    - Current fov viewer
    - Current color templerature viewer

- `RGB`
    - Send color image **only** to socket.
    - Manual ISO and exposure controller
    - Manual color gain controller

### Usage

Device's IP address is required to get images. `RCDCamera` uses port `12345` by default.

- RGB image : Send UTF-8 encoded `"rgb"` string to the address, PNG image itself will be returned.
- Depth image(in RGBD mode only) : Send UTF-8 encoded `"depth"` string to the address, **binary of the depth ARRAY** will be returned. You have to convert it to an image in some way.

Note that UTF-8 encoded `__TAIL_TAIL_TAIL__` is added to the end of the data in both mode. It can be used to separate images/data from received binary.

Please refer `client_example.py` for example. It receives color or depth image from the connected socket.

 1. Check IP address of your device and run application.
 2. Set IP address as device's in `client_example.py` and run script. It may requires few dependencies.



### Screenshots

#### `RGBD mode`
![IMG_8894](https://user-images.githubusercontent.com/11532321/123582627-18fdcb80-d819-11eb-9e0f-64a2ee882db9.PNG)

#### `RGB mode`
![output-onlinepngtools-2](https://user-images.githubusercontent.com/11532321/123582726-4c405a80-d819-11eb-84b1-3fc4a3c04e65.png)






