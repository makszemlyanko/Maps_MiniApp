//
//  DirectionsSearchView.swift
//  MapsDirectionsGooglePlaces_LBTA
//
//  Created by Maks Kokos on 30.08.2022.
//

import SwiftUI
import MapKit
import Combine

struct DirectionsMapView: UIViewRepresentable {
    
    typealias UIViewType = MKMapView
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    let mapView = MKMapView()
    
    class Coordinator: NSObject, MKMapViewDelegate {
        
        init(mapView: MKMapView) {
            super.init()
            mapView.delegate = self
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .red
            renderer.lineWidth = 5
            return renderer
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(mapView: mapView)
    }
    
    
    func makeUIView(context: Context) -> MKMapView {
        mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)
        
        [env.sourceMapItem, env.destinationMapItem].compactMap({$0}).forEach { (mapItem) in
            let annotation = MKPointAnnotation()
            annotation.title = mapItem.name
            annotation.coordinate = mapItem.placemark.coordinate
            uiView.addAnnotation(annotation)
        }
        
        uiView.showAnnotations(uiView.annotations, animated: false)
        
        if let route = env.route {
            uiView.addOverlay(route.polyline)
        }
    }
}

struct SelectLocationView: View {
    
//    @Binding var isShowing: Bool
    
    @State var mapItems = [MKMapItem]()
    
    @State var searchQuery = ""
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Button(action: {
                    self.env.isSelectingSource = false
                    self.env.isSelectingDestination = false // transition to previous screen
                }, label: {
                    Image(uiImage: #imageLiteral(resourceName: "back_arrow"))
                })
                
                TextField("Enter search term", text: self.$searchQuery)
                    .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification).debounce(for: .milliseconds(500), scheduler: RunLoop.main), perform: { _ in
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = self.searchQuery
                        let search = MKLocalSearch(request: request)
                        search.start { (response, error) in
                            if let error = error {
                                print("Failed to local search: ", error)
                                return
                            }
                            self.mapItems = response?.mapItems ?? []
                        }
                    })
            }
            .padding()
     
            if mapItems.count > 0 {
                ScrollView {
                    ForEach(mapItems, id: \.self) { item in
                        Button(action: {
                            if self.env.isSelectingSource {
                                self.env.isSelectingSource = false
                                self.env.sourceMapItem = item
                            } else {
                                self.env.isSelectingDestination = false
                                self.env.destinationMapItem = item
                            }
                        }, label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(item.name ?? "")")
                                        .font(.headline)
                                    Text("\(item.adress())")
                                }
                                .padding()
                                Spacer()
                            }
                        })
                        .foregroundColor(.black)
                        Divider()
                    }
                }
            }
            Spacer()
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarHidden(true)
    }
}

struct DirectionsSearchView: View {
    
    @EnvironmentObject var env: DirectionsEnvironment
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                VStack(spacing: -4) {
                    VStack {
                        
                        HStack(spacing: 16) {
                            Image(uiImage: #imageLiteral(resourceName: "start_location_circles")).frame(width: 24, height: 24)
                            NavigationLink(
                                destination: SelectLocationView(),
                                isActive: $env.isSelectingSource,
                                label: {
                                    HStack {
                                        Text(env.sourceMapItem != nil ? (env.sourceMapItem?.name ?? "") : "Source" )
                                        Spacer()
                                    }.padding()
                                    .background(Color.white)
                                    .cornerRadius(3)
                                })
                        }
                        
                        HStack(spacing: 16) {
                            Image(uiImage: #imageLiteral(resourceName: "annotation_icon")
                                    .withRenderingMode(.alwaysTemplate))
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                            NavigationLink(
                                destination: SelectLocationView(),
                                isActive: $env.isSelectingDestination,
                                label: {
                                    HStack {
                                        Text(env.destinationMapItem != nil ? (env.destinationMapItem?.name ?? "") : "Destination")
                                        Spacer()
                                    }.padding()
                                    .background(Color.white)
                                    .cornerRadius(3)
                                })
                        }
                        
                    }.padding()
                    .background(Color.blue)
                    
                    Spacer()
                    DirectionsMapView().edgesIgnoringSafeArea(.bottom)
                }
                
                // status bar cover
                Spacer().frame(width: UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.window?.frame.width,
                               height: UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.safeAreaInsets.top)
                    .background(Color.blue)
                    .edgesIgnoringSafeArea(.top)
            }
            .navigationBarTitle("Search")
            .navigationBarHidden(true)
        }
    }
}

class DirectionsEnvironment: ObservableObject {
    
    @Published var isSelectingSource = false
    @Published var isSelectingDestination = false
    
    @Published var sourceMapItem: MKMapItem?
    @Published var destinationMapItem: MKMapItem?
    
    @Published var route: MKRoute?
    
    var cancellable: AnyCancellable?
    
    init() {
        // lesten for changes of this items
        cancellable = Publishers.CombineLatest($sourceMapItem, $destinationMapItem).sink { (items) in
            
            // searching for directions
            let request = MKDirections.Request()
            request.source = items.0
            request.destination = items.1
            let directions = MKDirections(request: request)
            directions.calculate { [weak self] (response, error) in
                if let error = error {
                    print("Failed to calculate route: ", error)
                    return
                }
                self?.route = response?.routes.first
            }
        }
    }
}

struct DirectionsSearchView_Previews: PreviewProvider {
    
    static var env = DirectionsEnvironment()
    
    static var previews: some View {
        DirectionsSearchView().environmentObject(env)
    }
}
