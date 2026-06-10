//
//  PhoneFormat.swift
//  iMessage
//

import Foundation

/// 将 11 位中国大陆手机号格式化为 +86 分段展示；非 11 位数字串保持原样。
func formatPhoneDisplay(_ number: String) -> String {
    let digits = number.filter(\.isNumber)
    if digits.count == 11 {
        let n = String(digits)
        let a = n.prefix(3)
        let b = n.dropFirst(3).prefix(4)
        let c = n.suffix(4)
        return "+86 \(a) \(b) \(c)"
    }
    return number
}
