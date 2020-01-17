//
//  SPMPlaygroundCommand.swift
//  
//
//  Created by Sven A. Schmidt on 23/12/2019.
//

import Foundation
import Path
import ShellOut
import Yaap


public enum SPMPlaygroundError: LocalizedError {
    case invalidPath(String)
    case missingDependency
    case pathExists(String)
    case noLibrariesFound

    public var errorDescription: String? {
        switch self {
            case .invalidPath(let path):
                return "'\(path)' is not a valid path"
            case .missingDependency:
                return "provide at least one dependency via the -d parameter"
            case .pathExists(let path):
                return "'\(path)' already exists, use '-f' to overwrite"
            case .noLibrariesFound:
                return "no libraries found, make sure the referenced dependencies define library products"
        }
    }
}


public class SPMPlaygroundCommand {
    public let name = "spm-playground"
    public let documentation = "Creates an Xcode project with a Playground and one or more SPM libraries imported and ready for use."

    // Custom options

    @Option(name: "name", shorthand: "n", documentation: "Name of directory and Xcode project")
    var projectName = "SPM-Playground"

    @Option(name: "deps", shorthand: "d", documentation: "Dependency url(s) and (optionally) version specification")
    var dependencies = [Dependency]()

    @Option(name: "libs", shorthand: "l", documentation: "Names of libraries to import (inferred if not provided)")
    var libNames: [String] = []

    @Option(shorthand: "p", documentation: "Platform for Playground (one of 'macos', 'ios', 'tvos')")
    var platform: Platform = .macos

    @Option(shorthand: "f", documentation: "Overwrite existing file/directory")
    var force = false

    @Option(name: "outputdir", shorthand: "o", documentation: "Directory where project folder should be saved")
    var outputPath = Path.cwd

    // Built-in flags

    let version = Version(SPMPlaygroundVersion)

    let help = Help()

    public init() {}
}


extension SPMPlaygroundCommand: Command {
    public func run(outputStream: inout TextOutputStream, errorStream: inout TextOutputStream) throws {
        try createPlayground(
            projectName: projectName,
            dependencies: dependencies,
            libNames: libNames,
            platform: platform,
            outputPath: outputPath,
            force: force,
            outputStream: &outputStream,
            errorStream: &errorStream
        )
    }
}


public func createPlayground(
    projectName: String = "SPM-Playground",
    dependencies: [Dependency],
    libNames: [String] = [],
    platform: Platform = .macos,
    outputPath: String,
    force: Bool = false,
    outputStream: inout TextOutputStream,
    errorStream: inout TextOutputStream) throws {
    guard let path = Path(outputPath) else {
        throw SPMPlaygroundError.invalidPath(outputPath)
    }
    try createPlayground(
        projectName: projectName,
        dependencies: dependencies,
        libNames: libNames,
        platform: platform,
        outputPath: path,
        force: force,
        outputStream: &outputStream,
        errorStream: &errorStream
    )
}

public func createPlayground(
    projectName: String = "SPM-Playground",
    dependencies: [Dependency],
    libNames: [String] = [],
    platform: Platform = .macos,
    outputPath: Path,
    force: Bool = false,
    outputStream: inout TextOutputStream,
    errorStream: inout TextOutputStream) throws {

    guard !dependencies.isEmpty else {
        throw SPMPlaygroundError.missingDependency
    }

    let projectPath = outputPath/projectName

    if force && projectPath.exists {
        try projectPath.delete()
    }
    guard !projectPath.exists else {
        throw SPMPlaygroundError.pathExists(projectPath.basename())
    }

    // create package
    do {
        try projectPath.mkdir()
        try shellOut(to: .createSwiftPackage(withType: .library), at: projectPath)
    }

    // update Package.swift dependencies
    do {
        let packagePath = projectPath/"Package.swift"
        let packageDescription = try String(contentsOf: packagePath)
        let depsClause = dependencies.map { "    " + $0.packageClause }.joined(separator: ",\n")
        let updatedDeps = "package.dependencies = [\n\(depsClause)\n]"
        try [packageDescription, updatedDeps].joined(separator: "\n").write(to: packagePath)
    }

    do {
        outputStream.write("🔧  resolving package dependencies\n")
        try shellOut(to: ShellOutCommand(string: "swift package resolve"), at: projectPath)
    }

    let libs: [String]
    do {
        // find libraries
        libs = try dependencies
            .compactMap { $0.path ?? $0.checkoutDir(projectDir: projectPath) }
            .flatMap { try libraryNames(for: $0) }
        if libs.isEmpty { throw SPMPlaygroundError.noLibrariesFound }
        outputStream.write("📔  libraries found: \(libs.joined(separator: ", "))\n")
    }

    // update Package.swift targets
    do {
        let packagePath = projectPath/"Package.swift"
        let packageDescription = try String(contentsOf: packagePath)
        let libsClause = libs.map { "\"\($0)\"" }.joined(separator: ", ")
        let updatedTgts =  "package.targets = [.target(name: \"\(projectName)\", dependencies: [\(libsClause)])]"
        try [packageDescription, updatedTgts].joined(separator: "\n").write(to: packagePath)
    }

    // generate xcodeproj
    try shellOut(to: .generateSwiftPackageXcodeProject(), at: projectPath)

    // create workspace
    let xcworkspacePath = projectPath/"\(projectName).xcworkspace"
    do {
        let xcodeprojPath = projectPath/"\(projectName).xcodeproj"
        try xcworkspacePath.mkdir()
        try """
            <?xml version="1.0" encoding="UTF-8"?>
            <Workspace
            version = "1.0">
            <FileRef
            location = "group:MyPlayground.playground">
            </FileRef>
            <FileRef
            location = "container:\(xcodeprojPath.basename())">
            </FileRef>
            </Workspace>
            """.write(to: xcworkspacePath/"contents.xcworkspacedata")
    }

    // add playground
    do {
        let playgroundPath = projectPath/"MyPlayground.playground"
        try playgroundPath.mkdir()
        let libsToImport = !libNames.isEmpty ? libNames : libs
        let importClauses = libsToImport.map { "import \($0)" }.joined(separator: "\n") + "\n"
        try importClauses.write(to: playgroundPath/"Contents.swift")
        try """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <playground version='5.0' target-platform='\(platform)'>
            <timeline fileName='timeline.xctimeline'/>
            </playground>
            """.write(to: playgroundPath/"contents.xcplayground")
    }

    outputStream.write("✅  created project in folder '\(projectPath.relative(to: Path.cwd))'\n")
    try shellOut(to: .openFile(at: xcworkspacePath))
}

