//
//  Scheme.swift
//  
//
//  Created by Sven A. Schmidt on 02/01/2020.
//

import Foundation
import Path


enum Scheme: String, CaseIterable {
    case https = "https://"
    case http = "http://"
    case file = "file://"
    case nonstandardizedFile = "file:"
    case empty = ""

    func url(path: String) -> URL? {
        switch self {
            case .https, .http, .file:
                return URL(string: rawValue + path)
            case .nonstandardizedFile:
                return URL(string: Scheme.file.rawValue + path)
            case .empty:
                let p = Path(path) ?? Path.cwd/path
                return URL(string: "file://" + p.string)
        }
    }
}
