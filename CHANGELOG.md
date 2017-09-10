20170910

- Add workable Gaussian Blur filter

20170826

- Add macOS project, which requires 10.13 and Swift 4.0.
	- Use Metal kernel instead of CoreImage Kernel for saving compiling time.
	- MTKView is implemented to realtime render.

20170725

- Enhance Performance
- Add clamping for each kernel
	- Fix the out range problem
	- Partly fix the color management bug for AdobeRGB Image