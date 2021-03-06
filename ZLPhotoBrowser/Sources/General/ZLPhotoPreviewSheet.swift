//
//  ZLPhotoPreviewSheet.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/11.
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
import Photos

public class ZLPhotoPreviewSheet: UIView {

    struct Layout {
        
        static let colH: CGFloat = 155
        
        static let btnH: CGFloat = 45
        
        static let spacing: CGFloat = 1 / UIScreen.main.scale
        
    }
    
    private var baseView: UIView!
    
    private var collectionView: UICollectionView!
    
    private var cameraBtn: UIButton!
    
    private var photoLibraryBtn: UIButton!
    
    private var cancelBtn: UIButton!
    
    private var flexibleView: UIView!
    
    private var placeholderLabel: UILabel!
    
    private var arrDataSources: [ZLPhotoModel] = []
    
    private var arrSelectedModels: [ZLPhotoModel] = []
    
    private var preview = false
    
    private var baseViewHeight: CGFloat = 0
    
    private var isSelectOriginal = false
    
    private weak var sender: UIViewController?
    
    private var fetchImageQueue: OperationQueue = OperationQueue()
    
    /// Success callback
    /// block params
    ///  - params1: images for asset.
    ///  - params2: selected assets
    ///  - params3: is full image
    @objc public var selectImageBlockOo: ( ([UIImage], [PHAsset], Bool) -> Void )?
    

