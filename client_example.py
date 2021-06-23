import socket
import time

import numpy as np
import imageio

# iPad device's IP address
HOST = '192.168.0.9'
# Default port is 12345
# https://github.com/pjessesco/RemoteCamera/blob/b65894e1ce73c8052b43922e02fa84aa0d5b1a5f/RemoteCam/ViewController.swift#L20
PORT = 12345
ADDR = (HOST, PORT)
# Specified in
# https://github.com/pjessesco/RemoteCamera/blob/b65894e1ce73c8052b43922e02fa84aa0d5b1a5f/RemoteCam/ViewController.swift#L30
TAIL_UTF8 = "__TAIL_TAIL_TAIL__".encode('utf-8')


# Request signal to the RCDCamera application and return received data
def request(clientSocket, signal):
    print("send signal : ", signal)
    clientSocket.send(signal.encode())
    print("receiving..")

    data = clientSocket.recv(50000)

    while TAIL_UTF8 not in data:
        print("partially received...")
        data += clientSocket.recv(50000)

    print("whole data received : ", len(data))

    # if not sleep app may crashes
    time.sleep(1)

    return data

# PNG formatted image itself is returned from the RCDCamera.
def get_rgb_image(clientSocket, filename):
    img_data = request(clientSocket, 'rgb')
    img_data = img_data[:-len(TAIL_UTF8)]
    path = filename + '.png'

    f = open(path, 'wb')
    f.write(img_data)
    f.close()

# Depth array binary is returned from the RCDCamera.
# You have to convert it to exr or other image format manually.
def get_depth_image(clientSocket, filename):
    path = filename + '.exr'
    img_data = request(clientSocket, 'depth')

    array = np.frombuffer(img_data[:-len(TAIL_UTF8)], dtype=np.float32)

    # LiDAR scene depth resolution is 256*192 in iPad 12.9 4th-gen.
    array = np.reshape(array, (192, 256))
    print(array.shape)

    imageio.imwrite(path, array)


if __name__ == '__main__':

    # Download exr plugin for imageio
    # https://imageio.readthedocs.io/en/stable/format_exr-fi.html?highlight=exr#exr-fi-ilm-openexr
    imageio.plugins.freeimage.download()

    print("Connecting...")
    clientSocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    clientSocket.connect(ADDR)
    print("Done")

    # Verify connection via dummy call. It'll return 'DUMMY DATA'.
    # https://github.com/pjessesco/RemoteCamera/blob/b65894e1ce73c8052b43922e02fa84aa0d5b1a5f/RemoteCam/ViewController.swift#L81
    print("Dummy calls")
    request(clientSocket, 'dummy')
    request(clientSocket, 'dummy')
    print("Dummy call ends")


    get_rgb_image(clientSocket, str(1))
    # It'll get error in RGB mode.
    get_depth_image(clientSocket, str(1))

    print("Close socket")
    clientSocket.close()