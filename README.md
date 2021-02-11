# RCDCamera : Remote Color Depth Camera
Simple iOS remote camera app to send color and depth images that can be received by the socket, without any 3rd-party dependencies. It is implemented to replace [Intel RealSense](https://github.com/IntelRealSense/librealsense) for my personal usage. This repository contains 2 branches, `main` and `without_depth`.

### Dependencies and requirements
- `main` : [ARKit 4](https://developer.apple.com/documentation/arkit/), [Network](https://developer.apple.com/documentation/network), **LiDAR-embedded iOS device**
- `without_depth` : [AVFoundation](https://developer.apple.com/documentation/avfoundation), [Network](https://developer.apple.com/documentation/network)

### Feature
- `main` : Send color and depth image to socket
- `without_depth` Send color image **only** to socket with manually set camera(Exposure, ISO). **Note that ARKit 4 doesn't support setting camera ISO and exposure manually.**

### Usage

You have to know device's ip address. `RCDCamera` uses port `12345` by default.

- RGB : Send UTF-8 encoded `rgb` string to the address, PNG image itself will be returned.
- Depth(`main` branch only) : Send UTF-8 encoded `depth` string to the address, binary of the depth **ARRAY** will be returned. You have to convert it to an image in some way.

In both case, UTF-8 encoded `__TAIL_TAIL_TAIL__` is added to the end of the data. It can be used to separate images/data from received binary.

Please refer `client_example.py` for example. It receives color or depth image from the connected socket.

 1. Check IP address of your device and run application.
 2. Set IP address as device's in `client_example.py` and run script. It may requires few dependencies.



### Screenshots

#### `main`
![IMG_0006](https://user-images.githubusercontent.com/11532321/104289202-34d81400-54fc-11eb-96f8-5a6e6a03acf2.PNG)


#### `without_depth`

![output-onlinepngtools](https://user-images.githubusercontent.com/11532321/104986736-0e176180-5a57-11eb-8f01-eb4db918045f.png)
