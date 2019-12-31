@testable import SPMPlayground
import Path
import Workspace
import XCTest


final class SPMPlaygroundTests: XCTestCase {
    func test_loadManifest() throws {
        let p = checkoutsDirectory/"swift-package-manager"
        print(p)
        let package = AbsolutePath(p.string)
        let manifest = try ManifestLoader.loadManifest(packagePath: package, swiftCompiler: swiftCompiler)
        XCTAssertEqual(manifest.name, "SwiftPM")
        XCTAssertEqual(manifest.products.map { $0.name }, ["SwiftPM", "SwiftPM-auto", "SPMUtility"])
        XCTAssertEqual(manifest.products.map { $0.type }, [.library(.dynamic), .library(.automatic), .library(.automatic)])
    }

    func test_libraryNames() throws {
        let package = checkoutsDirectory/"swift-package-manager"
        XCTAssertEqual(try libraryNames(for: package), ["SwiftPM", "SwiftPM-auto", "SPMUtility"])
    }

    func test_parse_multiple_deps() throws {
        do {
            var args = ["-d", "https://github.com/mxcl/Path.swift.git==1.2.3", "https://github.com/hartbit/Yaap.git>=1.0.0"]
            let cmd = SPMPlaygroundCommand()
            let res = try cmd.parse(arguments: &args)
            XCTAssert(res)
            XCTAssertEqual(cmd.dependencies, [
                Dependency(url: URL(string: "https://github.com/mxcl/Path.swift.git")!, requirement: .exact("1.2.3")),
                Dependency(url: URL(string: "https://github.com/hartbit/Yaap.git")!, requirement: .range("1.0.0"..<"2.0.0"))
            ])
        }
    }

    func test_parse_version() throws {
        XCTAssertEqual(Parser.version.run("1.2.3"), Match(result: Version(1, 2, 3), rest: ""))
        XCTAssertEqual(Parser.version.run("1.2.3="), Match(result: Version(1, 2, 3), rest: "="))
    }

    func test_parse_requirement() throws {
        XCTAssertEqual(Parser.exact.run("==1.2.3"), Match(result: .exact("1.2.3"), rest: ""))
        XCTAssertEqual(Parser.exact.run("@1.2.3"), Match(result: .exact("1.2.3"), rest: ""))

        XCTAssertEqual(Parser.upToNextMajor.run(">=1.2.3"), Match(result: .range("1.2.3"..<"2.0.0"), rest: ""))
        XCTAssertEqual(Parser.upToNextMajor.run("@from:1.2.3"), Match(result: .range("1.2.3"..<"2.0.0"), rest: ""))

        XCTAssertEqual(Parser.range.run(">=1.2.3<3.2.1"), Match(result: .range("1.2.3"..<"3.2.1"), rest: ""))
        XCTAssertEqual(Parser.range.run("@1.2.3..<3.2.1"), Match(result: .range("1.2.3"..<"3.2.1"), rest: ""))
        XCTAssertEqual(Parser.range.run("@1.2.3...3.2.1"), Match(result: .range("1.2.3"..<"3.2.2"), rest: ""))

        do {  // combined
            XCTAssertEqual(Parser.requirement.run(""), Match(result: .range("0.0.0"..<"1.0.0"), rest: ""))
            XCTAssertEqual(Parser.requirement.run("==1.2.3"), Match(result: .exact("1.2.3"), rest: ""))
            XCTAssertEqual(Parser.requirement.run("@1.2.3"), Match(result: .exact("1.2.3"), rest: ""))
            XCTAssertEqual(Parser.requirement.run(">=1.2.3"), Match(result: .range("1.2.3"..<"2.0.0"), rest: ""))
            XCTAssertEqual(Parser.requirement.run("@from:1.2.3"), Match(result: .range("1.2.3"..<"2.0.0"), rest: ""))
            XCTAssertEqual(Parser.requirement.run(">=1.2.3<3.0.0"), Match(result: .range("1.2.3"..<"3.0.0"), rest: ""))
            XCTAssertEqual(Parser.requirement.run("@1.2.3..<3.0.0"), Match(result: .range("1.2.3"..<"3.0.0"), rest: ""))
        }
    }

