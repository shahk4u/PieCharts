//
//  PieChart.swift
//  PieChart2
//
//  Created by ischuetz on 06/06/16.
//  Copyright © 2016 Ivan Schütz. All rights reserved.
//

import UIKit

open class PieChart: UIView {
    
    public fileprivate(set) var container: CALayer = CALayer()
    
    fileprivate var slices: [PieSlice] = []
    
    public var models: [PieSliceModel] = [] {
        didSet {
            if oldValue.isEmpty {
                slices = generateSlices(models)
                showSlices()
            }
        }
    }
    
    public var settings = PieChartSettings()
    
    public weak var delegate: PieChartDelegate?
    
    public var layers: [PieChartLayer] = [] {
        didSet {
            for layer in layers {
                layer.chart = self
            }
        }
    }
    
    public var totalValue: Double {
        return models.reduce(0){$0 + $1.value}
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }
    
    private func sharedInit() {
        layer.addSublayer(container)
        container.frame = bounds
    }
    
    fileprivate func generateSlices(_ models: [PieSliceModel]) -> [PieSlice] {
        var slices: [PieSlice] = []
        var lastEndAngle: CGFloat = 0
        
        for (index, model) in models.enumerated() {
            let (newEndAngle, slice) = generateSlice(model: model, index: index, lastEndAngle: lastEndAngle, totalValue: totalValue)
            slices.append(slice)
            
            lastEndAngle = newEndAngle
        }
        
        return slices
    }
    
    fileprivate func generateSlice(model: PieSliceModel, index: Int, lastEndAngle: CGFloat, totalValue: Double) -> (CGFloat, PieSlice) {
        let percentage = 1 / (totalValue / model.value)
        let angle = (Double.pi * 2) * percentage
        let newEndAngle = lastEndAngle + CGFloat(angle)
        
        let data = PieSliceData(model: model, id: index, percentage: percentage)
        let slice = PieSlice(data: data, view: PieSliceLayer(color: model.color, startAngle: lastEndAngle, endAngle: newEndAngle, animDelay: 0, center: bounds.center))
        
        slice.view.frame = bounds
        
        slice.view.sliceData = data
        
        slice.view.innerRadius = settings.innerRadius
        slice.view.outerRadius = settings.outerRadius
        slice.view.referenceAngle = settings.referenceAngle
        slice.view.selectedOffset = settings.selectedOffset
        slice.view.animDuration = settings.animDuration
        
        slice.view.sliceDelegate = self
     
        return (newEndAngle, slice)
    }
    
    
    fileprivate func showSlices() {
        for slice in slices {
            container.addSublayer(slice.view)
            
            slice.view.rotate(angle: slice.view.referenceAngle)
            
            slice.view.startAnim()
        }
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            
            if let slice = (slices.filter{$0.view.contains(point)}).first {
                slice.view.selected = !slice.view.selected
            }
        }
    }
    
    public func insertSlice(index: Int, model: PieSliceModel) {
        
        guard index < slices.count else {print("Out of bounds index: \(index), slices count: \(slices.count), exit"); return}
        
        for layer in layers {
            layer.clear()
        }
        
        func wrap(angle: CGFloat) -> CGFloat {
            return angle.truncatingRemainder(dividingBy: CGFloat.pi * 2)
        }
        
        let newSlicePercentage = 1 / ((totalValue + model.value) / model.value)
        let remainingPercentage = 1 - newSlicePercentage
        
        let currentSliceAtIndexEndAngle = index == 0 ? 0 : wrap(angle: slices[index - 1].view.endAngle)
        let currentSliceAfterIndeStartAngle = index == 0 ? 0 : wrap(angle: slices[index].view.startAngle)
        
        var offset = CGFloat.pi * 2 * CGFloat(newSlicePercentage)
        var lastEndAngle = currentSliceAfterIndeStartAngle + offset
        
        let (_, slice) = generateSlice(model: model, index: index, lastEndAngle: currentSliceAtIndexEndAngle, totalValue: model.value + totalValue)
        
        container.addSublayer(slice.view)
        
        slice.view.setEndAngle(angle: slice.view.startAngle, animated: false)
        slice.view.startAnim()
        
        let slicesToAdjust = Array(slices[index..<slices.count]) + Array(slices[0..<index])
        
        models.insert(model, at: index)
        slices.insert(slice, at: index)

        for (index, slice) in slices.enumerated() {
            slice.data.id = index
        }
        
        for slice in slicesToAdjust {
            let currentAngle = slice.view.endAngle - slice.view.startAngle
            let newAngle = currentAngle * CGFloat(remainingPercentage)
            let angleDelta = newAngle - currentAngle
            
            let start = lastEndAngle < slice.view.startAngle ? CGFloat.pi * 2 + lastEndAngle : lastEndAngle
            offset = offset + angleDelta
            
            var end = slice.view.endAngle + offset
            end = end.truncateDefault() < slice.view.endAngle.truncateDefault() ? CGFloat.pi * 2 + end : end
            
            slice.view.angles = (start, end)
            
            lastEndAngle = wrap(angle: end)
            
            slice.data.percentage = 1 / (totalValue / slice.data.model.value)
        }
    }
    
    public func removeSlices() {
        for slice in slices {
            slice.view.removeFromSuperlayer()
        }
        slices = []
    }
}

extension PieChart: PieSliceDelegate {
    
    public func onStartAnimation(slice: PieSlice) {
        for layer in layers {
            layer.onStartAnimation(slice: slice)
        }
        delegate?.onStartAnimation(slice: slice)
    }
    
    public func onEndAnimation(slice: PieSlice) {
        for layer in layers {
            layer.onEndAnimation(slice: slice)
        }
        delegate?.onEndAnimation(slice: slice)
    }
    
    public func onSelected(slice: PieSlice, selected: Bool) {
        for layer in layers {
            layer.onSelected(slice: slice, selected: selected)
        }
        delegate?.onSelected(slice: slice, selected: selected)
    }
}