//
//  ZLClipImageViewController.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/27.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit


import AVFoundation


class ZLClipImageViewController: UIViewController {

    static let bottomToolViewH: CGFloat = 90
    
    static let clipRatioItemSize: CGSize = CGSize(width: 60, height: 70)
    
    var editImage: UIImage
    
    var containerView: UIView!
    
    var imageView: UIImageView!
    
    var bottomToolView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var bottomToolLineView: UIView!
    
    var cancelBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var rotateBtn: UIButton!
    
    var shouldLayout = true
    
    
    var clipBoxFrame: CGRect = .zero
    
    var clipOriginFrame: CGRect = .zero
    

    
    var angle: CGFloat = 0
    
    
    lazy var maxClipFrame: CGRect = {
        var insets = deviceSafeAreaInsets()
        insets.top +=  20
        var rect = CGRect.zero
        rect.origin.x = 15
        rect.origin.y = insets.top
        rect.size.width = UIScreen.main.bounds.width - 15 * 2
        rect.size.height = UIScreen.main.bounds.height - insets.top - ZLClipImageViewController.bottomToolViewH - ZLClipImageViewController.clipRatioItemSize.height - 25
        return rect
    }()
    
    var minClipSize = CGSize(width: 45, height: 45)
    
    /// 传回旋转角度，图片编辑区域的rect
    var clipDoneBlockZz: ( (CGFloat) -> Void )?
    
    var cancelClipBlockQq: ( () -> Void )?
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    
    init(image: UIImage, editRect: CGRect?, angle: CGFloat = 0) {
        self.angle = angle
        if angle == -90 {
            self.editImage = image.rotate(orientation: .left)
        } else if self.angle == -180 {
            self.editImage = image.rotate(orientation: .down)
        } else if self.angle == -270 {
            self.editImage = image.rotate(orientation: .right)
        } else {
            self.editImage = image
        }
      
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .black
        
        
        
        self.containerView = UIView()
        
        self.view.addSubview(self.containerView)
        self.imageView = UIImageView(image: self.editImage)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        self.containerView.addSubview(self.imageView)
        
        self.bottomToolView = UIView()
        self.view.addSubview(self.bottomToolView)
        
        let color1 = UIColor.black.withAlphaComponent(0.15).cgColor
        let color2 = UIColor.black.withAlphaComponent(0.35).cgColor
        
        self.bottomShadowLayer = CAGradientLayer()
        self.bottomShadowLayer.colors = [color1, color2]
        self.bottomShadowLayer.locations = [0, 1]
        self.bottomToolView.layer.addSublayer(self.bottomShadowLayer)
        
        self.bottomToolLineView = UIView()
        self.bottomToolLineView.backgroundColor = zlRGB(240, 240, 240)
        self.bottomToolView.addSubview(self.bottomToolLineView)
        
        self.cancelBtn = UIButton(type: .custom)
        self.cancelBtn.setImage(getImage("zl_close"), for: .normal)
        self.cancelBtn.adjustsImageWhenHighlighted = false
        self.cancelBtn.zl_enlargeValidTouchArea(inset: 20)
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.cancelBtn)
        
        
        self.doneBtn = UIButton(type: .custom)
        self.doneBtn.setImage(getImage("zl_right"), for: .normal)
        self.doneBtn.adjustsImageWhenHighlighted = false
        self.doneBtn.zl_enlargeValidTouchArea(inset: 20)
        self.doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.doneBtn)
        
        self.rotateBtn = UIButton(type: .custom)
        self.rotateBtn.setImage(getImage("zl_rotateimage"), for: .normal)
        self.rotateBtn.adjustsImageWhenHighlighted = false
        self.rotateBtn.zl_enlargeValidTouchArea(inset: 20)
        self.rotateBtn.addTarget(self, action: #selector(rotateBtnClick), for: .touchUpInside)
        self.view.addSubview(self.rotateBtn)
        

    }
    
 
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard self.shouldLayout else {
            return
        }
        self.shouldLayout = false
        
        self.containerView.frame = self.view.bounds
        
        self.layoutInitialImage()
        
        self.bottomToolView.frame = CGRect(x: 0, y: self.view.bounds.height-ZLClipImageViewController.bottomToolViewH, width: self.view.bounds.width, height: ZLClipImageViewController.bottomToolViewH)
        self.bottomShadowLayer.frame = self.bottomToolView.bounds
        
        self.bottomToolLineView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 1/UIScreen.main.scale)
        let toolBtnH: CGFloat = 25
        let toolBtnY = (ZLClipImageViewController.bottomToolViewH - toolBtnH) / 2 - 10
        self.cancelBtn.frame = CGRect(x: 30, y: toolBtnY, width: toolBtnH, height: toolBtnH)
      
        self.doneBtn.frame = CGRect(x: self.view.bounds.width-30-toolBtnH, y: toolBtnY, width: toolBtnH, height: toolBtnH)
        
        let ratioColViewY = self.bottomToolView.frame.minY - ZLClipImageViewController.clipRatioItemSize.height - 5
        self.rotateBtn.frame = CGRect(x: 30, y: ratioColViewY + (ZLClipImageViewController.clipRatioItemSize.height-25)/2, width: 25, height: 25)
      
    }
    


    
    func layoutInitialImage(){

  
        var frame = containerView.frame
        frame.origin.x = 10
        frame.origin.y = 10
        frame.size.width -= 20
        frame.size.height -= 180
        self.imageView.frame = AVMakeRect(aspectRatio: editImage.size, insideRect: frame)
        
        
    

    }
    
    
    @objc func cancelBtnClick() {

        self.cancelClipBlockQq?()
        self.dismiss(animated: true, completion: nil)
    }
    

    
    @objc func doneBtnClick() {

        self.clipDoneBlockZz?(self.angle)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func rotateBtnClick() {

        self.angle -= 90
        if self.angle == -360 {
            self.angle = 0
        }
        
            print("aaaa  aaaaa    xxxx")
            // 自由比例和1:1比例，进行edit rect转换
            
            // 将edit rect转换为相对edit image的rect

            // 旋转图片
            self.editImage = self.editImage.rotate(orientation: .left)
            // 将rect进行旋转，转换到相对于旋转后的edit image的rect
       
    
        
        self.imageView.image = self.editImage
        self.layoutInitialImage()
    }

    

    
}