    deinit {
        zl_debugPrint("ZLPhotoPreviewSheet deinit")
    }
    
    
    /// - Parameter selectedAssets: preselected assets
    @objc public init(selectedAssets: [PHAsset] = []) {
        super.init(frame: .zero)
        
        if !ZLPhotoConfiguration.default().allowSelectImage &&
            !ZLPhotoConfiguration.default().allowSelectVideo {
            assert(false, "ZLPhotoBrowser: error configuration")
            ZLPhotoConfiguration.default().allowSelectImage = true
        }
        
        self.fetchImageQueue.maxConcurrentOperationCount = 3
        self.setupUI()
        
        self.arrSelectedModels.removeAll()
        selectedAssets.removeDuplicate().forEach { (asset) in
         
            let m = ZLPhotoModel(asset: asset)
            m.isSelected = true
            self.arrSelectedModels.append(m)
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.baseView.frame = CGRect(x: 0, y: self.bounds.height - self.baseViewHeight, width: self.bounds.width, height: self.baseViewHeight)
        
        var btnY: CGFloat = 0
        if ZLPhotoConfiguration.default().maxPreviewCount > 0 {
            self.collectionView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.colH)
            btnY += (self.collectionView.frame.maxY + ZLPhotoPreviewSheet.Layout.spacing)
        }
        if self.canShowCameraBtn() {
            self.cameraBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
            btnY += (ZLPhotoPreviewSheet.Layout.btnH + ZLPhotoPreviewSheet.Layout.spacing)
        }
        self.photoLibraryBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
        btnY += (ZLPhotoPreviewSheet.Layout.btnH + ZLPhotoPreviewSheet.Layout.spacing)
        self.cancelBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
        btnY += ZLPhotoPreviewSheet.Layout.btnH
        self.flexibleView.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: self.baseViewHeight - btnY)
    }
    
    func setupUI() {
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = .previewBgColor
        
        let showCameraBtn = self.canShowCameraBtn()
        var bh: CGFloat = 0
        if ZLPhotoConfiguration.default().maxPreviewCount > 0 {
            bh += ZLPhotoPreviewSheet.Layout.colH
        }
        bh += (ZLPhotoPreviewSheet.Layout.spacing + ZLPhotoPreviewSheet.Layout.btnH) * (showCameraBtn ? 3 : 2)
        bh += deviceSafeAreaInsets().bottom
        self.baseViewHeight = bh
        
        self.baseView = UIView()
        self.baseView.backgroundColor = zlRGB(230, 230, 230)
        self.addSubview(self.baseView)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 3
        layout.minimumLineSpacing = 3
        layout.sectionInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.collectionView.backgroundColor = .previewBtnBgColor
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.isHidden = ZLPhotoConfiguration.default().maxPreviewCount == 0
        ZLThumbnailPhotoCell.zl_register(self.collectionView)
        self.baseView.addSubview(self.collectionView)
        
        self.placeholderLabel = UILabel()
        self.placeholderLabel.font = getFont(15)
        self.placeholderLabel.text = localLanguageTextValue(.noPhotoTips)
        self.placeholderLabel.textAlignment = .center
        self.placeholderLabel.textColor = .previewBtnTitleColor
        self.collectionView.backgroundView = self.placeholderLabel
        
        func createBtn(_ title: String) -> UIButton {
            let btn = UIButton(type: .custom)
            btn.backgroundColor = .previewBtnBgColor
            btn.setTitleColor(.previewBtnTitleColor, for: .normal)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = getFont(17)
            return btn
        }
        
        let cameraTitle: String
        if !ZLPhotoConfiguration.default().allowTakePhoto, ZLPhotoConfiguration.default().allowRecordVideo {
            cameraTitle = localLanguageTextValue(.previewCameraRecord)
        } else {
            cameraTitle = localLanguageTextValue(.previewCamera)
        }
        self.cameraBtn = createBtn(cameraTitle)
        self.cameraBtn.isHidden = !showCameraBtn
        self.cameraBtn.addTarget(self, action: #selector(cameraBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.cameraBtn)
        
        self.photoLibraryBtn = createBtn(localLanguageTextValue(.previewAlbum))
        self.photoLibraryBtn.addTarget(self, action: #selector(photoLibraryBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.photoLibraryBtn)
        
        self.cancelBtn = createBtn(localLanguageTextValue(.cancel))
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.cancelBtn)
        
        self.flexibleView = UIView()
        self.flexibleView.backgroundColor = .previewBtnBgColor
        self.baseView.addSubview(self.flexibleView)
        
 
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tap.delegate = self
        self.addGestureRecognizer(tap)
    }
    
    func canShowCameraBtn() -> Bool {
        if !ZLPhotoConfiguration.default().allowTakePhoto, !ZLPhotoConfiguration.default().allowRecordVideo {
            return false
        }
        return true
    }
    
    @objc public func showPreview(sender: UIViewController) {
        self.show(preview: true, animate: true, sender: sender)
    }
    
    @objc public func showPhotoLibrary(sender: UIViewController) {
        self.show(preview: false, animate: false, sender: sender)
    }
    
    /// ??????????????????assets????????????
    @objc public func previewAssets(sender: UIViewController, assets: [PHAsset], index: Int, isOriginal: Bool) {
        let models = assets.removeDuplicate().map { (asset) -> ZLPhotoModel in
            let m = ZLPhotoModel(asset: asset)
            m.isSelected = true
            return m
        }
        self.arrSelectedModels.removeAll()
        self.arrSelectedModels.append(contentsOf: models)
        self.sender = sender
        self.isSelectOriginal = isOriginal
        self.isHidden = true
        self.sender?.view.addSubview(self)
        

        if models.count > 0{
            showEditImageVC(model: models[0])
        }
        
        
        
        
        
        
        
        
    }
    
    func show(preview: Bool, animate: Bool, sender: UIViewController) {
        self.preview = preview
        self.sender = sender
        
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .restricted || status == .denied {
            self.showNoAuthorityAlert()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    if status == .denied {
                        self.showNoAuthorityAlert()
                    } else if status == .authorized {
                        if self.preview {
                            self.loadPhotos()
                            self.show()
                        } else {
                            self.photoLibraryBtnClick()
                        }
                    }
                }
            }
            
            self.sender?.view.addSubview(self)
        } else {
            if preview {
                self.loadPhotos()
                self.show()
            } else {
                self.sender?.view.addSubview(self)
                self.photoLibraryBtnClick()
            }
        }
        
        // Register for the album change notification when the status is limited, because the photoLibraryDidChange method will be repeated multiple times each time the album changes, causing the interface to refresh multiple times. So the album changes are not monitored in other authority.
        if #available(iOS 14.0, *), preview, PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            PHPhotoLibrary.shared().register(self)
        }
    }
    
    func loadPhotos() {
        self.arrDataSources.removeAll()
        
        let config = ZLPhotoConfiguration.default()
        ZLPhotoManager.getCameraRollAlbum(allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else { return }
            var totalPhotos = ZLPhotoManager.fetchPhoto(in: cameraRoll.result, ascending: false, allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo, limitCount: config.maxPreviewCount)
            markSelected(source: &totalPhotos, selected: &self.arrSelectedModels)
            self.arrDataSources.append(contentsOf: totalPhotos)
            self.collectionView.reloadData()
        }
    }
    
    func show() {
        self.frame = self.sender?.view.bounds ?? .zero
        
        self.collectionView.contentOffset = .zero
        
        if self.superview == nil {
            self.sender?.view.addSubview(self)
        }

    }
    
    func hide(completion: ( () -> Void )? = nil) {
 
            self.isHidden = true
            completion?()
            self.removeFromSuperview()
    }
    
    func showNoAuthorityAlert() {
        let alert = UIAlertController(title: nil, message: String(format: localLanguageTextValue(.noPhotoLibratyAuthority), getAppName()), preferredStyle: .alert)
        let action = UIAlertAction(title: localLanguageTextValue(.ok), style: .default) { (_) in
            ZLPhotoConfiguration.default().noAuthorityCallback?(.library)
        }
        alert.addAction(action)
        self.sender?.showDetailViewController(alert, sender: nil)
    }
    
    @objc func tapAction(_ tap: UITapGestureRecognizer) {
        self.hide {}
    }
    
    @objc func cameraBtnClick() {
        let config = ZLPhotoConfiguration.default()
        if config.useCustomCamera {
            let camera = ZLCustomCamera()
            camera.takeDoneBlockX = { [weak self] (image) in
                self?.saveX(image: image)
            }
            self.sender?.showDetailViewController(camera, sender: nil)
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.videoQuality = .typeHigh
                picker.sourceType = .camera
                picker.cameraFlashMode = config.cameraConfiguration.flashMode.imagePickerFlashMode
                var mediaTypes = [String]()
                if config.allowTakePhoto {
                    mediaTypes.append("public.image")
                }
                if config.allowRecordVideo {
                    mediaTypes.append("public.movie")
                }
                picker.mediaTypes = mediaTypes
                picker.videoMaximumDuration = TimeInterval(config.maxRecordDuration)
                self.sender?.showDetailViewController(picker, sender: nil)
            } else {
                showAlertView(localLanguageTextValue(.cameraUnavailable), self.sender)
            }
        }
    }
    
    @objc func photoLibraryBtnClick() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

        
    }
    
    @objc func cancelBtnClick() {
        guard !self.arrSelectedModels.isEmpty else {
            self.hide { }
            return
        }
        self.requestSelectPhoto()
    }
    

    
    func requestSelectPhoto(viewController: UIViewController? = nil) {
        guard !self.arrSelectedModels.isEmpty else {
            self.selectImageBlockOo?([], [], self.isSelectOriginal)
            self.hide()
            viewController?.dismiss(animated: true, completion: nil)
            return
        }
    
        let callback = { [weak self] (sucImages: [UIImage], sucAssets: [PHAsset], errorAssets: [PHAsset], errorIndexs: [Int]) in
            
            if let vc = viewController {
                self?.isHidden = true
                vc.dismiss(animated: true) {
                    self?.selectImageBlockOo?(sucImages, sucAssets, self?.isSelectOriginal ?? false)
                    self?.hide()
                }
            } else {
                self?.hide(completion: {
                    self?.selectImageBlockOo?(sucImages, sucAssets, self?.isSelectOriginal ?? false)
                })
            }
            
            self?.arrSelectedModels.removeAll()
            self?.arrDataSources.removeAll()
        }
        
        guard ZLPhotoConfiguration.default().shouldAnialysisAsset else {
            callback([], self.arrSelectedModels.map { $0.asset }, [], [])
            return
        }
        
        var images: [UIImage?] = Array(repeating: nil, count: self.arrSelectedModels.count)
        var assets: [PHAsset?] = Array(repeating: nil, count: self.arrSelectedModels.count)
        var errorAssets: [PHAsset] = []
        var errorIndexs: [Int] = []
        
        var sucCount = 0
        let totalCount = self.arrSelectedModels.count
        for (i, m) in self.arrSelectedModels.enumerated() {
            let operation = ZLFetchImageOperation(model: m, isOriginal: self.isSelectOriginal) { (image, asset) in
               
                sucCount += 1
                
                if let image = image {
                    images[i] = image
                    assets[i] = asset ?? m.asset
                    zl_debugPrint("ZLPhotoBrowser: suc request \(i)")
                } else {
                    errorAssets.append(m.asset)
                    errorIndexs.append(i)
                    zl_debugPrint("ZLPhotoBrowser: failed request \(i)")
                }
                
                guard sucCount >= totalCount else { return }
                
                callback(
                    images.compactMap { $0 },
                    assets.compactMap { $0 },
                    errorAssets,
                    errorIndexs
                )
            }
            self.fetchImageQueue.addOperation(operation)
        }
    }
    
    
    func showEditImageVC(model: ZLPhotoModel) {
   
        
        ZLPhotoManager.fetchImage(for: model.asset, size: model.previewSize) { [weak self] (image, isDegraded) in
            if !isDegraded {
                if let image = image {
                    let editModel = model.editImageModel
              
                    let vc = ZLClipImageViewController(image: image, editRect: editModel?.editRect, angle: editModel?.angle ?? 0)
                    vc.clipDoneBlockZz = { [weak self]  (angle) in
                        let ei = image.clipImage(angle) ?? image
                        let editImageModel = ZLEditImageModel(editRect: CGRect.zero, angle: angle)
                  
                            model.isSelected = true
                            model.editImage = ei
                            model.editImageModel = editImageModel
                            self?.arrSelectedModels.append(model)
                            self?.requestSelectPhoto()
                    }
                    vc.modalPresentationStyle = .fullScreen
                    self?.sender?.present(vc, animated: true, completion: nil)
                    
                    
                } else {
                    showAlertView(localLanguageTextValue(.imageLoadFailed), self?.sender)
                }
            }
        }
    }
    
    
    func saveX(image: UIImage?) {
   
        if let image = image {
           
            ZLPhotoManager.saveImageToAlbum(image: image) { [weak self] (suc, asset) in
                if suc, let at = asset {
                    let model = ZLPhotoModel(asset: at)
                    self?.handleDataArray(newModel: model)
                } else {
                    showAlertView(localLanguageTextValue(.saveImageError), self?.sender)
                }
         
            }
        }
    }
    
    func handleDataArray(newModel: ZLPhotoModel) {
        self.arrDataSources.insert(newModel, at: 0)
        
        let insertIndexPath = IndexPath(row: 0, section: 0)
        self.collectionView.performBatchUpdates({
            self.collectionView.insertItems(at: [insertIndexPath])
        }) { (_) in
            self.collectionView.scrollToItem(at: insertIndexPath, at: .centeredHorizontally, animated: true)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
        }
        
        self.changeCancelBtnTitle()
    }
    
}


