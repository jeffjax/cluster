//
//  AGS+Additions.swift
//  cluster
//
//  Created by Jeff Jackson on 12/28/16.
//  Copyright © 2016 Esri. All rights reserved.
//


import ArcGIS

extension AGSViewpoint {
    class func forLocation(center: AGSPoint, mapView: AGSMapView, topOffset: CGFloat, bottomOffset: CGFloat) -> AGSViewpoint {
        
        let bottom = mapView.screen(toDistance: bottomOffset)
        let top = mapView.screen(toDistance: topOffset)
        let point = AGSPoint(x: center.x, y: center.y - (bottom - top) / 2, spatialReference: center.spatialReference)
        return AGSViewpoint(center: point, scale: mapView.mapScale)
    }
}

extension AGSMapView {
    func screen(toDistance screen: CGFloat) -> Double {
        let p1 = self.screen(toLocation: CGPoint(x: 0, y: 0))
        let p2 = self.screen(toLocation: CGPoint(x: 0, y: screen))
        return fabs(p1.y - p2.y)
    }
    
    private func inchesPerUnit() -> Double? {
        guard let spatialReference = spatialReference, let unit = spatialReference.unit as? AGSLinearUnit, let inches = AGSLinearUnit(unitID: .inches) else {
            return nil
        }
        return unit.convert(1, to: inches)
    }
    
    public func scale(for resolution: Double) -> Double? {
        guard let inchesPerUnit = inchesPerUnit() else {
            return nil
        }
        return resolution * Double(96) * inchesPerUnit
    }
    
    public func resolution(for scale: Double) -> Double? {
        guard let inchesPerUnit = inchesPerUnit() else {
            return nil
        }
        return scale / (Double(96) * inchesPerUnit)
    }
    
    public func zoom(to envelope: AGSEnvelope, insets: UIEdgeInsets, animated: Bool = true, completion: ((Bool)->Void)? = nil) {
        
        if envelope.hasArea {
            
            // Compute a zoom-to resolution. Resolution is the ratio of map coordinates to device coordinates.
            //
            // The technique used here determines the screen width and height needed for the
            // envelope, at the current map scale. These are compared against current
            // width and height of the view bounds, adjusted by the insets. The ratio of these
            // widths and heights is computed. These ratios represent how much the map resolution
            // needs to be adjusted. The maximum ratio is used to compute a new map resolution
            // based on the current resolution. The map is then zoomed to this new resolution.
            //
            
            guard let spatialReference = spatialReference, let envelopeSR = AGSGeometryEngine.projectGeometry(envelope, to: spatialReference) as? AGSEnvelope else {
                completion?(false)
                return
            }
            
            // Compute current center of offset area
            //
            guard let centerOffset = centerOffset(with: insets) else {
                completion?(false)
                return
            }
            guard let currentResolution = resolution(for: mapScale) else {
                completion?(false)
                return
            }
            
            // First compute the four points corresponding to the four corners of the envelope. Have to
            // do this to account for rotated maps
            //
            let mapP1 = AGSPoint(x: envelopeSR.xMin, y: envelopeSR.yMax, spatialReference: spatialReference)
            let mapP2 = AGSPoint(x: envelopeSR.xMax, y: envelopeSR.yMax, spatialReference: spatialReference)
            let mapP3 = AGSPoint(x: envelopeSR.xMax, y: envelopeSR.yMin, spatialReference: spatialReference)
            let mapP4 = AGSPoint(x: envelopeSR.xMin, y: envelopeSR.yMin, spatialReference: spatialReference)
            
            // Project the points to screen coordinates
            //
            let screenP1 = location(toScreen: mapP1)
            let screenP2 = location(toScreen: mapP2)
            let screenP3 = location(toScreen: mapP3)
            let screenP4 = location(toScreen: mapP4)
            
            // Determine the min and max of the screen points
            //
            let minX = min(min(min(screenP1.x, screenP2.x), screenP3.x), screenP4.x)
            let minY = min(min(min(screenP1.y, screenP2.y), screenP3.y), screenP4.y)
            let maxX = max(max(max(screenP1.x, screenP2.x), screenP3.x), screenP4.x)
            let maxY = max(max(max(screenP1.y, screenP2.y), screenP3.y), screenP4.y)
            
            // Compute required screen width/height
            //
            let screenHeight = maxY - minY
            let screenWidth = maxX - minX
            
            // Compute ratio of required to current width/height
            //
            let ratioW = Double(screenWidth) / Double(bounds.width - insets.left - insets.right)
            let ratioH = Double(screenHeight) / Double(bounds.height - insets.top - insets.bottom)
            
            // Compute new resolution
            //
            var resolutionRatio = max(ratioW, ratioH)
            var newResolution = currentResolution*resolutionRatio
            
            // Handle an attemp to zoom past map's max scale
            //
            if let scale = scale(for: newResolution), let maxScale = map?.maxScale, scale < maxScale {
                newResolution = resolution(for: maxScale)!
                resolutionRatio = newResolution / currentResolution
            }
            
            // Compute offsets to center
            //
            let offsetx = centerOffset.x * resolutionRatio
            let offsety = centerOffset.y * resolutionRatio
            
            // Compute new center using center of envelope and offsets
            //
            let newCenter = AGSPoint(x: envelopeSR.extent.center.x + offsetx, y: envelopeSR.extent.center.y + offsety, spatialReference: spatialReference)
            
            if let scale = scale(for: newResolution) {
                if animated {
                    setViewpointCenter(newCenter, scale: scale, completion: completion)
                } else {
                    let viewpoint = AGSViewpoint(center: newCenter, scale: scale)
                    setViewpoint(viewpoint)
                    completion?(true)
                }
            }
            
        } else {
            
            center(at: envelope.center, insets: insets, animated: animated, completion: completion)
        }
    }
    
