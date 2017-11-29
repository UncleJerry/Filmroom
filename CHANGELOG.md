20171129

- Add some comments and fix the threadgroup config for 1st stage

20171124

- Add first two step of FFT algorithm

20170910

- Add workable Gaussian Blur filter
- Fix Unstable when process high solution pictures

20170826

- Add macOS project, which requires 10.13 and Swift 4.0.
	- Use Metal kernel instead of CoreImage Kernel for saving compiling time.
	- MTKView is implemented to realtime render.

20170725

- Enhance Performance
- Add clamping for each kernel
	- Fix the out range problem
	- Partly fix the color management bug for AdobeRGB Image
