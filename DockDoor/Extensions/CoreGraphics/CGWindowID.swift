import Cocoa

extension CGWindowID {
    func cgsTitle() -> String? {
        var value: CFTypeRef?
        let status = CGSCopyWindowProperty(CGS_CONNECTION, self, "kCGSWindowTitle" as CFString, &value)
        guard status == .success, let str = value as? String else { return nil }
        return str
    }

    func cgsLevel() -> CGWindowLevel {
        var lvl: CGWindowLevel = 0
        _ = CGSGetWindowLevel(CGS_CONNECTION, self, &lvl)
        return lvl
    }

    func cgsSpaces() -> [CGSSpaceID] {
        let arr: CFArray = [NSNumber(value: self)] as CFArray
        let spaces = CGSCopySpacesForWindows(CGS_CONNECTION, CGSSpaceMask.all.rawValue, arr) as? [NSNumber] ?? []
        return spaces.map(\.uint64Value)
    }

    func cgsBounds() -> CGRect? {
        var wid = self
        var rect = CGRect.zero
        guard CGSGetWindowBounds(CGS_CONNECTION, &wid, &rect) == .success else { return nil }
        return rect
    }

    func cgsOwnerPid() -> pid_t? {
        var connectionId: CGSConnectionID = 0
        guard CGSGetWindowOwner(CGS_CONNECTION, self, &connectionId) == .success else { return nil }
        var psn = ProcessSerialNumber()
        guard CGSGetConnectionPSN(connectionId, &psn) == .success else { return nil }
        var pid: pid_t = 0
        GetProcessPID(&psn, &pid)
        return pid
    }
}
