// swift-tools-version:5.9
//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of ResourceGenerator
//
// Copyright (c) 2024 PIXO
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import Foundation
import PathKit
import Stencil
import StencilSwiftKit
import Yams

@main
struct ResourceGeneratorTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resource-generator",
        abstract: "iOS 프로젝트의 리소스 코드를 자동으로 생성하는 도구입니다.",
        subcommands: [
            AssetsCommand.self,
            StringsCommand.self,
            GenerateCommand.self
        ]
    )
}

// MARK: - Config Based Command
struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "설정 파일을 기반으로 리소스 코드를 생성합니다."
    )
    
    @Argument(help: "설정 파일 경로입니다.")
    var configPath: String
    
    func run() throws {
        let configURL = URL(fileURLWithPath: configPath)
        let configString = try String(contentsOf: configURL, encoding: .utf8)
        let config = try YAMLDecoder().decode(Config.self, from: configString)
        
        // XCAssets 생성
        if let xcassets = config.xcassets {
            for input in xcassets.inputs {
                for output in xcassets.outputs {
                    try generateAssets(input: input, output: output)
                }
            }
        }
        
        // Strings 생성
        if let strings = config.strings {
            for input in strings.inputs {
                for output in strings.outputs {
                    try generateStrings(input: input, output: output)
                }
            }
        }
    }
    
    private func generateAssets(input: String, output: OutputConfig) throws {
        var command = AssetsCommand()
        command.path = input
        command.output = output.output
        command.templatePath = output.templatePath
        try command.run()
    }
    
    private func generateStrings(input: String, output: OutputConfig) throws {
        var command = StringsCommand()
        command.path = input
        command.output = output.output
        command.templatePath = output.templatePath
        try command.run()
    }
}

// MARK: - Assets Command
struct AssetsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assets",
        abstract: "지정된 경로의 xcassets 파일을 분석하여 Swift 코드를 생성합니다."
    )
    
    @Argument(help: "xcassets 파일이 위치한 경로입니다.")
    var path: String
    
    @Option(name: .shortAndLong, help: "생성된 코드가 저장될 경로입니다.")
    var output: String = "Generated+Assets.swift"
    
    @Option(name: .long, help: "사용자 정의 템플릿 파일의 경로입니다.")
    var templatePath: String?
    
    func run() throws {
        let inputPath = Path(path)
        let outputPath = Path(output)
        
        let url = URL(fileURLWithPath: inputPath.string)
        let catalog = try AssetCatalog.parse(url: url)
        
        // Load template
        let templateString: String
        if let customTemplatePath = templatePath {
            let templateURL = URL(fileURLWithPath: customTemplatePath)
            templateString = try String(contentsOf: templateURL)
        } else {
            let templatePath = Path(Bundle.module.path(forResource: "Assets", ofType: "stencil", inDirectory: "Templates")!)
            templateString = try String(contentsOf: templatePath.url)
        }
        
        // StencilSwiftKit 환경 설정
        let ext = Extension()
        ext.registerStencilSwiftExtensions()
        
        let environment = Environment(loader: FileSystemLoader(paths: []), extensions: [ext], templateClass: StencilSwiftTemplate.self)
        
        // Context 생성
        let context: [String: Any] = [
            "colors": catalog.root.colors.map { ["name": $0.name] },
            "images": catalog.root.images.map { ["name": $0.name] },
            "dataAssets": catalog.root.dataAssets.map { ["name": $0.name] }
        ]
        
        // 템플릿 렌더링
        let template = try environment.renderTemplate(string: templateString, context: context)
        
        // Write generated code
        try template.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
        
        print("에셋 분석이 완료되었습니다.")
        print("- 이미지: \(catalog.root.images.count)개")
        print("- 색상: \(catalog.root.colors.count)개")
        print("- 데이터: \(catalog.root.dataAssets.count)개")
        print("\n생성된 코드가 저장되었습니다: \(outputPath)")
    }
}

// MARK: - Strings Command
struct StringsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "strings",
        abstract: "지정된 경로의 Localizable.strings 또는 xcstrings 파일을 분석하여 Swift 코드를 생성합니다."
    )
    
    @Argument(help: "strings 파일이 위치한 경로입니다.")
    var path: String
    
    @Option(name: .shortAndLong, help: "생성된 코드가 저장될 경로입니다.")
    var output: String = "Generated+Strings.swift"
    
    @Option(name: .long, help: "사용자 정의 템플릿 파일의 경로입니다.")
    var templatePath: String?
    
    func run() throws {
        let inputPath = Path(path)
        let outputPath = Path(output)
        
        let url = URL(fileURLWithPath: inputPath.string)
        let catalogs = try StringsCatalog.parseDirectory(url: url)
        
        guard !catalogs.isEmpty else {
            throw ValidationError("strings 파일을 찾을 수 없습니다: \(path)")
        }
        
        // 중복 제거를 위해 Dictionary 사용
        var uniqueEntries: [String: StringsEntry] = [:]
        for catalog in catalogs {
            for entry in catalog.entries {
                // Base 로케일이 있으면 Base를 우선적으로 사용
                if entry.locale.isBase {
                    uniqueEntries[entry.key] = entry
                } else if uniqueEntries[entry.key] == nil {
                    uniqueEntries[entry.key] = entry
                }
            }
        }
        
        // Load template
        let templateString: String
        if let customTemplatePath = templatePath {
            let templateURL = URL(fileURLWithPath: customTemplatePath)
            templateString = try String(contentsOf: templateURL)
        } else {
            let templatePath = Path(Bundle.module.path(forResource: "Strings", ofType: "stencil", inDirectory: "Templates")!)
            templateString = try String(contentsOf: templatePath.url)
        }
        
        // StencilSwiftKit 환경 설정
        let ext = Extension()
        ext.registerStencilSwiftExtensions()
        
        let environment = Environment(loader: FileSystemLoader(paths: []), extensions: [ext], templateClass: StencilSwiftTemplate.self)
        
        // Context 생성
        let context: [String: Any] = [
            "filename": catalogs[0].filename,
            "entries": uniqueEntries.values.map { ["key": $0.key] }
        ]
        
        // 템플릿 렌더링
        let template = try environment.renderTemplate(string: templateString, context: context)
        
        // Write generated code
        try template.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
        
        print("Strings 파일 분석이 완료되었습니다.")
        print("- 문자열: \(uniqueEntries.count)개")
        print("\n생성된 코드가 저장되었습니다: \(outputPath)")
    }
} 