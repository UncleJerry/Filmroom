# Filmroom, an image process playground

> 
> Swift 4 + iOS 11 or macOS 10.13
> 
> Mainly working on iOS


## iOS Part include

- [x] Image adjustment
	- [x] Exposure
	- [x] Shadow & highlight
	- [x] Saturation
	- [x] Contrast
	- [x] HSL for Orange
- [x] Real-Time Rendering via MTKView
- [x] ★★★ The implementation of Low Light Enhancement Algorithm - LIME ★★★ 

## macOS parts included

- [x] Gamma Correction
- [x] Gaussian Blur
- [x] Transforms between NSImage, CIImage and CGImage.
- [x] Real-Time Rendering via MTKView

### Rendering Features

- Real-Time Rendering via MTKView
	- Adapted aspect radio
	- Lower CPU cost because fewer data type conversion
		- This way is much more faster than DispatchQueue method.
	- It decreases the CPU usage because of taking use of argument Buffer of Metal . (macOS only)

## Computation Kernels

These algorithms are written in computation kernels (of Metal API):

- [x] 2D FFT in Apple Metal by a Iterative Way
	- [x] 1st: Rearrangement of element ([shader is here](https://github.com/UncleJerry/Filmroom/blob/master/iOS/Filmroom/Filters/ComputeKernel.metal#L21-L57))
	- [x] 2nd: Calculate FFT from beginning to final stage. ([shader of early stage](https://github.com/UncleJerry/Filmroom/blob/master/iOS/Filmroom/Filters/ComputeKernel.metal#L93), [shader of full stage](https://github.com/UncleJerry/Filmroom/blob/master/iOS/Filmroom/Filters/ComputeKernel.metal#L132))
	- [x] 3rd: Complex to modulus.
- [x] Illumination Map in mean way
- [x] Shrinkage
- [x] Gradient
- [x] Low Light Enhancement Algorithm - LIME

Computational Kernel can be found both in [macOS project](/macOS/Filmroom%20for%20Mac/Filters/ComputeKernel.metal) and [iOS project](iOS/Filmroom/Filters/ComputeKernel.metal). These two kernels are not identical, please focus on iOS one.

## Core Image kernels

Core Image kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel for Core Image Kernel with comments under the iOS directory. 

## Test

You can test these filters by images supported by Core Image. Output is available.

Note: FFT algorithm only support image size like 1024x1024 or 4096x4096.

## FFT Result

Case 1:

![FFTcase1](/TestingCase/FFTcase1.jpg)

Case 2:
![FFTcase2](/TestingCase/FFTcase2.jpg)

## Low-Light Image Enhancement (LIME)

### Reference of LIME

Guo, X., Li, Y., & Ling, H. (2017). LIME: Low-Light Image Enhancement via Illumination Map Estimation. IEEE TRANSACTIONS ON IMAGE PROCESSING, 26(2), 982–993.

### Result


![LIMEcase1](/TestingCase/LIMEcase1.jpg)

![LIMEcase2](/TestingCase/LIMEcase2.jpg)
