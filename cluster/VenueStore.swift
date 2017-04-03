//
//  VenueStore.swift
//  cluster
//
//  Created by Jeff Jackson on 12/28/16.
//  Copyright © 2016 Esri. All rights reserved.
//

import Foundation

import ArcGIS

class VenueStore {
    
    static var shared = VenueStore()
    
    var venues: [Venue] = []
    
    private let locatorTask = AGSLocatorTask(url: URL(string: "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")!)
    
    private init() {
        
    }
    
    func loadVenues(location: AGSPoint, spatialReference: AGSSpatialReference, completed: @escaping () -> Void) {
        
        locatorTask.load() { error in
            let params = AGSGeocodeParameters()
            params.maxResults = 100
            params.preferredSearchLocation = location
            params.outputSpatialReference = spatialReference
            params.resultAttributeNames = ["*"]
            self.locatorTask.geocode(withSearchText: "coffee", parameters: params) { results, error in
                if let results = results {
                    self.venues = results.map { Venue(location: $0.displayLocation!, name: $0.attributes!["PlaceName"] as! String) }
                }
                completed()
            }
        }
    }
}

class Venue: NSObject {
    
    let location: AGSPoint
    let id: String
    let name: String
    
    init(location: AGSPoint, name: String) {
        self.location = location
        self.id = UUID().uuidString
        self.name = name
    }
}
