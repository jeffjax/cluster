//
//  GraphicsClusteringManager.swift
//  cluster
//
//  Created by Jeff Jackson on 12/29/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import ArcGIS

class GraphicsClusteringManager {
    let graphicsOverlay = AGSGraphicsOverlay()
    
    var graphics: [AGSGraphic] = []
    var clusters = Set<ClusterGraphic>()
    
    func clusterGraphics(mapView: AGSMapView, symbolSize: CGFloat) {
        if graphics.isEmpty {
            return
        }
        
        if mapView.mapScale == mapView.map?.maxScale {
            removeAllClusters()
            return
        }
        
        var toAdd = [AGSGraphic]()
        var toRemove = [AGSGraphic]()
        var newClusters = Set<ClusterGraphic>()
        
        var set = Set<AGSGraphic>(graphics)
        let drawnGraphics = Set<AGSGraphic>(graphicsOverlay.graphics as NSArray as! [AGSGraphic])
        
        while !set.isEmpty {
            let graphic = set.removeFirst()
            var cluster = [AGSGraphic]()
            for next in set {
                if graphic.collidesWith(graphic: next, inMapView: mapView, tolerance: symbolSize * 2) {
                    set.remove(next)
                    cluster.append(next)
                }
            }
            
            if cluster.isEmpty {
                if !drawnGraphics.contains(graphic) {
                    toAdd.append(graphic)
                }
            } else {
                cluster.append(graphic)
                
                for next in cluster {
                    if drawnGraphics.contains(next) {
                        toRemove.append(next)
                    }
                }
                newClusters.insert(ClusterGraphic(graphics: cluster, symbolSize: symbolSize + 2))
            }
        }
        
        // figure out which clusters are equivalent to clusters already on the map and
        // preserve those to avoid flashing
        //
        var clustersToRemove = Set<ClusterGraphic>()
        for cluster in clusters {
            var found = false
            for newCluster in newClusters {
                if cluster.isEqualTo(newCluster) {
                    newClusters.remove(newCluster)
                    found = true
                    break
                }
            }
            if !found {
                clustersToRemove.insert(cluster)
            }
        }
        
        
        toAdd.append(contentsOf: newClusters as Set<AGSGraphic>)
        toRemove.append(contentsOf: clustersToRemove as Set<AGSGraphic>)

        graphicsOverlay.graphics.removeObjects(in: toRemove)
        graphicsOverlay.graphics.addObjects(from: toAdd)
        
        clusters = clusters.subtracting(clustersToRemove).union(newClusters)
    }
    
    
    func removeAllClusters() {
        var toAdd = [AGSGraphic]()
        let clusters = graphicsOverlay.graphics.filter( { $0 is ClusterGraphic } ) as! [ClusterGraphic]
        clusters.forEach { cluster in
            cluster.graphics.forEach { toAdd.append($0) }
        }
        graphicsOverlay.graphics.removeObjects(in: clusters)
        graphicsOverlay.graphics.addObjects(from: toAdd)
    }

    // returns the graphic on the map for the specified graphic
    //
    func mapGraphicForGraphic(_ graphic: AGSGraphic) -> AGSGraphic {
        for cluster in clusters {
            if cluster.graphics.contains(graphic) {
                return cluster
            }
        }
        return graphic
    }
}

class ClusterGraphic: AGSGraphic {
    var graphics: Set<AGSGraphic>
    
    init(graphics: [AGSGraphic], symbolSize: CGFloat) {
        self.graphics = Set(graphics)
        
        var sumX: Double = 0
        var sumY: Double = 0

        for graphic in graphics {
            let point = graphic.geometry as! AGSPoint
            sumX += point.x
            sumY += point.y
        }
        let point = AGSPoint(x: sumX / Double(graphics.count), y: sumY / Double(graphics.count), spatialReference: graphics[0].geometry!.spatialReference!)
        let outer = AGSSimpleMarkerSymbol(style: .circle, color: UIColor(r: 248, g: 148, b: 63), size: symbolSize)
        let inner = AGSTextSymbol(text: "\(graphics.count)", color: UIColor.white, size: symbolSize / 2, horizontalAlignment: .center, verticalAlignment: .middle)
        
        super.init(geometry: point, symbol: AGSCompositeSymbol(symbols: [outer, inner]), attributes: nil)
    }
    
    func isEqualTo(_ other: ClusterGraphic) -> Bool {
        if graphics.count != other.graphics.count {
            return false
        }
        
        for graphic in graphics {
            if !other.graphics.contains(graphic) {
                return false
            }
        }
        
        return true
    }
}

extension AGSGraphic {
    func collidesWith(graphic: AGSGraphic, inMapView mapView: AGSMapView, tolerance: CGFloat) -> Bool {
        guard let point1 = geometry as? AGSPoint, let point2 = graphic.geometry as? AGSPoint else {
            return false
        }
        
        let p1 = mapView.location(toScreen: point1)
        let p2 = mapView.location(toScreen: point2)
        
        let distance = sqrt(((p2.x - p1.x) * (p2.x - p1.x)) + ((p2.y - p1.y) * (p2.y - p1.y)))
        
        return distance < tolerance
    }
}


