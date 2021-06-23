//
//  String+.swift
//  RemoteCam
//
//  Created by jino on 2021/06/23.
//


// https://stackoverflow.com/a/39215372
extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        } else {
            return String(self.suffix(toLength))
        }
    }
}


