import Foundation

enum SlotEdge { case start, end }

enum DragMode: Equatable {
    case create(start: Int, current: Int)
    case resize(slotID: UUID, edge: SlotEdge, originalStart: Int, originalEnd: Int)
}
