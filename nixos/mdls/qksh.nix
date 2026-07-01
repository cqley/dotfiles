{ pkgs, ... }:

{
  xdg.configFile."quickshell/shell.qml".text = ''
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Hyprland
    import Quickshell.Io
    import Quickshell.Services.Notifications
    import QtQuick
    import QtQuick.Layouts
    import QtCore

    Scope {
        id: configRoot

    Component.onCompleted: {
        let families = Qt.fontFamilies()
        if (!families.includes("JetBrainsMono Nerd Font"))
            console.warn("[shell] jetbrainsmono nerd font not found")
    }

    Settings {
        id: barSettings
        location: Qt.resolvedUrl("state")
        property string position: "top"
        property string layout: "minimal"
        property string look: "float"
        property string centerMode: "default"
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: (notif) => {
            if (notifModel.count >= 3) notifModel.remove(0)
            notifModel.append({
                nid:     notif.id,
                app:     notif.appName   ?? "",
                summary: notif.summary   ?? "",
                body:    notif.body      ?? "",
                timeout: notif.expireTimeout > 0 ? notif.expireTimeout : 5000
            })
        }
    }

    ListModel { id: notifModel }

    PanelWindow {
        id: root
        property string position: barSettings.position
        property string layout:   barSettings.layout
        property string look:     barSettings.look

        screen: Quickshell.screens.find(s => s.name === "HDMI-A-1") ?? Quickshell.screens[0]

        property string activeMode:  "none"
        property bool   autoHideBar: false

        property var launcherTopApp: null

        property string sysStats: "cpu --% | mem --%"
        property string micState: "󰍬"

        function removeNotif(nid) {
            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).nid === nid) {
                    notifModel.remove(i)
                    break
                }
            }
        }

        function launcherRefilter(q) {
            if (!DesktopEntries.applications?.values || q === "") {
                launcherTopApp = null; return
            }
            let ql = q.toLowerCase()
            let m = DesktopEntries.applications.values.filter(
                a => a?.name && a.name.toLowerCase().includes(ql)
            ).sort((a, b) => {
                let an = a.name.toLowerCase()
                let bn = b.name.toLowerCase()
                if (an === ql) return -1
                if (bn === ql) return 1
                if (an.startsWith(ql) && !bn.startsWith(ql)) return -1
                if (!an.startsWith(ql) && bn.startsWith(ql)) return 1
                if (an.includes("steam") && an !== "steam" && bn === "steam") return 1
                if (bn.includes("steam") && bn !== "steam" && an === "steam") return -1
                return an.localeCompare(bn)
            })
            launcherTopApp = m.length > 0 ? m[0] : null
        }

        function launcherOpen() {
            if (!root.visible) { autoHideBar = true; root.visible = true }
            else                  autoHideBar = false
            launcherTopApp = null
            activeMode = "launcher"
        }

        function launcherClose() {
            activeMode = "none"
            launcherTopApp = null
            if (autoHideBar) { root.visible = false; autoHideBar = false }
        }

        function launcherAccept() {
            if (launcherTopApp !== null) {
                let exec = launcherTopApp.execString.replace(/%[fFuU]/g, "")
                launchProc.command = ["systemd-run", "--user", "--scope", "bash", "-c", exec]
                launchProc.running = true
            }
            launcherClose()
        }

        property string masterLevel:    "root"
        property var    masterStack:    []
        property var    masterCurrent:  []
        property var    masterFiltered: []
        property int    masterSelected: 0

        property var masterRootItems: [
            { label: "cfg", sub: "cfg" },
            { label: "sts", sub: "sts" },
            { label: "wp",  sub: "wallpapers"  },
            { label: "pw",  sub: "pw"  }
        ]
        property var masterCfgItems: [
            { label: "nix",   cmd: ["kitty", "-e", "sudo", "nvim", "/etc/nixos/hosts/box/configuration.nix"] },
            { label: "box",   cmd: ["kitty", "-e", "sudo", "nvim", "/etc/nixos/hosts/box/box.nix"]           },
            { label: "hypr",  cmd: ["kitty", "-e", "sudo", "nvim", "/etc/nixos/mdls/hypr.nix"]               },
            { label: "shell", cmd: ["kitty", "-e", "sudo", "nvim", "/etc/nixos/mdls/qksh.nix"]               },
            { label: "vi",    cmd: ["kitty", "-e", "sudo", "nvim", "/etc/nixos/mdls/vi.nix"]                 }
        ]
        property var masterStsItems: [
            { label: "animations", sub: "animations" },
            { label: "bar", sub: "bar" }
        ]
        property var masterAnimationsItems: [
            { label: "fade",
              cmd:    ["hyprctl", "eval", "hl.animation({ leaf = \"workspaces\", enabled = true, speed = 1.94, bezier = \"almostLinear\", style = \"fade\" })"],
              cmd2:   ["hyprctl", "eval", "hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 1.94, bezier = \"almostLinear\", style = \"fade\" })"],
              notify: ["notify-send", "animations", "fade"] },
            { label: "vertical",
              cmd:    ["hyprctl", "eval", "hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5, bezier = \"hard\", style = \"slidevert\" })"],
              cmd2:   ["hyprctl", "eval", "hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 5, bezier = \"hard\", style = \"slidevert\" })"],
              notify: ["notify-send", "animations", "vertical"] },
            { label: "horizontal",
              cmd:    ["hyprctl", "eval", "hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5, bezier = \"hard\", style = \"slide\" })"],
              cmd2:   ["hyprctl", "eval", "hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 5, bezier = \"hard\", style = \"slide\" })"],
              notify: ["notify-send", "animations", "horizontal"] }
        ]
        property var masterBarItems:     [{ label: "position", sub: "barPosition" }, { label: "layout", sub: "barLayout" }, { label: "mode", sub: "barMode" }, { label: "look", sub: "barLook" }]
        property var masterBarPositionItems:  [{ label: "top", barPos: "top" }, { label: "bottom", barPos: "bottom" }]
        property var masterBarLayoutItems: [{ label: "minimal", barLyt: "minimal" }, { label: "full", barLyt: "full" }]
        property var masterBarModeItems: [{ label: "performance", centerLyt: "performance" }, { label: "default", centerLyt: "default" }]
        property var masterBarLookItems: [{ label: "float", barLook: "float" }, { label: "fill", barLook: "fill" }]
        property var masterWpItems:      []
        property string masterWpBuf:    ""
        property var masterPwItems: [
            { label: "lock",     cmd: ["hyprlock"]                                    },
            { label: "logout",   cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
            { label: "reboot",   cmd: ["systemctl", "reboot"]                   },
            { label: "shutdown", cmd: ["systemctl", "poweroff"]                 }
        ]

        function masterItemsForLevel(l) {
            let lookup = { cfg: masterCfgItems, sts: masterStsItems, animations: masterAnimationsItems, bar: masterBarItems, barPosition: masterBarPositionItems, barLayout: masterBarLayoutItems, barMode: masterBarModeItems, barLook: masterBarLookItems, wallpapers: masterWpItems, pw: masterPwItems }
            return lookup[l] ?? masterRootItems
        }

        function masterRefilter(q) {
            masterFiltered = q === "" ? masterCurrent : masterCurrent.filter(i => i.label.toLowerCase().includes(q.toLowerCase()))
            let max = masterFiltered.length - 1
            if (masterSelected > max) masterSelected = Math.max(0, max)
        }

        function masterGoTo(l) {
            masterLevel    = l
            masterSelected = 0
            if (l === "wallpapers") {
                masterWpItems  = []; masterWpBuf = ""
                masterCurrent  = []; masterFiltered = []
                wpLsProc.running = true
            } else {
                masterCurrent  = masterItemsForLevel(l)
                masterFiltered = masterCurrent
            }
        }

        function masterOpen() {
            if (!root.visible) { autoHideBar = true; root.visible = true }
            else                  autoHideBar = false
            masterStack = []
            masterGoTo("root")
            activeMode = "master"
        }

        function masterClose() {
            activeMode = "none"
            if (autoHideBar) { root.visible = false; autoHideBar = false }
        }

        function masterBack() {
            if (masterStack.length > 0) {
                let prev   = masterStack[masterStack.length - 1]
                masterStack    = masterStack.slice(0, -1)
                masterLevel    = prev
                masterSelected = 0
                masterCurrent  = masterItemsForLevel(prev)
                masterFiltered = masterCurrent
            } else {
                masterClose()
            }
        }

        function masterAccept() {
            let items = masterFiltered
            let idx   = masterSelected
            if (items.length === 0 || idx < 0 || idx >= items.length) return
            let item  = items[idx]

            if (item.sub !== undefined) {
                masterStack = masterStack.concat([masterLevel])
                masterGoTo(item.sub)
                return
            }
            if (item.wp !== undefined) {
                mProc.command = ["bash", "-c", "colors \"$HOME/.wallpapers/" + item.wp + "\""]
                mProc.running = true
                masterClose(); return
            }
            if (item.barPos  !== undefined) { barSettings.position = item.barPos; masterClose(); return }
            if (item.barLyt  !== undefined) { barSettings.layout   = item.barLyt; masterClose(); return }
            if (item.barLook !== undefined) { barSettings.look     = item.barLook; masterClose(); return }
            if (item.centerLyt !== undefined) { barSettings.centerMode = item.centerLyt; masterClose(); return }
            if (item.cmd    !== undefined) { mProc.command  = item.cmd; mProc.running  = true }
            if (item.cmd2   !== undefined) { mProc2.command = item.cmd2; mProc2.running = true }
            if (item.notify !== undefined) { mProc3.command = item.notify; mProc3.running = true }
            masterClose()
        }

        onActiveModeChanged: {
            if (activeMode !== "none" && activeMode !== "calendar" && typeof barInput !== "undefined") {
                barInput.text = ""
                barInput.forceActiveFocus()
            }
        }

        WlrLayershell.keyboardFocus: activeMode !== "none" && activeMode !== "calendar" ? WlrLayershell.Exclusive : WlrLayershell.None

        anchors.top:    position === "top"
        anchors.bottom: position === "bottom"

        implicitWidth:  look === "fill" ? (root.screen?.width ?? 1920)
                      : layout === "full" ? (root.screen?.width ?? 1920) - 12
                      : 820
        implicitHeight: 22

        margins.top:    look === "fill" ? 0 : (position === "top"    ? 6 : 0)
        margins.bottom: look === "fill" ? 0 : (position === "bottom" ? 6 : 0)

        exclusiveZone: 22
        color: "transparent"

        IpcHandler {
            target: "bar"
            function toggle(): void { root.visible = !root.visible }
        }
        IpcHandler {
            target: "menu"
            function toggle(): void {
                if (root.activeMode === "launcher") root.launcherClose()
                else root.launcherOpen()
            }
        }
        IpcHandler {
            target: "master"
            function toggle(): void {
                if (root.activeMode === "master") root.masterClose()
                else root.masterOpen()
            }
        }
        IpcHandler {
            target: "calendar"
            function toggle(): void {
                if (root.activeMode === "calendar") root.activeMode = "none"
                else root.activeMode = "calendar"
            }
        }
        IpcHandler {
            target: "mic"
            function toggle(): void {
                micActProc.command = ["${pkgs.wireplumber}/bin/wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
                micActProc.running = true
            }
        }

        Connections {
            target: Hyprland
            function onFocusedWorkspaceChanged() {
                if (root.activeMode !== "none") root.activeMode = "none"
            }
        }

        Process { id: launchProc; running: false }
        Process { id: mProc; running: false }
        Process { id: mProc2; running: false }
        Process { id: mProc3; running: false }

        Process {
            id: wpLsProc
            command: ["bash", "-c", "ls $HOME/.wallpapers/"]
            running: false
            stdout: SplitParser {
                splitMarker: ""
                onRead: data => { root.masterWpBuf += data }
            }
            onRunningChanged: {
                if (!running && root.masterWpBuf !== "") {
                    let lines = root.masterWpBuf.trim().split("\n").filter(l => l.length > 0)
                    root.masterWpItems  = lines.map(l => ({ label: l, wp: l }))
                    root.masterWpBuf    = ""
                    if (root.activeMode === "master" && root.masterLevel === "wallpapers") {
                        root.masterCurrent  = root.masterWpItems
                        root.masterFiltered = root.masterWpItems
                    }
                }
            }
        }

        Timer {
            interval: 2000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                if (barSettings.centerMode === "performance" && !sysProc.running) sysProc.running = true
                if (!micProc.running) micProc.running = true
            }
        }

        Process {
            id: sysProc
            command: ["sh", "-c", "echo \"cpu $(top -bn1 | awk '/Cpu\\(s\\):/ {print $2}')% | mem $(free | awk '/Mem:/ {print int($3/$2*100)}')%\""]
            running: false
            stdout: SplitParser {
                onRead: data => { root.sysStats = data.trim() }
            }
        }

        Process {
            id: micProc
            command: ["sh", "-c", "${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print ($3==\"[MUTED]\"?\"󰍭\":\"󰍬\")}'"]
            running: false
            stdout: SplitParser {
                onRead: data => { root.micState = data.trim() }
            }
        }

        Process {
            id: micActProc
            running: false
            onRunningChanged: if (!running) micProc.running = true
        }

        FontMetrics {
            id: fm
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight:    Font.Normal
        }

        Rectangle {
            anchors.fill: parent
            color: "#1c1c1c"

            Text {
                anchors.centerIn: parent
                visible:        root.activeMode === "none" || root.activeMode === "calendar"
                font.family:    "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight:    Font.Normal
                renderType:     Text.NativeRendering
                color:          "#aaaaaa"
                text:           barSettings.centerMode === "performance" ? root.sysStats : ""
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Row {
                    spacing: 0
                    Layout.fillHeight: true

                    Repeater {
                        model: 10

                        Item {
                            property int   wsId:      index + 1
                            property var   ws:        Hyprland.workspaces?.values?.find(w => w.id === wsId) ?? null
                            property bool  isActive:  Hyprland.focusedWorkspace?.id === wsId
                            property bool  isUrgent:  ws?.urgent ?? false
                            property bool  hovered:   harea.containsMouse
                            property string kanji:    (["一","二","三","四","五","六","七","八","九","十"])[index]

                            visible: ws !== null || isActive
                            width:   visible ? Math.round(fm.advanceWidth(kanji)) + 16 : 0
                            height:  parent.height

                            Rectangle {
                                anchors.fill: parent
                                color: parent.isUrgent ? "#cc2222"
                                     : parent.isActive ? "#dddddd"
                                     : parent.hovered  ? "#2a2a2a"
                                     : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                font.family:    "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight:    Font.Normal
                                renderType:     Text.NativeRendering
                                color: parent.isUrgent ? "#ffffff"
                                     : parent.isActive ? "#000000"
                                     : parent.hovered  ? "#c0c0c0"
                                     : "#888888"
                                text: parent.kanji
                            }
                            MouseArea {
                                id: harea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + parent.wsId + '" })')
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill:        parent
                        anchors.leftMargin:  10
                        anchors.rightMargin: 10
                        spacing: 6
                        visible: root.activeMode === "launcher" || root.activeMode === "master"

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            renderType:     Text.NativeRendering
                            color: "#555555"
                            text: root.activeMode === "launcher" ? ">" : root.masterStack.concat([root.masterLevel]).join(" >")
                        }

                        TextInput {
                            id: barInput
                            Layout.fillWidth:  true
                            Layout.alignment:  Qt.AlignVCenter
                            height:            parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color:          "#c0c0c0"
                            focus:          root.activeMode === "launcher" || root.activeMode === "master"

                            onTextChanged: {
                                if (root.activeMode === "launcher") root.launcherRefilter(text)
                                else if (root.activeMode === "master") root.masterRefilter(text)
                            }
                            onAccepted: {
                                if (root.activeMode === "launcher") root.launcherAccept()
                                else if (root.activeMode === "master") root.masterAccept()
                            }
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    if (root.activeMode === "launcher") root.launcherClose()
                                    else if (root.activeMode === "master") root.masterBack()
                                    event.accepted = true
                                } else if (root.activeMode === "master") {
                                    if (event.key === Qt.Key_Down) {
                                        if (root.masterSelected < root.masterFiltered.length - 1) root.masterSelected++
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        if (root.masterSelected > 0) root.masterSelected--
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.alignment:   Qt.AlignVCenter
                            Layout.rightMargin: 4
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            renderType:     Text.NativeRendering
                            color: "#555555"
                            visible: root.activeMode === "launcher" ? root.launcherTopApp !== null : (root.activeMode === "master" ? root.masterFiltered.length > 0 : false)
                            text: root.activeMode === "launcher" ? (root.launcherTopApp?.name ?? "") : (root.activeMode === "master" && root.masterSelected < root.masterFiltered.length ? (root.masterFiltered[root.masterSelected]?.label ?? "") : "")
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    implicitWidth: 26

                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        Item {
                            width: 20
                            height: 22

                            Text {
                                id: micText
                                anchors.centerIn: parent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                renderType: Text.NativeRendering
                                color: "#aaaaaa"
                                text: root.micState
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    micActProc.command = ["${pkgs.wireplumber}/bin/wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
                                    micActProc.running = true
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                    implicitWidth: clockText.implicitWidth + 20

                    Rectangle {
                        anchors.horizontalCenter: parent.left
                        width: 1; height: parent.height
                        color: "#3c3c3c"
                    }
                    Text {
                        id: clockText
                        anchors.centerIn:   parent
                        font.family:        "JetBrainsMono Nerd Font"
                        font.pixelSize:      12
                        font.weight:        Font.Normal
                        font.letterSpacing: 0.02 * 11
                        renderType:          Text.NativeRendering
                        color: "#c0c0c0"
                        text:  Qt.formatDateTime(new Date(), "dd/MM | HH:mm:ss")

                        Timer {
                            interval: 1000; running: true; repeat: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "dd/MM | HH:mm:ss")
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.activeMode === "calendar") root.activeMode = "none"
                            else root.activeMode = "calendar"
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: masterOverlay
        visible: root.activeMode === "master" && root.masterFiltered.length > 0

        screen: Quickshell.screens.find(s => s.name === "HDMI-A-1") ?? Quickshell.screens[0]

        anchors.top:    root.position === "top"
        anchors.bottom: root.position === "bottom"
        anchors.left:   true
        anchors.right:  true

        margins.top:    root.position === "top"    ? (root.look === "fill" ? 0 : 6) : 0
        margins.bottom: root.position === "bottom" ? (root.look === "fill" ? 0 : 6) : 0

        implicitWidth:  root.implicitWidth
        implicitHeight: root.masterFiltered.length * (root.masterLevel === "wallpapers" ? 38 : 22)

        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayershell.Overlay

        MouseArea {
            anchors.fill: parent
            onClicked:    root.masterClose()
        }

        Rectangle {
            width:  root.implicitWidth
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#1c1c1c"

            Column {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width

                Repeater {
                    model: root.masterFiltered

                    Rectangle {
                        width:  parent.width
                        height: root.masterLevel === "wallpapers" ? 38 : 22
                        color:  root.masterSelected === index ? "#2a2a2a" : "transparent"

                        Image {
                            visible: root.masterLevel === "wallpapers"
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46; height: 26
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: visible ? "file:///home/cat/.wallpapers/" + modelData.wp : ""
                        }

                        Rectangle {
                            visible:                root.masterSelected === index
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: root.masterLevel === "wallpapers" ? 22 : 12
                            color: "#dddddd"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x:                      root.masterLevel === "wallpapers" ? 64 : 14
                            text:                   modelData?.label ?? ""
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            renderType:     Text.NativeRendering
                            color: root.masterSelected === index ? "#dddddd" : "#666666"
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right:          parent.right
                            anchors.rightMargin:    12
                            visible:                modelData?.sub !== undefined
                            text:                   "›"
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            renderType:     Text.NativeRendering
                            color: root.masterSelected === index ? "#888888" : "#333333"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered:   root.masterSelected = index
                            onClicked:   root.masterAccept()
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: notifOverlay
        visible: notifModel.count > 0

        screen: Quickshell.screens.find(s => s.name === "HDMI-A-1") ?? Quickshell.screens[0]

        anchors.top:    root.position === "top"
        anchors.bottom: root.position === "bottom"
        anchors.left:   true
        anchors.right:  true

        margins.top:    root.position === "top"    ? (root.look === "fill" ? 0 : 6) : 0
        margins.bottom: root.position === "bottom" ? (root.look === "fill" ? 0 : 6) : 0

        implicitWidth:  Math.round(root.implicitWidth / 3)
        implicitHeight: notifModel.count * 34

        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayershell.Overlay

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(root.implicitWidth / 3)
            spacing: 0

            Repeater {
                model: notifModel

                Rectangle {
                    id: toastRect
                    width:  Math.round(root.implicitWidth / 3)
                    height: 34
                    color:  "#1c1c1c"

                    Rectangle {
                        visible: index > 0
                        anchors.top: parent.top
                        width: parent.width; height: 1
                        color: "#2a2a2a"
                    }

                    Rectangle {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2; height: 18
                        color: "#dddddd"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.leftMargin:     12
                        anchors.rightMargin:    10
                        spacing: 2

                        Text {
                            width:          parent.width
                            text:           model.summary !== "" ? model.summary : model.app
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            renderType:     Text.NativeRendering
                            color:          "#dddddd"
                            elide:          Text.ElideRight
                        }

                        Text {
                            visible:        model.body !== "" && model.summary !== ""
                            width:          parent.width
                            text:           model.body
                            font.family:    "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            renderType:     Text.NativeRendering
                            color:          "#666666"
                            elide:          Text.ElideRight
                        }
                    }

                    Timer {
                        interval: model.timeout
                        running:  true
                        repeat:   false
                        onTriggered: root.removeNotif(model.nid)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked:    root.removeNotif(model.nid)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: calendarOverlay
        visible: root.activeMode === "calendar"

        screen: Quickshell.screens.find(s => s.name === "HDMI-A-1") ?? Quickshell.screens[0]

        anchors.top:    root.position === "top"
        anchors.bottom: root.position === "bottom"
        anchors.right:  true

        margins.top:    root.position === "top"    ? (root.look === "fill" ? 0 : 6) : 0
        margins.bottom: root.position === "bottom" ? (root.look === "fill" ? 0 : 6) : 0
        margins.right:  root.look === "fill" ? 0 : root.layout === "full" ? 6 : Math.round(((root.screen?.width ?? 1920) - 820) / 2)

        implicitWidth: 216
        implicitHeight: 186
        color: "transparent"

        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrLayershell.Exclusive : WlrLayershell.None

        property int selectedDay: new Date().getDate()
        property int viewYear: new Date().getFullYear()
        property int viewMonth: new Date().getMonth()

        property var days: {
            let today = new Date()
            let first = new Date(viewYear, viewMonth, 1).getDay()
            let total = new Date(viewYear, viewMonth + 1, 0).getDate()
            let ptotal = new Date(viewYear, viewMonth, 0).getDate()
            let res = []
            for (let i = first - 1; i >= 0; i--) {
                res.push({ d: ptotal - i, cur: false, today: false, monthOffset: -1 })
            }
            for (let i = 1; i <= total; i++) {
                let isToday = (i === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear())
                res.push({ d: i, cur: true, today: isToday, monthOffset: 0 })
            }
            let n = 42 - res.length
            for (let i = 1; i <= n; i++) {
                res.push({ d: i, cur: false, today: false, monthOffset: 1 })
            }
            return res
        }

        property string title: {
            let months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
            return months[viewMonth] + " " + viewYear
        }

        function prevMonth() {
            if (viewMonth === 0) { viewMonth = 11; viewYear-- }
            else                   viewMonth--
        }

        function nextMonth() {
            if (viewMonth === 11) { viewMonth = 0; viewYear++ }
            else                    viewMonth++
        }

        onVisibleChanged: {
            if (visible) {
                let d = new Date()
                viewYear = d.getFullYear()
                viewMonth = d.getMonth()
                selectedDay = d.getDate()
                calendarBox.forceActiveFocus()
            }
        }

        Rectangle {
            id: calendarBox
            anchors.fill: parent
            color: "#1c1c1c"
            border.color: "#3c3c3c"
            border.width: 1
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.activeMode = "none"
                    event.accepted = true
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: calendarOverlay.title
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: "#aaaaaa"
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 12

                        Text {
                            text: "<"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: prevMouse.containsMouse ? "#ffffff" : "#666666"
                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: calendarOverlay.prevMonth()
                            }
                        }

                        Text {
                            text: ">"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: nextMouse.containsMouse ? "#ffffff" : "#666666"
                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: calendarOverlay.nextMonth()
                            }
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: 4
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: ["s", "m", "t", "w", "t", "f", "s"]
                        Text {
                            width: 22; height: 14
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#666666"
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: 4
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: calendarOverlay.days

                        Rectangle {
                            width: 22; height: 22
                            property bool isHovered: dayMouse.containsMouse

                            color: modelData.today ? "#444444" : (isHovered ? "#333333" : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData.d
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: modelData.today ? "#ffffff" : (isHovered ? "#ffffff" : (modelData.cur ? "#aaaaaa" : "#444444"))
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }
    }
    }
  '';
}
