import Foundation

internal extension URL {
    var filenameWithoutExtension: String? {
        let name = self.deletingPathExtension().lastPathComponent
        return name == "" ? nil : name
    }
}
