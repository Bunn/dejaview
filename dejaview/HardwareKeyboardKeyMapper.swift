import UIKit
import RoyalVNCKit

enum HardwareKeyboardKeyMapper {
    static func keyCode(for usage: UIKeyboardHIDUsage) -> VNCKeyCode? {
        switch usage {
        case .keyboardReturnOrEnter, .keyboardReturn:
            return .return
        case .keyboardDeleteOrBackspace:
            return .delete
        case .keyboardDeleteForward:
            return .forwardDelete
        case .keyboardTab:
            return .tab
        case .keyboardEscape:
            return .escape
        case .keyboardSpacebar:
            return .space
        case .keyboardLeftArrow:
            return .leftArrow
        case .keyboardRightArrow:
            return .rightArrow
        case .keyboardUpArrow:
            return .upArrow
        case .keyboardDownArrow:
            return .downArrow
        case .keyboardPageUp:
            return .pageUp
        case .keyboardPageDown:
            return .pageDown
        case .keyboardHome:
            return .home
        case .keyboardEnd:
            return .end
        case .keyboardInsert:
            return .insert
        case .keypadEnter:
            return .ansiKeypadEnter
        case .keypadSlash:
            return .ansiKeypadDivide
        case .keypadAsterisk:
            return .ansiKeypadMultiply
        case .keypadHyphen:
            return .ansiKeypadMinus
        case .keypadPlus:
            return .ansiKeypadPlus
        case .keypadEqualSign:
            return .ansiKeypadEquals
        case .keypadPeriod:
            return .ansiKeypadDecimal
        case .keyboardF1:
            return .f1
        case .keyboardF2:
            return .f2
        case .keyboardF3:
            return .f3
        case .keyboardF4:
            return .f4
        case .keyboardF5:
            return .f5
        case .keyboardF6:
            return .f6
        case .keyboardF7:
            return .f7
        case .keyboardF8:
            return .f8
        case .keyboardF9:
            return .f9
        case .keyboardF10:
            return .f10
        case .keyboardF11:
            return .f11
        case .keyboardF12:
            return .f12
        case .keyboardF13:
            return .f13
        case .keyboardF14:
            return .f14
        case .keyboardF15:
            return .f15
        case .keyboardF16:
            return .f16
        case .keyboardF17:
            return .f17
        case .keyboardF18:
            return .f18
        case .keyboardF19:
            return .f19
        default:
            return nil
        }
    }

    static func modifierKeyCodes(for flags: UIKeyModifierFlags,
                                 includeShift: Bool) -> [VNCKeyCode] {
        var keyCodes: [VNCKeyCode] = []

        if includeShift, flags.contains(.shift) {
            keyCodes.append(.shift)
        }

        if flags.contains(.control) {
            keyCodes.append(.control)
        }

        if flags.contains(.alternate) {
            keyCodes.append(.option)
        }

        if flags.contains(.command) {
            keyCodes.append(.command)
        }

        return keyCodes
    }
}
