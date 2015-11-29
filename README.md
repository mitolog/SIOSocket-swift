# SIOSocket-swift
A swift version of SIOSocket just for my training of JavascriptCore with swift.

The sample is minimal chat app where UI is really pity.

## How to use

### nodejs

1. go to nodeapp directory
2. type `npm install socket.io` on terminal
3. type `node app` on terminal

### ios

1. Preapare 2 ios devices.
2. Set userName and hostUrl at ViewController.swift.
3. Build and install app to each devices where each app has different userName to distinguish each other.

*) A part of hostUrl is local IP of http server where socket.io app.js running.

## Todo

 - Write test (check if all argument has passed when emitting)
 - Use JSExport hopefully...
 - 

## License
MIT
