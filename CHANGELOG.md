20180312

- Optimize the memory.
- Adapt Argument buffer for some kernel functions.

20180310

- Finish the 2D FFT on Metal algorithm, and it works nice.
- Upgrade the iOS part to Swift 4 and bring the computation kernel to it.
- Simplify the code.

20180228

- Add two compute kernel
	- illumination map in mean way
	- shrinkage

20180218

- Correct the data type of MTLTexture. (From rg8Unorm to rg32Float)

20180215

- Add Complex number to modulus function

20180209

- Finish the commandBuffer and commandEncoder configuration.

20180204

- Complete the FFT Metal Shader which suits all stage calculation, pipeline queue and command buffer config are under preparing 

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
