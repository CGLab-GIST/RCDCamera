# RemoteCamera
Simple iOS remote camera app to send color and depth images that can be received by the socket, without any 3rd-party dependencies, using [ARKit 4](https://developer.apple.com/documentation/arkit/) and [Network](https://developer.apple.com/documentation/network) frameworks. It is implemented to replace [Intel RealSense](https://github.com/IntelRealSense/librealsense) for my personal usage. 

**This app requires LiDAR-embedded ios devices.**

Use `main` branch for getting depth image with ARKit 4 or `without_depth` branch for adjusting exposure and ISO only if you need color image only (Note that ARKit 4 doesn't support setting camera exposure manually).

Please refer `client_example.py` for usage.

 1. Check IP address of your device in Setting and run application.
 2. Set IP address as device's in `client_example.py` and run script. It may requires few dependencies.


#### `main` : Getting depth image from LiDAR
![IMG_0006](https://user-images.githubusercontent.com/11532321/104289202-34d81400-54fc-11eb-96f8-5a6e6a03acf2.PNG)


#### `without_depth` : Setting ISO and exposure time manually

![output-onlinepngtools](https://user-images.githubusercontent.com/11532321/104986736-0e176180-5a57-11eb-8f01-eb4db918045f.png)
