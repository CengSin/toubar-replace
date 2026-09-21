import Foundation
import TouchBarPrivateAPI





enum TouchBarHardwareCapability {

    static var canCreateDisplayStream: Bool {
        TBRCanCreateTouchBarDisplayStream()
    }


    static var canInstantiateDisplayStream: Bool {
        TBRCanInstantiateTouchBarDisplayStream()
    }


    static var canPresentSystemModal: Bool {
        TBRCanPresentSystemModalTouchBar()
    }


    static var usesSoftwareWorkspace: Bool {
        softwareWorkspaceMode(
            canPresentSystemModal: canPresentSystemModal,
            canCreateDisplayStream: canCreateDisplayStream,
            canInstantiateDisplayStream: canInstantiateDisplayStream
        )
    }


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


enum MirrorClickThroughPolicy {


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

    static func shouldEnterWorkspaceAtLaunch(
        usesSoftwareWorkspace: Bool,
        preferredScene: WorkspaceStartupScene
    ) -> Bool {
        _ = usesSoftwareWorkspace
        return preferredScene == .workspace
    }



    static func shouldStartHardwareCapture(usesSoftwareWorkspace: Bool) -> Bool {
        !usesSoftwareWorkspace
    }








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