    // Determine the offset between the map center and the center caused by
    // the provided offsets
    //
    private func centerOffset(with insets: UIEdgeInsets) -> AGSPoint? {
        
        // Get the current center of the map visible area
        //
        guard let currentCenter = visibleArea?.extent.center else {
            return nil
        }
        
        // Construct the visible area accounting for the offsets, and get
        // its center
        let currentInsetCenter = visibleArea(with: insets).extent.center
        
        // The center offset is the difference between these two centers
        //
        let dx = currentCenter.x - currentInsetCenter.x
        let dy = currentCenter.y - currentInsetCenter.y
        
        return AGSPoint(x: dx, y: dy, spatialReference: currentCenter.spatialReference)
    }
    
    // Centers the map at the specified point with insets. Useful when map is in a navigation controller or has
    // other views over the map
    //
    public func center(at point: AGSPoint, insets: UIEdgeInsets, animated: Bool = true, completion: ((Bool)->Void)? = nil) {
        
        guard let spatialReference = spatialReference else {
            completion?(false)
            return
        }
        
        // Determine the current offset from the map center to the center of the
        // visible area resulting from the insets
        //
        guard let centerOffset = centerOffset(with: insets) else {
            completion?(false)
            return
        }
        
        // Project input to map SR
        //
        guard let inputCenter = AGSGeometryEngine.projectGeometry(point, to: spatialReference) as? AGSPoint else {
            completion?(false)
            return
        }
        
        // Compute the new center by applying the offset to the input
        //
        let newCenter = AGSPointMake(inputCenter.x + centerOffset.x, inputCenter.y + centerOffset.y, spatialReference)
        
        if animated {
            setViewpointCenter(newCenter, completion: completion)
        } else {
            let viewPoint = AGSViewpoint(center: newCenter, scale: mapScale)
            setViewpoint(viewPoint)
            completion?(true)
        }
    }
    // Compute an envelope based on the map view's visible area that defines a "near" area. If geometries
    // are not in the visible area, but they are in the near area, then the geometries are "near". Used
    // in panning the map to features, search results, etc.
    //
    // According to the design, "near" is defined as "<2x min screen side"
    //
    public var nearVisibleArea: AGSPolygon {
        
        let near = 2*min(bounds.size.width, bounds.size.height)
        return visibleArea(with: UIEdgeInsets(top: -near, left: -near, bottom: -near, right: -near))
    }
    
    // Computes a polygon based on the map view's visible area, reduced by the provided insets
    //
    public func visibleArea(with insets: UIEdgeInsets) -> AGSPolygon {
        
        // Inset the bounds rect
        //
        let insetRect = UIEdgeInsetsInsetRect(bounds, insets)
        
        // Compute points in map coordinates for the four corners of the inset rect
        //
        let topLeft = screen(toLocation: insetRect.origin)
        let topRight = screen(toLocation: CGPoint(x: insetRect.origin.x + insetRect.size.width, y: insetRect.origin.y))
        let btmLeft = screen(toLocation: CGPoint(x: insetRect.origin.x, y: insetRect.origin.y + insetRect.size.height))
        let btmRight = screen(toLocation: CGPoint(x: insetRect.origin.x + insetRect.size.width, y: insetRect.origin.y + insetRect.size.height))
        
        // Construct a polygon from the four points
        //
        let part = AGSMutablePart(spatialReference: spatialReference)
        part.addPoint(topLeft)
        part.addPoint(topRight)
        part.addPoint(btmRight)
        part.addPoint(btmLeft)
        
        let builder = AGSPolygonBuilder(spatialReference: spatialReference)
        builder.parts.add(part)
        
        return builder.toGeometry()
    }
    
}


extension AGSEnvelope {
    
    // Does the envelope have an area
    //
    public var hasArea: Bool {
        return width > 0 && height > 0
    }
    
    // Does the envelope represent a point
    //
    public var isZeroDimension: Bool {
        return width == 0 && height == 0
    }
}

