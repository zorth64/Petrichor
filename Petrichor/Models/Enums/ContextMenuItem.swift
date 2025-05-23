import SwiftUI

enum ContextMenuItem {
    case button(title: String, role: ButtonRole? = nil, action: () -> Void)
    case menu(title: String, items: [ContextMenuItem])
    case divider
    
    var id: String {
        switch self {
        case .button(let title, _, _):
            return "button_\(title)"
        case .menu(let title, _):
            return "menu_\(title)"
        case .divider:
            return "divider_\(UUID().uuidString)"
        }
    }
}
