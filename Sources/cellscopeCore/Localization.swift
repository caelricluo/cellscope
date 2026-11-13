import Foundation

/// Shared localization for SwiftUI, UIKit annotations, status messages and exports.
public func tr(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
public func trf(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: tr(key), locale: Locale.current, arguments: arguments)
}
