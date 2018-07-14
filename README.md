# Filmroom, an image process playground

> 
> Swift 4 + iOS 11 or macOS 10.13
> 
> Mainly working on iOS




## iOS Part include

- [x] Exposure,
- [x] Shadow & highlight
- [x] Saturation
- [x] Contrast
- [x] HSL for Orange
- [x] Computational Kernels

## Rendering Features

- Real-Time Rendering via MTKView
	- Adapted aspect radio
	- Lowest CPU cost with fewest data type conversion
	- This way is much more faster than DispatchQueue method.
- Argument Buffer of Metal, which decrease around 10 times of CPU overheads. (macOS only)

## macOS Features

- [x] Gamma Correction
- [x] Gaussian Blur
- [x] Transforms between NSImage, CIImage and CGImage.

## Computation Kernels

- [x] 2D FFT in Apple Metal by a Iterative Way
	- [x] 1st: Rearrangement of element
	- [x] 2nd: Calculate FFT from beginning to final stage. 
	- [x] 3rd: Complex to modulus.
- [x] Illumination Map in mean way
- [x] Shrinkage
- [x] Gradient
- [x] Low Light Enhancement Algorithm - LIME

## Kernel codes

All Kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel for Core Image Kernel with comments under the iOS directory. 

The filter written in Metel is located in [here](/macOS/Filmroom%20for%20Mac/Filters/Kernels.metal).

Computational Kernel can be found both in [macOS project](/macOS/Filmroom%20for%20Mac/Filters/ComputeKernel.metal) and [iOS project](iOS/Filmroom/Filters/ComputeKernel.metal). These two kernels are not identical, please focus on macOS one.

## Test

Thanks to Core Image, you can test these filters by images supported by it. Output is available.

## FFT Result

Case 1:

![Input 512*512](/TestingCase/1_512.jpg)

![Output](/TestingCase/1_output.jpg)

Case 2:
![Input 4096*4096](/TestingCase/2_4096.jpg)

![Output](/TestingCase/2_output.jpg)

## Low-Light Image Enhancement

### Reference

Guo, X., Li, Y., & Ling, H. (2017). LIME: Low-Light Image Enhancement via Illumination Map Estimation. IEEE TRANSACTIONS ON IMAGE PROCESSING, 26(2), 982–993.

### Result

Case 1:

![Low-Light 1](/TestingCase/LIME1_2048.jpg)

![Output 1](/TestingCase/LIME1_output.JPG)
