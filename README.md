# Filmroom, an image process playground

> 
> Swift 4 + iOS 11 or macOS 10.13
> 
> Mainly working on desktop
> 
> For the Cocoa experiment, please refer to Photo Factory folder



## iOS Part include

- [x] Exposure,
- [x] Shadow & highlight
- [x] Saturation
- [x] Contrast
- [x] HSL for Orange

iOS 11 adaptation will be done before March.

## Rendering Features

- Real-Time Rendering via MTKView
	- Adapted aspect radio
	- Lowest CPU cost with fewest data type conversion
	- This way is much more faster than DispatchQueue method.
- Argument Buffer of Metal, which decrease around 10 times of CPU overheads. (macOS only)

## macOS Filters Filters

- [x] Gamma Correction
- [x] Gaussian Blur

## Computation Kernels

Please search the file named ComputeKernel.metal 

- [x] 2D FFT in Apple Metal by a Iterative Way
	- [x] 1st: Rearrangement of element
	- [x] 2nd: Calculate FFT from beginning to final stage. 
	- [x] 3rd: Complex to modulus.
- [ ] Composition Relation
- [x] Illumination Map in mean way
- [x] shrinkage

## Test

Thanks to Core Image, you can test these filters by images supported by it. Output is available.

The 2D FFT on Metal API is under testing, there's still a long journey to correct behavior, due to wrong configuration of Metal. But currently it is workable and meet no runtime error.

## Kernel codes

All Kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel for Core Image Kernel with comments under the iOS directory. 

The filter written in Metel is located in [here](/macOS/Filmroom\ for\ Mac/Filters/Kernels.metal).

Computational Kernel can be found in [macOS folder](/macOS/Filmroom\ for\ Mac/Filters/ComputeKernel.metal) and [iOS folder](iOS/Filmroom/Filters/ComputeKernel.metal). These two kernels are not identical, please focus on macOS one.

## Photo Factory

This is a final project of the course named Software Engineering. It has friendly UI, and real-time rendering for input image or RAW file. More features are included at report.PDF file in that folder.

## FFT Testing

Case 1:

![Input 512*512](/TestingCase/1_512.jpg)

![Output](/TestingCase/1_output.jpg)

Case 2:
![Input 4096*4096](/TestingCase/2_4096.jpg)

![Output](/TestingCase/2_output.jpg)

