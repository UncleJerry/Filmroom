# Filmroom, an image process playground

> With the help of Core Image to implement custom kernel.
> 
> Currently Swift 3 + iOS 10




## Filter include

- [x] Exposure,
- [x] Shadow & highlight
- [x] Saturation
- [x] Contrast
- [x] HSL for Orange
- [ ] Color Management
- [ ] To be continued …




## Test
Thanks to Core Image, you can test these filters by images supported by it. Output is available.

## Kernel codes
All Kernels locate in CustomKernel functions from CustomFilter.swift, you can also find them in Kernels.cikernel with comments under the root directory.

## Filter Chain
The app links all filters together by this order:

1. Exposure
2. Shadow
3. Highlight
4. Contrast
5. Saturation
6. HSV (HSL)

This flow is based on my experience on Lightroom, but requires more experiment
