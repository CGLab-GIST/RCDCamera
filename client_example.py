import socket
import time

import numpy as np
import pyexr

# iPad device's IP address
HOST = '192.168.0.9'
# Default port is 12345
# https://github.com/pjessesco/RemoteCamera/blob/b65894e1ce73c8052b43922e02fa84aa0d5b1a5f/RemoteCam/ViewController.swift#L20
PORT = 12345
ADDR = (HOST,PORT)
# Specified in 
# https://github.com/pjessesco/RemoteCamera/blob/b65894e1ce73c8052b43922e02fa84aa0d5b1a5f/RemoteCam/ViewController.swift#L30
TAIL_UTF8 = "__TAIL_TAIL_TAIL__".encode('utf-8')

def request(clientSocket, signal):
    print("send signal : ",signal)
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

def get_rgb_image(clientSocket, filename):
    img_data = request(clientSocket, 'rgb')
    path = filename + '.png'
    
    f = open(path, 'wb')
    f.write(img_data)
    f.close()

def get_depth_png_image(clientSocket, filename):
    img_data = request(clientSocket, 'depth')
    path = filename + '.png'
    
    f = open(path, 'wb')
    f.write(img_data)
    f.close()

def get_depth_image(clientSocket, filename):
    path = filename + '.exr'
    img_data = request(clientSocket, 'depth')

    array = np.frombuffer(img_data[:-len(TAIL_UTF8)], dtype=np.float32)
    # LiDAR scene depth resolution is 256*192 in iPad 12.9 4th-gen.
    array = np.reshape(array, (192,256))
    
    pyexr.write(path, array)

if __name__ == '__main__':

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

    for i in range(1, 3):
        get_rgb_image(clientSocket, str(i))
        get_depth_image(clientSocket, str(i))
        get_depth_png_image(clientSocket, str(i))

    print("Close socket")
    clientSocket.close()
