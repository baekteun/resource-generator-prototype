import Foundation

struct Config: Codable {
    let strings: ResourceConfig?
    let xcassets: ResourceConfig?
    let fonts: ResourceConfig?
}

struct ResourceConfig: Codable {
    let inputs: [String]
    let outputs: [OutputConfig]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // inputs can be either a single string or an array of strings
        if let singleInput = try? container.decode(String.self, forKey: .inputs) {
            self.inputs = [singleInput]
        } else {
            self.inputs = try container.decode([String].self, forKey: .inputs)
        }
        
        self.outputs = try container.decode([OutputConfig].self, forKey: .outputs)
    }
}

struct OutputConfig: Codable {
    let templateName: String
    let output: String
    let templatePath: String?
}