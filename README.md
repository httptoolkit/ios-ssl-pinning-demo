# ios-ssl-pinning-demo

> _Part of [HTTP Toolkit](https://httptoolkit.com): powerful tools for building, testing & debugging HTTP(S)_

A tiny demo iOS app using SSL pinning to block HTTPS MitM interception.

## Try it out

To test this out, clone this repo and build it yourself in XCode, then install it on your simulator or device.

Pressing each button will send an HTTP request with the corresponding configuration. The buttons are purple initially or while a request is in flight, and then turn green or red (with corresponding icons) when the request succeeds/fails. Error details for failures are available in the console.

On a normal unintercepted device, every button should always immediately go green. On a device whose HTTPS is being intercepted (e.g. by [HTTP Toolkit](https://httptoolkit.com/)) all 'pinning' buttons will go red and fail, unless you've used Frida or similar to successfully disable certificate pinning.

<img width=200 src="https://raw.githubusercontent.com/httptoolkit/ios-ssl-pinning-demo/main/screenshot.png" alt="A screenshot of the app in action" />
