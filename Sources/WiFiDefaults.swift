import CoreLocation
import CoreWLAN
import Foundation

final class WiFiDefaults {
    private let locationManager = CLLocationManager()

    var canReadNetworkName: Bool {
        locationManager.authorizationStatus == .authorizedAlways
    }

    var permissionDenied: Bool {
        [.denied, .restricted].contains(locationManager.authorizationStatus)
    }

    var currentNetwork: String? {
        canReadNetworkName ? CWWiFiClient.shared().interface()?.ssid() : nil
    }

    var saved: [String: Bool] {
        get { UserDefaults.standard.dictionary(forKey: "wifiDefaults") as? [String: Bool] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "wifiDefaults") }
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
}
