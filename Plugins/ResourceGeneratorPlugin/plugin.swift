//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of ResourceGenerator
//
// Copyright (c) 2024 PIXO
//
//===----------------------------------------------------------------------===//

import PackagePlugin
import Foundation

@main
struct ResourceGeneratorPlugin: CommandPlugin {
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        // 리소스 생성기 도구 찾기
        let generationToolFile = try context.tool(named: "resource-generator").path
        
        // 인자 추출기 생성
        var extractor = ArgumentExtractor(arguments)
        
        // 도움말 요청 시 실행
        if extractor.helpRequest() {
            try generationToolFile.exec(arguments: ["--help"])
            print("""
                추가 옵션:
                  --configuration <configuration>
                                      도구 빌드 설정을 지정합니다. (기본값: release)
                
                참고: "ResourceGeneratorPlugin"은 "<config-path>"와 "--output <output-path>" 인자를 자동으로 처리합니다.
                이러한 인자를 수동으로 제공하면 런타임 오류가 발생할 수 있습니다.
                """)
            return
        }
        
        // 설정 인자 추출
        let configuration = try extractor.configuration()
        
        // 모든 제품 빌드
        print("\(configuration) 모드로 패키지를 빌드하는 중...")
        let buildResult = try packageManager.build(
            .all(includingTests: false),
            parameters: .init(configuration: configuration))
        
        guard buildResult.succeeded else {
            throw ResourceGeneratorPluginError.buildFailed(buildResult.logText)
        }
        print("\(configuration) 모드로 패키지 빌드 완료")
        
        // 모든 실행 가능한 아티팩트에 대해 리소스 생성 실행
        for builtArtifact in buildResult.builtArtifacts {
            // 실행 파일이 아닌 대상 건너뛰기
            guard builtArtifact.kind == .executable else { continue }
            
            // 매칭되는 제품이 없는 실행 파일 건너뛰기
            guard let product = builtArtifact.matchingProduct(context: context)
            else { continue }
            
            // ResourceGenerator에 의존성이 없는 제품 건너뛰기
            guard product.hasDependency(named: "ResourceGenerator") else { continue }
            
            // 아티팩트 이름 가져오기
            let executableName = builtArtifact.path.lastComponent
            print("\(executableName)의 리소스를 생성하는 중...")
            
            // 출력 디렉토리 생성
            let outputDirectory = context
                .pluginWorkDirectory
                .appending(executableName)
            try outputDirectory.createOutputDirectory()
            
            // 생성 도구 인자 생성
            var generationToolArguments = [
                "generate",
                builtArtifact.path.string,
                "--output",
                outputDirectory.string
            ]
            generationToolArguments.append(
                contentsOf: extractor.remainingArguments)
            
            // 생성 도구 실행
            try generationToolFile.exec(arguments: generationToolArguments)
            print("'\(outputDirectory)'에 리소스 생성 완료")
        }
    }
}

// MARK: - Errors
enum ResourceGeneratorPluginError: Error, CustomStringConvertible {
    case buildFailed(String)
    case unknownBuildConfiguration(String)
    case createOutputDirectoryFailed(Error)
    case subprocessFailedError(Path, Error)
    case subprocessFailedNonZeroExit(Path, Int32)
    
    var description: String {
        switch self {
        case .buildFailed(let log):
            return "빌드 실패: \(log)"
        case .unknownBuildConfiguration(let config):
            return "알 수 없는 빌드 설정: \(config)"
        case .createOutputDirectoryFailed(let error):
            return "출력 디렉토리 생성 실패: \(error.localizedDescription)"
        case .subprocessFailedError(let path, let error):
            return "\(path) 실행 실패: \(error.localizedDescription)"
        case .subprocessFailedNonZeroExit(let path, let status):
            return "\(path) 실행이 종료 코드 \(status)로 실패"
        }
    }
}

// MARK: - Extensions
extension ArgumentExtractor {
    mutating func helpRequest() -> Bool {
        self.extractFlag(named: "help") > 0
    }
    
    mutating func configuration() throws -> PackageManager.BuildConfiguration {
        switch self.extractOption(named: "configuration").first {
        case .some(let configurationString):
            switch configurationString {
            case "debug":
                return .debug
            case "release":
                return .release
            default:
                throw ResourceGeneratorPluginError
                    .unknownBuildConfiguration(configurationString)
            }
        case .none:
            return .release
        }
    }
}

extension Path {
    func createOutputDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                atPath: self.string,
                withIntermediateDirectories: true)
        } catch {
            throw ResourceGeneratorPluginError.createOutputDirectoryFailed(error)
        }
    }
    
    func exec(arguments: [String]) throws {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.string)
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard
                process.terminationReason == .exit,
                process.terminationStatus == 0
            else {
                throw ResourceGeneratorPluginError.subprocessFailedNonZeroExit(
                    self, process.terminationStatus)
            }
        } catch {
            throw ResourceGeneratorPluginError.subprocessFailedError(self, error)
        }
    }
}

extension PackageManager.BuildResult.BuiltArtifact {
    func matchingProduct(context: PluginContext) -> Product? {
        context
            .package
            .products
            .first { $0.name == self.path.lastComponent }
    }
}

extension Product {
    func hasDependency(named name: String) -> Bool {
        recursiveTargetDependencies
            .contains { $0.name == name }
    }
    
    var recursiveTargetDependencies: [Target] {
        var dependencies = [Target.ID: Target]()
        for target in self.targets {
            for dependency in target.recursiveTargetDependencies {
                dependencies[dependency.id] = dependency
            }
        }
        return Array(dependencies.values)
    }
} 