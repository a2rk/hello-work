import Foundation

/// Тип события, перехваченного overlay'ом во время блокировки.
enum StatEvent {
    case tap            // .leftMouseDown — главная метрика
    case secondaryTap   // .rightMouseDown / .otherMouseDown
    case scrollSwipe    // дебаунсенный жест скролла
    case keystroke      // .keyDown
}
