# Filmroom, an image process playground

> 
> Swift 3 + iOS 10 or Swift 4 + macOS 10.13
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

## macOS Features

- Real-Time Rendering via MTKView
	- Adapted aspect radio
	- Lowest CPU cost with fewest data type conversion

This way is much more faster than DispatchQueue method.

## macOS Filters Filters

- [x] Gamma Correction
- [x] Gaussian Blur

Computation Kernels

- [x] 2D FFT in Apple Metal by a Iterative Way
	- [x] 1st: Rearrangement of element
	- [x] 2nd: Calculate FFT from beginning to final stage. 
	- [x] 3rd: Complex to modulus.
- [ ] Composition Relation



## Test

Thanks to Core Image, you can test these filters by images supported by it. Output is available.

The 2D FFT on Metal API has not been tested yet. But currently it is workable and meet no runtime error.

## Comments of This Commit

The FFT function chains are all implemented, but the test results are wrong. I will keep modifying and testing to fix the fault.

## Kernel codes

All Kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel for Core Image Kernel with comments under the iOS directory. 

The Metal Kernel is located in macOS folder.

FFT kernel can be found in Computekernel.metal.

## Photo Factory

This is a final project of the course named Software Engineering. It has friendly UI, and real-time rendering for input image or RAW file. More features are included at report.PDF file in that folder.