# Filmroom, an image process playground

> 
> 
> Swift 3 + iOS 10 or Swift 4 + macOS 10.13






## iOS Filter include

- [x] Exposure,
- [x] Shadow & highlight
- [x] Saturation
- [x] Contrast
- [x] HSL for Orange

## macOS Filters Filters

- [x] Gamma Correction
- [x] Gaussian Blur (High amount of pixel is unstable)

## macOS Features
- [x] Real-Time Rendering via MTKView
	- [x] Adapted aspect radio
	- [x] Lowest CPU cost with fewest data type conversion

This way is much more faster than DispatchQueue method.

## Test

Thanks to Core Image, you can test these filters by images supported by it. Output is available.

## Kernel codes

All Kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel for Core Image Kernel with comments under the iOS directory. The Metal Kernel is located in macOS folder.


