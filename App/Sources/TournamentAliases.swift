import GameCore

// `Group` is ambiguous in files that also import SwiftUI (SwiftUI.Group vs
// GameCore.Group), and `GameCore.Group` can't be written because the module
// name is shadowed by the `GameCore` enum. This file imports only GameCore, so
// the bare name resolves unambiguously; the rest of the app uses this alias.
typealias FootballGroup = Group
