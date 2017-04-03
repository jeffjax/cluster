//
//  ViewController.swift
//  cluster
//
//  Created by Jeff Jackson on 12/28/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import ArcGIS

class MainViewController: UIViewController, UIGestureRecognizerDelegate, AGSGeoViewTouchDelegate {

    @IBOutlet weak var mapView: AGSMapView!
    let symbolSize: CGFloat = 24
    let clusteringManager = GraphicsClusteringManager()
    
    var currentVenue: Venue? {
        didSet {
            clusteringManager.graphicsOverlay.clearSelection()

            guard let currentVenue = currentVenue else {
                return
            }
            

            if let graphic = graphicForVenue(currentVenue) {
                let mapGraphic = clusteringManager.mapGraphicForGraphic(graphic)
                mapGraphic.isSelected = true

                let viewPoint = AGSViewpoint.forLocation(center: mapGraphic.geometry as! AGSPoint, mapView: mapView, topOffset: 20, bottomOffset: view.frame.height / 2)
                mapView.setViewpoint(viewPoint, duration: 0.2)
                
                mapView.callout.title = currentVenue.name
                mapView.callout.accessoryButtonType = .custom
                mapView.callout.show(for: mapGraphic, tapLocation: mapGraphic.geometry as! AGSPoint, animated: true)
            }

        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.backgroundGrid = AGSBackgroundGrid(color: mapView.backgroundColor!, gridLineColor: UIColor.lightGray.withAlphaComponent(0.5), gridLineWidth: 0.1, gridSize: 100)
        mapView.graphicsOverlays.add(clusteringManager.graphicsOverlay)
        mapView.touchDelegate = self
        mapView.interactionOptions.isMagnifierEnabled = false
        mapView.interactionOptions.isRotateEnabled = false
        
        let vectorTiledLayer = AGSArcGISVectorTiledLayer(url: URL(string: "http://www.arcgis.com/sharing/rest/content/items/e19e9330bf08490ca8353d76b5e2e658")!)
        
        let map = AGSMap(basemap: AGSBasemap(baseLayer: vectorTiledLayer))
        let location = AGSPoint(x: -70.2558333, y: 43.6613889, spatialReference: AGSSpatialReference.wgs84())
        map.initialViewpoint = AGSViewpoint(latitude: location.y, longitude: location.x, scale: 30000)
        
        mapView.map = map
        
        mapView.addObserver(self, forKeyPath: "mapScale", options: [], context: nil)
        
        map.load { error in
            VenueStore.shared.loadVenues(location: location, spatialReference: map.spatialReference!) {
                self.updateVenues()
            }
        }
    }

    func updateVenues() {
        
        let venues = VenueStore.shared.venues
        
        clusteringManager.graphics = venues.map { venue -> AGSGraphic in
            let point = venue.location
            let outer = AGSSimpleMarkerSymbol(style: .circle, color: UIColor.white, size: symbolSize)
            let inner = AGSSimpleMarkerSymbol(style: .circle, color: UIColor(r: 248, g: 148, b: 63), size: symbolSize - 5)
            let graphic = AGSGraphic(geometry: point, symbol: AGSCompositeSymbol(symbols: [outer, inner]), attributes: ["id": venue.id])
            
            return graphic
        }
        
        clusteringManager.clusterGraphics(mapView: mapView, symbolSize: symbolSize)
        if let currentVenue = currentVenue, let graphic = graphicForVenue(currentVenue) {
            clusteringManager.mapGraphicForGraphic(graphic).isSelected = true
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        clusteringManager.clusterGraphics(mapView: mapView, symbolSize: symbolSize)
        if let currentVenue = currentVenue, let graphic = graphicForVenue(currentVenue) {
            clusteringManager.mapGraphicForGraphic(graphic).isSelected = true
        }
    }


    func venueForGraphic(_ graphic: AGSGraphic) -> Venue? {
        guard let id = graphic.attributes["id"] as? String else {
            return nil
        }
        
        for venue in VenueStore.shared.venues {
            if venue.id == id {
                return venue
            }
        }
        return nil
    }
    
    func graphicForVenue(_ venue: Venue) -> AGSGraphic? {
        for graphic in clusteringManager.graphics {
            if graphic.attributes["id"] as? String == venue.id {
                return graphic
            }
        }
        
        return nil
    }


    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        mapView.identify(clusteringManager.graphicsOverlay, screenPoint: screenPoint, tolerance: 10, returnPopupsOnly: false) { result in
            
            guard let graphic = result.graphics.first else {
                self.clusteringManager.graphicsOverlay.clearSelection()
                self.mapView.callout.dismiss()
                return
            }
            
            if let cluster = graphic as? ClusterGraphic {
                self.zoomToCluster(cluster)
            } else if let venue = self.venueForGraphic(graphic) {
                self.currentVenue = venue
            }
        }
    }
    
    func zoomToCluster(_ cluster: ClusterGraphic) {
        var union  = cluster.graphics.first!.geometry!
        for graphic in cluster.graphics {
            union = AGSGeometryEngine.union(ofGeometry1: union, geometry2: graphic.geometry!)!
        }
        
        mapView.zoom(to: union.extent, insets: UIEdgeInsets.init(top: 50, left: 50, bottom: 50, right: 50))
    }
}
