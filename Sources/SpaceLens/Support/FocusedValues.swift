import SwiftUI

struct FocusSearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearchAction: FocusSearchActionKey.Value? {
        get { self[FocusSearchActionKey.self] }
        set { self[FocusSearchActionKey.self] = newValue }
    }
}