extension ZLPhotoPreviewSheet: UIGestureRecognizerDelegate {
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self)
        return !self.baseView.frame.contains(location)
    }
    
}


extension ZLPhotoPreviewSheet: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let m = self.arrDataSources[indexPath.row]
        let w = CGFloat(m.asset.pixelWidth)
        let h = CGFloat(m.asset.pixelHeight)
        let scale = min(1.7, max(0.5, w / h))
        return CGSize(width: collectionView.frame.height * scale, height: collectionView.frame.height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.placeholderLabel.isHidden = self.arrSelectedModels.isEmpty
        return self.arrDataSources.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZLThumbnailPhotoCell.zl_identifier(), for: indexPath) as! ZLThumbnailPhotoCell
        
        let model = self.arrDataSources[indexPath.row]
        
        cell.selectedBlock = { [weak self, weak cell] (isSelected) in
            guard let `self` = self else { return }
            if !isSelected {
                guard canAddModel(model, currentSelectCount: self.arrSelectedModels.count, sender: self.sender) else {
                    return
                }
                
            } else {
                cell?.btnSelect.isSelected = false
                model.isSelected = false
                self.arrSelectedModels.removeAll { $0 == model }
                self.refreshCellIndex()
            }
            
            self.changeCancelBtnTitle()
        }
        
        cell.indexLabel.isHidden = true
        if ZLPhotoConfiguration.default().showSelectedIndex {
            for (index, selM) in self.arrSelectedModels.enumerated() {
                if model == selM {
                    self.setCellIndex(cell, showIndexLabel: true, index: index + 1)
                    break
                }
            }
        }
        
        self.setCellMaskView(cell, isSelected: model.isSelected, model: model)
        
        cell.model = model
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let c = cell as? ZLThumbnailPhotoCell else {
            return
        }
        let model = self.arrDataSources[indexPath.row]
        self.setCellMaskView(c, isSelected: model.isSelected, model: model)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
            return
        }
        
        if !ZLPhotoConfiguration.default().allowPreviewPhotos {
            cell.btnSelectClick()
            return
        }
        
        if !cell.enableSelect, ZLPhotoConfiguration.default().showInvalidMask {
            return
        }
        let model = self.arrDataSources[indexPath.row]
        
        showEditImageVC(model: model)
       
    }
    

    
    func setCellIndex(_ cell: ZLThumbnailPhotoCell?, showIndexLabel: Bool, index: Int) {
        guard ZLPhotoConfiguration.default().showSelectedIndex else {
            return
        }
        cell?.index = index
        cell?.indexLabel.isHidden = !showIndexLabel
    }
    
    func refreshCellIndex() {
        let showIndex = ZLPhotoConfiguration.default().showSelectedIndex
        let showMask = ZLPhotoConfiguration.default().showSelectedMask || ZLPhotoConfiguration.default().showInvalidMask
        
        guard showIndex || showMask else {
            return
        }
        
        let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems
        
        visibleIndexPaths.forEach { (indexPath) in
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
                return
            }
            let m = self.arrDataSources[indexPath.row]
            
            var show = false
            var idx = 0
            var isSelected = false
            for (index, selM) in self.arrSelectedModels.enumerated() {
                if m == selM {
                    show = true
                    idx = index + 1
                    isSelected = true
                    break
                }
            }
            if showIndex {
                self.setCellIndex(cell, showIndexLabel: show, index: idx)
            }
            if showMask {
                self.setCellMaskView(cell, isSelected: isSelected, model: m)
            }
        }
    }
    
    func setCellMaskView(_ cell: ZLThumbnailPhotoCell, isSelected: Bool, model: ZLPhotoModel) {
        cell.coverView.isHidden = true
        cell.enableSelect = true
        let config = ZLPhotoConfiguration.default()
        
        if isSelected {
            cell.coverView.backgroundColor = .selectedMaskColor
            cell.coverView.isHidden = !config.showSelectedMask
            if config.showSelectedBorder {
                cell.layer.borderWidth = 4
            }
        } else {
            let selCount = self.arrSelectedModels.count
            if selCount < 1 {
                if selCount > 0 {
                    cell.coverView.backgroundColor = .invalidMaskColor
                    cell.coverView.isHidden = (!config.showInvalidMask)
                    
                }
            } else if selCount >= 1 {
                cell.coverView.backgroundColor = .invalidMaskColor
                cell.coverView.isHidden = !config.showInvalidMask
                cell.enableSelect = false
            }
            if config.showSelectedBorder {
                cell.layer.borderWidth = 0
            }
        }
    }
    
    func changeCancelBtnTitle() {
        if self.arrSelectedModels.count > 0 {
            self.cancelBtn.setTitle(String(format: "%@(%ld)", localLanguageTextValue(.done), self.arrSelectedModels.count), for: .normal)
            self.cancelBtn.setTitleColor(.previewBtnHighlightTitleColor, for: .normal)
        } else {
            self.cancelBtn.setTitle(localLanguageTextValue(.cancel), for: .normal)
            self.cancelBtn.setTitleColor(.previewBtnTitleColor, for: .normal)
        }
    }
    
}


extension ZLPhotoPreviewSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            let image = info[.originalImage] as? UIImage
         
            self.saveX(image: image)
        }
    }
    
}


extension ZLPhotoPreviewSheet: PHPhotoLibraryChangeObserver {
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        DispatchQueue.main.async {
            self.loadPhotos()
        }
    }
    
}
