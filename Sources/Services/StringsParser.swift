import Foundation
import PathKit

public struct StringsEntry: Sendable {
    public let key: String
    public let value: String
    public let locale: LocaleReference
    public let argumentCount: Int
    
    public init(key: String, value: String, locale: LocaleReference, argumentCount: Int = 0) {
        self.key = key
        self.value = value
        self.locale = locale
        self.argumentCount = argumentCount
    }
}

public struct StringsCatalog: Sendable {
    public let filename: String
    public let entries: [StringsEntry]
    
    public init(filename: String, entries: [StringsEntry]) {
        self.filename = filename
        self.entries = entries
    }
}

extension StringsCatalog {
    static public let supportedExtensions: Set<String> = ["strings", "xcstrings"]
    
    static public func parse(url: URL) throws -> StringsCatalog {
        guard let basename = url.filenameWithoutExtension else {
            throw NSError(domain: "StringsSample", code: 0, userInfo: nil)
        }
        
        if url.pathExtension == "xcstrings" {
            let entries = try parseXCStringsFile(url: url)
            return StringsCatalog(filename: basename, entries: entries)
        } else {
            let entries = try parseStringsFile(url: url)
            return StringsCatalog(filename: basename, entries: entries)
        }
    }
    
    static private func parseStringsFile(url: URL) throws -> [StringsEntry] {
        let locale = LocaleReference(url: url)
        let contents = try String(contentsOf: url, encoding: .utf8)
        var entries: [StringsEntry] = []
        
        // 정규식을 사용하여 key-value 쌍을 추출
        let pattern = #""([^"]+)"\s*=\s*"([^"]+)"\s*;"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(contents.startIndex..., in: contents)
        
        regex.enumerateMatches(in: contents, range: range) { match, _, _ in
            guard let match = match else { return }
            
            let keyRange = Range(match.range(at: 1), in: contents)!
            let valueRange = Range(match.range(at: 2), in: contents)!
            
            let key = String(contents[keyRange])
            let value = String(contents[valueRange])
            
            let argumentCount = countArguments(in: value)
            entries.append(StringsEntry(key: key, value: value, locale: locale, argumentCount: argumentCount))
        }
        
        return entries
    }
    
    static private func parseXCStringsFile(url: URL) throws -> [StringsEntry] {
        let locale = LocaleReference(url: url)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let xcstrings = try decoder.decode(XCStringsFile.self, from: data)
        
        var entries: [StringsEntry] = []
        for (key, stringEntry) in xcstrings.strings {
            // localizations이 없는 경우 빈 문자열로 처리
            if stringEntry.localizations == nil {
                entries.append(StringsEntry(key: key, value: "", locale: locale))
                continue
            }
            
            // 기본 값 또는 plural의 'other' 값을 사용
            if let value = stringEntry.value {
                let argumentCount = countArguments(in: value)
                entries.append(StringsEntry(key: key, value: value, locale: locale, argumentCount: argumentCount))
            }
            
            // Plural 변형이 있는 경우 각각의 변형에 대한 키를 생성
            if let plural = stringEntry.localizations?.values.first?.variations?.plural {
                if let zero = plural.zero?.stringUnit.value {
                    let argumentCount = countArguments(in: zero)
                    entries.append(StringsEntry(key: "\(key)_zero", value: zero, locale: locale, argumentCount: argumentCount))
                }
                if let one = plural.one?.stringUnit.value {
                    let argumentCount = countArguments(in: one)
                    entries.append(StringsEntry(key: "\(key)_one", value: one, locale: locale, argumentCount: argumentCount))
                }
                if let two = plural.two?.stringUnit.value {
                    let argumentCount = countArguments(in: two)
                    entries.append(StringsEntry(key: "\(key)_two", value: two, locale: locale, argumentCount: argumentCount))
                }
                if let few = plural.few?.stringUnit.value {
                    let argumentCount = countArguments(in: few)
                    entries.append(StringsEntry(key: "\(key)_few", value: few, locale: locale, argumentCount: argumentCount))
                }
                if let many = plural.many?.stringUnit.value {
                    let argumentCount = countArguments(in: many)
                    entries.append(StringsEntry(key: "\(key)_many", value: many, locale: locale, argumentCount: argumentCount))
                }
            }
        }
        
        return entries
    }
    
    static private func countArguments(in value: String) -> Int {
        // %@ 또는 %d와 같은 포맷 지정자를 찾습니다
        let pattern = "%[@dDuUxXoOfeEgGcCsSPpaA]"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex.numberOfMatches(in: value, range: range)
    }
    
    static public func parseDirectory(url: URL) throws -> [StringsCatalog] {
        let fileManager = FileManager.default
        var catalogs: [StringsCatalog] = []
        
        if supportedExtensions.contains(url.pathExtension) {
            let catalog = try parse(url: url)
            catalogs.append(catalog)
            return catalogs
        }
        
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            if supportedExtensions.contains(fileURL.pathExtension) {
                let catalog = try parse(url: fileURL)
                catalogs.append(catalog)
            }
        }
        
        return catalogs
    }
}

// MARK: - XCStrings Models
private struct XCStringsFile: Codable {
    let sourceLanguage: String
    let strings: [String: StringEntry]
    let version: String
}

private struct StringEntry: Codable {
    let extractedComment: String?
    let comment: String?
    let extractionState: String?
    let localizations: [String: Localization]?
    
    var value: String? {
        guard let localizations = localizations,
              let firstLocalization = localizations.values.first else { return nil }
        if let pluralValue = firstLocalization.variations?.plural?.other?.stringUnit.value {
            return pluralValue
        }
        return firstLocalization.stringUnit?.value
    }
}

private struct Localization: Codable {
    let stringUnit: StringUnit?
    let variations: Variations?
}

private struct StringUnit: Codable {
    let value: String
    let state: String?
}

private struct Variations: Codable {
    let plural: PluralVariation?
}

private struct PluralVariation: Codable {
    let zero: StringUnitContainer?
    let one: StringUnitContainer?
    let two: StringUnitContainer?
    let few: StringUnitContainer?
    let many: StringUnitContainer?
    let other: StringUnitContainer?
}

private struct StringUnitContainer: Codable {
    let stringUnit: StringUnit
} 