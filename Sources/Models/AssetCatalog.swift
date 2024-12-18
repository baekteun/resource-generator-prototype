import Foundation

public struct AssetCatalog: Sendable {
    public let filename: String
    public let root: Namespace

    public init(filename: String, root: Namespace) {
        self.filename = filename
        self.root = root
    }
}

public struct ColorResource: Sendable {
    public let name: String
    public let path: [String]
    public let bundle: Bundle

    public init(name: String, path: [String], bundle: Bundle) {
        self.name = name
        self.path = path
        self.bundle = bundle
    }
}

public struct ImageResource: Sendable {
    public let name: String
    public let path: [String]
    public let bundle: Bundle
    public let locale: LocaleReference?
    public let onDemandResourceTags: [String]?

    public init(name: String, path: [String], bundle: Bundle, locale: LocaleReference?, onDemandResourceTags: [String]?) {
        self.name = name
        self.path = path
        self.bundle = bundle
        self.locale = locale
        self.onDemandResourceTags = onDemandResourceTags
    }
}

public struct DataResource: Sendable {
    public let name: String
    public let path: [String]
    public let bundle: Bundle
    public let onDemandResourceTags: [String]?

    public init(name: String, path: [String], bundle: Bundle, onDemandResourceTags: [String]?) {
        self.name = name
        self.path = path
        self.bundle = bundle
        self.onDemandResourceTags = onDemandResourceTags
    }
}

extension AssetCatalog {
    public struct Namespace: Sendable {
        public var subnamespaces: [String: Namespace] = [:]
        public var colors: [ColorResource] = []
        public var images: [ImageResource] = []
        public var dataAssets: [DataResource] = []

        public init() {
        }

        public init(
            subnamespaces: [String: Namespace],
            colors: [ColorResource],
            images: [ImageResource],
            dataAssets: [DataResource]
        ) {
            self.subnamespaces = subnamespaces
            self.colors = colors
            self.images = images
            self.dataAssets = dataAssets
        }

        public mutating func merge(_ other: Namespace) {
            self.subnamespaces = self.subnamespaces.merging(other.subnamespaces) { $0.merging($1) }
            self.colors += other.colors
            self.images += other.images
            self.dataAssets += other.dataAssets
        }

        public func merging(_ other: Namespace) -> Namespace {
            var new = self
            new.merge(other)
            return new
        }
    }
}
