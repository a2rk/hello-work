// Private.swift — приватные API SkyLight/CoreGraphics Services.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import CoreGraphics

typealias CGSConnectionID = Int32

// MARK: - CGSConnection

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

// MARK: - CGSWindow

@_silgen_name("CGSGetWindowList")
func CGSGetWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetOnScreenWindowList")
func CGSGetOnScreenWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetWindowCount")
func CGSGetWindowCount(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetOnScreenWindowCount")
func CGSGetOnScreenWindowCount(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outRect: inout CGRect
) -> CGError

@_silgen_name("CGSGetWindowOwner")
func CGSGetWindowOwner(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outOwner: inout CGSConnectionID
) -> CGError

@_silgen_name("CGSConnectionGetPID")
func CGSConnectionGetPID(
    _ cid: CGSConnectionID,
    _ outPID: inout pid_t
) -> CGError

// MARK: - Window Alpha (для hide-by-alpha подхода)

/// Устанавливает alpha (прозрачность) окна. 0.0 = полностью невидимо,
/// 1.0 = непрозрачно. Работает на любые windows включая чужие menubar items.
@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ alpha: CGFloat
) -> CGError

@_silgen_name("CGSGetWindowAlpha")
func CGSGetWindowAlpha(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outAlpha: inout CGFloat
) -> CGError
