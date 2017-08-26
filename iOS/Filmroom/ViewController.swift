//
//  ViewController.swift
//  Filmroom
//
//  Created by 周建明 on 2017/7/8.
//  Copyright © 2017年 Uncle Jerry. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.delegate = self
        
        //CIFilter.registerName("Exposure Filter", constructor: FilterVendor(), classAttributes: [kCIAttributeFilterName: "Exposure Filter"])
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func Adjust(_ sender: UISlider) {
        if MyImageView.image == nil {
            ErrorAlert(message: "Please Load Image first")
            return
        }
        
        let input = processedImage
        
        let exposure = ExposureFilter()
        let expoUnit = ExpSlider.value
        
        let shadow = ShadowFilter()
        let shadowUnit = ShadowSlider.value
        
        let highlight = HighlightFilter()
        let hlUnit = HLSlider.value
        
        let contrast = ContrastFilter()
        let contrastUnit = ContrastSlider.value
        
        let hsv = HSLFilter()
        let shift = CIVector(x: CGFloat(HueSlider.value), y: CGFloat(SatSlider.value), z: CGFloat(LumSlider.value))
        
        let saturation = SaturationFilter()
        let satUnit = SatSlider.value
        
        exposure.setValue(input, forKey: kCIInputImageKey)
        exposure.setValue(expoUnit, forKey: "inputUnit")
        
        shadow.setValue(exposure.outputImage, forKey: kCIInputImageKey)
        shadow.setValue(shadowUnit, forKey: "inputUnit")
        
        highlight.setValue(shadow.outputImage, forKey: kCIInputImageKey)
        highlight.setValue(hlUnit, forKey: "inputUnit")
        
        contrast.setValue(highlight.outputImage, forKey: kCIInputImageKey)
        contrast.setValue(contrastUnit, forKey: "inputUnit")
        
        saturation.setValue(contrast.outputImage, forKey: kCIInputImageKey)
        saturation.setValue(satUnit, forKey: "inputUnit")
        
        hsv.setValue(saturation.outputImage, forKey: kCIInputImageKey)
        hsv.setValue(shift, forKey: "inputShift0")
        
        
        
        resultImage = hsv.outputImage!
        
        MyImageView.image = UIImage(ciImage: hsv.outputImage)
    }

    @IBOutlet weak var HueSlider: UISlider!
    @IBOutlet weak var SatSlider: UISlider!
    @IBOutlet weak var LumSlider: UISlider!
    @IBOutlet weak var ExpSlider: UISlider!
    @IBOutlet weak var ContrastSlider: UISlider!
    @IBOutlet weak var HLSlider: UISlider!
    @IBOutlet weak var ShadowSlider: UISlider!
    @IBOutlet weak var MyImageView: UIImageView!
    let picker = UIImagePickerController()
    var processedImage: CIImage?
    var resultImage: CIImage?
    let context = CIContext()
    
    @IBAction func LoadImage(_ sender: UIButton) {
        
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
        
        HueSlider.value = 0.0828158104110671
        SatSlider.value = 1
        LumSlider.value = 1
        ExpSlider.value = 0
        ContrastSlider.value = 1
        HLSlider.value = 0
        ShadowSlider.value = 0
        SatSlider.value = 1
        
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func SaveImage(_ sender: UIButton) {
        if MyImageView.image == nil {
            ErrorAlert(message: "Please Load Image first")
            return
        }
        let cgimage = context.createCGImage(resultImage!, from: (resultImage?.extent)!)
        let toBeSaved = UIImage(cgImage: cgimage!)
        let vc = UIActivityViewController(activityItems: [toBeSaved], applicationActivities: [])
        vc.excludedActivityTypes =  [
            //UIActivityTypePostToTwitter,
            UIActivityType.postToFacebook,
            //UIActivityType.postToWeibo,
            UIActivityType.message,
            //UIActivityTypeMail,
            UIActivityType.print,
            UIActivityType.copyToPasteboard,
            UIActivityType.assignToContact,
            //UIActivityType.saveToCameraRoll,
            UIActivityType.addToReadingList,
            UIActivityType.postToFlickr,
            UIActivityType.postToVimeo,
            UIActivityType.postToTencentWeibo
        ]
        present(vc, animated: true, completion: nil)
        vc.popoverPresentationController?.sourceView = self.view
        vc.completionWithItemsHandler = {(activity, success, items, error) in }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]){
        MyImageView.image = info[UIImagePickerControllerOriginalImage] as? UIImage
        processedImage = CIImage(image: MyImageView.image!)
        
        dismiss(animated:true, completion: nil)
    }
}

