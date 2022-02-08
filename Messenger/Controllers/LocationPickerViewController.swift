//
//  LocationPickerViewController.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 08.02.2022.
//

import UIKit
import CoreLocation
import MapKit

class LocationPickerViewController: UIViewController {
    
    public var complition: ((CLLocationCoordinate2D) -> Void)?
    private var coordinates: CLLocationCoordinate2D?
    private var isPickable = true
    
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D?) {
        self.coordinates = coordinates
        self.isPickable = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self,
                                                 action: #selector(didTapMap))
            gesture.numberOfTouchesRequired = 1
            gesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            // just showing location
            guard let coordinates = self.coordinates else {
                return
            }
            
            // drop a pin on that location
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
            
            let span = map.region.span
            let region = MKCoordinateRegion(center: coordinates, span: span)
            map.setRegion(region, animated: true)
            let zoomRange = MKMapView.CameraZoomRange(maxCenterCoordinateDistance: 10000)
            map.setCameraZoomRange(zoomRange, animated: true)
        }
        view.addSubview(map)
    }
    
    @objc func sendButtonTapped() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        complition?(coordinates)
    }
    
    @objc func didTapMap(_ gesture: UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinates
        
        for anotation in map.annotations {
            map.removeAnnotation(anotation)
        }
        
        // drop a pin on that location
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
}
