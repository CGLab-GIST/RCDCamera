# RCDCamera : Remote Color Depth Camera
Simple iOS remote camera app to send color and depth images that can be received by the socket, without any 3rd-party dependencies. It is implemented to replace [Intel RealSense](https://github.com/IntelRealSense/librealsense) for my personal usage. 

### Dependencies and requirements
- [ARKit 4](https://developer.apple.com/documentation/arkit/), [AVFoundation](https://developer.apple.com/documentation/avfoundation), [Network](https://developer.apple.com/documentation/network)
- **LiDAR-embedded iOS device**

### Feature

2 mode is available, `RGBD` and `RGB`.

- `RGBD` : Able to send color and depth image to socket
- `RGB` : Able to send color image **only** to socket with manually set camera(Exposure, ISO). **Note that ARKit 4 doesn't support setting camera ISO and exposure manually.**

### Usage

You have to know device's ip address. `RCDCamera` uses port `12345` by default.

- RGB image : Send UTF-8 encoded `"rgb"` string to the address, PNG image itself will be returned.
- Depth image(in RGBD mode only) : Send UTF-8 encoded `"depth"` string to the address, **binary of the depth ARRAY** will be returned. You have to convert it to an image in some way.

In both case, UTF-8 encoded `__TAIL_TAIL_TAIL__` is added to the end of the data. It can be used to separate images/data from received binary.

Please refer `client_example.py` for example. It receives color or depth image from the connected socket.

 1. Check IP address of your device and run application.
 2. Set IP address as device's in `client_example.py` and run script. It may requires few dependencies.



### Screenshots

#### `RGB mode`
![IMG_8891](https://user-images.githubusercontent.com/11532321/123085692-81d1f600-d45d-11eb-8cd1-4ab50e3d9d33.PNG)


#### `RGBD mode`
![output-onlinepngtools](https://user-images.githubusercontent.com/11532321/123085879-b80f7580-d45d-11eb-8692-e40ca1090ec0.png)