    func test_parse_url() throws {
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: ""))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar==1.2.3"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: "==1.2.3"))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar>=1.2.3"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: ">=1.2.3"))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar>=1.2.3<3.0.0"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: ">=1.2.3<3.0.0"))

        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: ""))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar@1.2.3"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: "@1.2.3"))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar@from:1.2.3"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: "@from:1.2.3"))
        XCTAssertEqual(Parser.url.run("https://github.com/foo/bar@1.2.3..<3.0.0"),
                       Match(result: URL(string: "https://github.com/foo/bar"), rest: "@1.2.3..<3.0.0"))
    }

    func test_parse_branchName() {
        XCTAssertEqual(branchName.run("develop"), Match(result: "develop", rest: ""))
        XCTAssertEqual(branchName.run("foo-bar"), Match(result: "foo-bar", rest: ""))
        // disallowed
        XCTAssertEqual(branchName.run("/foo"), Match(result: nil, rest: "/foo"))
        XCTAssertEqual(branchName.run("foo."), Match(result: nil, rest: "foo."))
        XCTAssertEqual(branchName.run("foo/"), Match(result: nil, rest: "foo/"))
    }

    func test_parse_branch() {
        XCTAssertEqual(Parser.branch.run("@branch:develop"), Match(result: .branch("develop"), rest: ""))
    }

    func test_parse_dependency() throws {
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .range("0.0.0"..<"1.0.0")),
                             rest: ""))
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@1.2.3"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .exact("1.2.3")),
                             rest: ""))
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@from:1.2.3"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .range("1.2.3"..<"2.0.0")),
                             rest: ""))
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@1.2.3..<4.0.0"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .range("1.2.3"..<"4.0.0")),
                             rest: ""))
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@1.2.3...4.0.0"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .range("1.2.3"..<"4.0.1")),
                             rest: ""))
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@branch:develop"),
                       Match(result: Dependency(url: URL(string: "https://github.com/foo/bar")!,
                                                requirement: .branch("develop")),
                             rest: ""))
    }

    func test_parse_dependency_errors() throws {
        // unparsable trailing characters
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@from:1.2.3trailingjunk"),
                       Match(result: nil,
                             rest: "https://github.com/foo/bar@from:1.2.3trailingjunk"))
        // invalid version
        XCTAssertEqual(Parser.dependency.run("https://github.com/foo/bar@from:1.2.3..<2.0.0"),
                       Match(result: nil,
                             rest: "https://github.com/foo/bar@from:1.2.3..<2.0.0"))
    }

    func test_dependency_package_clause() throws {
        do {
            let dep = Dependency(url: URL(string: "https://github.com/foo/bar")!, requirement: .branch("develop"))
            XCTAssertEqual(dep.packageClause, #".package(url: "https://github.com/foo/bar", .branch("develop"))"#)
        }
        do {
            let dep = Dependency(url: URL(string: "https://github.com/foo/bar")!, requirement: .exact("1.2.3"))
            XCTAssertEqual(dep.packageClause, #".package(url: "https://github.com/foo/bar", .exact("1.2.3"))"#)
        }
        do {
            let dep = Dependency(url: URL(string: "https://github.com/foo/bar")!, requirement: .range("1.2.3"..<"2.3.4"))
            XCTAssertEqual(dep.packageClause, #".package(url: "https://github.com/foo/bar", "1.2.3"..<"2.3.4")"#)
        }
        do {
            let dep = Dependency(url: URL(string: "https://github.com/foo/bar")!, requirement: .revision("foo"))
            XCTAssertEqual(dep.packageClause, #".package(url: "https://github.com/foo/bar", .revision("foo"))"#)
        }
    }
}


extension XCTestCase {
    /// Returns path to the built products directory.
    var productsDirectory: Foundation.URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }

    var projectDirectory: Foundation.URL {
        productsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var checkoutsDirectory: Path {
        // if run via "swift test":
        // projectDirectory/.build/checkouts
        // if run via Xcode
        // projectDirectory(*)/SourcePackages/checkouts
        // where projectDirectory resolves to a path under DerivedData
        let path = Path(url: projectDirectory)!
        for testPath in ["/.build/checkouts", "/SourcePackages/checkouts"] {
            let p = path/testPath
            if p.exists {
                return p
            }
        }
        fatalError("checkouts directory not found!")
    }
}


