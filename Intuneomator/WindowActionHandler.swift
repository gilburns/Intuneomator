//
//  WindowActionHandler.swift
//  Intuneomator
//
//  Created by Gil Burns on 7/28/25.
//

import Cocoa

class WindowActionHandler: NSResponder {
    
    @IBAction func openAppsCategoryManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "AppCategoryManagerViewController",
            storyboardName: "AppCategories",
            controllerType: AppCategoryManagerViewController.self,
            windowTitle: "App Category Manager",
            defaultSize: NSSize(width: 650, height: 500),
            restoreKey: "AppCategoryManagerViewController"
        )
    }

    @IBAction func openAppsReportingManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "AppsReportingManagerViewController",
            storyboardName: "AppsReporting",
            controllerType: AppsReportingManagerViewController.self,
            windowTitle: "App Installation Status",
            defaultSize: NSSize(width: 820, height: 410),
            restoreKey: "AppsReportingManagerViewController"
        )
    }

    @IBAction func openConfigReportingManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "ConfigReportingManagerViewController",
            storyboardName: "ConfigReporting",
            controllerType: ConfigReportingManagerViewController.self,
            windowTitle: "Config Installation Status",
            defaultSize: NSSize(width: 820, height: 410),
            restoreKey: "ConfigReportingManagerViewController"
        )
    }

    @IBAction func openCustomAttributeManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "CustomAttributeManagerViewController",
            storyboardName: "CustomAttributes",
            controllerType: CustomAttributeManagerViewController.self,
            windowTitle: "Custom Attribute Manager",
            defaultSize: NSSize(width: 820, height: 410),
            restoreKey: "CustomAttributeManagerViewController"
        )
    }

    @IBAction func openDevicesManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "DevicesViewController",
            storyboardName: "DevicesManager",
            controllerType: DevicesViewController.self,
            windowTitle: "Intune Devices",
            defaultSize: NSSize(width: 950, height: 600),
            restoreKey: "DevicesViewController"
        )
    }

    @IBAction func openDiscoveredAppsManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "DiscoveredAppsViewController",
            storyboardName: "DiscoveredApps",
            controllerType: DiscoveredAppsViewController.self,
            windowTitle: "Intune Discovered Apps",
            defaultSize: NSSize(width: 800, height: 420),
            restoreKey: "DiscoveredAppsViewController"
        )
    }

    @IBAction func openReportsExportManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "IntuneReportsViewController",
            storyboardName: "IntuneReports",
            controllerType: IntuneReportsViewController.self,
            windowTitle: "Intune Reports Export",
            defaultSize: NSSize(width: 550, height: 250),
            restoreKey: "IntuneReportsViewController"
        )
    }

    @IBAction func openReportsScheduleManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "ScheduledReportsManagementViewController",
            storyboardName: "IntuneReports",
            controllerType: ScheduledReportsManagementViewController.self,
            windowTitle: "Scheduled Reports Manager",
            defaultSize: NSSize(width: 800, height: 600),
            restoreKey: "ScheduledReportsManagementViewController"
        )
    }

    @IBAction func openShellScriptsManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "ScriptManagerViewController",
            storyboardName: "ShellScripts",
            controllerType: ScriptManagerViewController.self,
            windowTitle: "Shell Script Manager",
            defaultSize: NSSize(width: 820, height: 410),
            restoreKey: "ScriptManagerViewController"
        )
    }

    @IBAction func openWebClipsManagerWindow(_ sender: Any?) {
        WindowManager.shared.openWindow(
            identifier: "WebClipsManagerViewController",
            storyboardName: "WebClips",
            controllerType: WebClipsManagerViewController.self,
            windowTitle: "Web Clip Manager",
            defaultSize: NSSize(width: 820, height: 410),
            restoreKey: "WebClipsManagerViewController"
        )
    }

}

