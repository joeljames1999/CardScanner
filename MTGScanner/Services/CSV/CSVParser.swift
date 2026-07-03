//
//  CSVParser.swift
//  TcgScanner
//
//  Created by Joel James on 03/07/2026.
//
import Foundation

enum CSVParser {

    static func parse(_ text: String) -> [[String]] {
        text
            .split(whereSeparator: \.isNewline)
            .map { parseLine(String($0)) }
    }

    static func parseLine(_ line: String) -> [String] {

        var fields: [String] = []
        var field = ""

        var insideQuotes = false

        let chars = Array(line)
        var i = 0

        while i < chars.count {

            let c = chars[i]

            if c == "\"" {

                if insideQuotes &&
                    i + 1 < chars.count &&
                    chars[i + 1] == "\"" {

                    field.append("\"")
                    i += 1

                } else {

                    insideQuotes.toggle()
                }

            } else if c == "," && !insideQuotes {

                fields.append(field)
                field = ""

            } else {

                field.append(c)
            }

            i += 1
        }

        fields.append(field)

        return fields
    }
}
