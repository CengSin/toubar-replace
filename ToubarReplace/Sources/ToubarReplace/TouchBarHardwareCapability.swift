import Foundation
import TouchBarPrivateAPI

/// Runtime probe for a usable physical Touch Bar stack (stream + system modal).
///
/// Gate is **API availability only** — never CPU brand / `uname` / arm64.
/// Intel Macs with Touch Bar must keep `usesSoftwareWorkspace == false`.
enum TouchBarHardwareCapability {
    /// SkyLight exports the private DFR display-stream entry point.
    static var canCreateDisplayStream: Bool {
        TBRCanCreateTouchBarDisplayStream()
    }

    /// A stream object can be created (symbol alone is not enough on some builds).
    static var canInstantiateDisplayStream: Bool {
        TBRCanInstantiateTouchBarDisplayStream()
    }

    /// AppKit exposes system-modal present/dismiss selectors.
    static var canPresentSystemModal: Bool {
        TBRCanPresentSystemModalTouchBar()
    }

    /// No usable physical Touch Bar: drive Workspace on the desktop mirror instead.
    static var usesSoftwareWorkspace: Bool {
        softwareWorkspaceMode(
            canPresentSystemModal: canPresentSystemModal,
            canCreateDisplayStream: canCreateDisplayStream,
            canInstantiateDisplayStream: canInstantiateDisplayStream
        )
    }

    /// Pure policy for smoke tests (no private-API side effects).
    static func softwareWorkspaceMode(
        canPresentSystemModal: Bool,
        canCreateDisplayStream: Bool,
        canInstantiateDisplayStream: Bool
    ) -> Bool {
        !canPresentSystemModal
            || !canCreateDisplayStream
            || !canInstantiateDisplayStream
    }
}

/// When the mirror panel should ignore mouse events (click-through).
enum MirrorClickThroughPolicy {
    /// Interactive only while desktop Workspace fallback chrome is visible.
    /// Physical Workspace (system modal) keeps the mirror click-through.
    static func ignoresMouseEvents(
        usesSoftwareWorkspace: Bool,
        scene: BarScene,
        showsWorkspaceFallback: Bool
    ) -> Bool {
        _ = usesSoftwareWorkspace
        if scene == .workspace, showsWorkspaceFallback {
            return false
        }
        return true
    }
}

enum SoftwareWorkspaceLaunchPolicy {
    /// Launch scene follows the user preference on both hardware and software.
    static func shouldEnterWorkspaceAtLaunch(
        usesSoftwareWorkspace: Bool,
        preferredScene: WorkspaceStartupScene
    ) -> Bool {
        _ = usesSoftwareWorkspace
        return preferredScene == .workspace
    }

    /// Physical capture stays on whenever the Mac has a usable Touch Bar stack,
    /// including when launch enters Workspace so switching back to mirror is warm.
    static func shouldStartHardwareCapture(usesSoftwareWorkspace: Bool) -> Bool {
        !usesSoftwareWorkspace
    }

    /// Effective switcher placement.
    ///
    /// Software mode only needs the floating window in **mirror** (no physical
    /// grid). Workspace itself always has an in-bar return, so the extra
    /// desktop pill is hidden there.
    /// Hardware honors the user preference in both scenes; Workspace still
    /// hosts its own physical return item.
    static func effectiveSwitcherDisplayMode(
        usesSoftwareWorkspace: Bool,
        preferred: WorkspaceSwitcherDisplayMode,
        scene: BarScene = .mirror
    ) -> WorkspaceSwitcherDisplayMode {
        if usesSoftwareWorkspace {
            return scene == .workspace ? .touchBar : .floating
        }
        return preferred
    }
}

enum TouchBarResumeAction: Equatable {
    case restoreSoftwareWorkspace
    case restartHardwareCapture
    case restoreHardwareWorkspace
}

enum TouchBarResumePolicy {
    static func action(
        usesSoftwareWorkspace: Bool,
        restoreWorkspace: Bool
    ) -> TouchBarResumeAction {
        if usesSoftwareWorkspace {
            return .restoreSoftwareWorkspace
        }
        return restoreWorkspace
            ? .restoreHardwareWorkspace
            : .restartHardwareCapture
    }
}

enum WorkspaceSleepPausePolicy {
    /// Sleep/lock fires several notifications. The first one latches whether
    /// we were in Workspace; later ones must not see the torn-down scene and
    /// overwrite that latch (that used to wake into mirror).
    static func latchedResumeToWorkspace(
        alreadyPaused: Bool,
        latchedResume: Bool,
        sceneIsWorkspace: Bool
    ) -> Bool {
        if alreadyPaused {
            return latchedResume
        }
        return sceneIsWorkspace || latchedResume
    }
}
