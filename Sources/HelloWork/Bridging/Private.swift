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
