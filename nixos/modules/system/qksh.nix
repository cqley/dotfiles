{ pkgs, config, osConfig, ... }:
let
  host = osConfig.networking.hostName;
  isbed = host == "bed";
  wpdir = "pictures/wallpapers";
  sysstat = pkgs.writeCBin "sysstat" ''
    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
    #include <string.h>

    int main() {
        long double a[4], b[4];
        FILE *fp;
        while (1) {
            fp = fopen("/proc/stat", "r");
            if (!fp) break;
            fscanf(fp, "%*s %lf %lf %lf %lf", &a[0], &a[1], &a[2], &a[3]);
            fclose(fp);

            sleep(1);

            fp = fopen("/proc/stat", "r");
            if (!fp) break;
            fscanf(fp, "%*s %lf %lf %lf %lf", &b[0], &b[1], &b[2], &b[3]);
            fclose(fp);

            double load = ((b[0]+b[1]+b[2]) - (a[0]+a[1]+a[2])) / ((b[0]+b[1]+b[2]+b[3]) - (a[0]+a[1]+a[2]+a[3])) * 100.0;

            fp = fopen("/proc/meminfo", "r");
            if (!fp) break;
            long total = 0, avail = 0;
            char line[256];
            while (fgets(line, sizeof(line), fp)) {
                if (sscanf(line, "MemTotal: %ld kB", &total) == 1) continue;
                if (sscanf(line, "MemAvailable: %ld kB", &avail) == 1) break;
            }
            fclose(fp);

            int mem = total > 0 ? (int)(((double)(total - avail) / total) * 100.0) : 0;

            printf("cpu %d%% | mem %d%%\n", (int)load, mem);
            fflush(stdout);

            sleep(9);
        }
        return 0;
    }
  '';
in {
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

        property string colorBuf: ""
        property var colors: {
            "special": { "background": "#1c1c1c", "foreground": "#c0c0c0", "cursor": "#c0c0c0" },
            "colors": {
                "color0": "#1c1c1c", "color1": "#cc2222", "color2": "#22cc22", "color3": "#cccc22",
                "color4": "#2222cc", "color5": "#cc22cc", "color6": "#22cccc", "color7": "#aaaaaa",
                "color8": "#555555", "color9": "#ff4444", "color10": "#44ff44", "color11": "#ffff44",
                "color12": "#4444ff", "color13": "#ff44ff", "color14": "#44ffff", "color15": "#ffffff"
            }
        }

        component MText: Text {
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: Font.Normal
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            color: root.colors.special.foreground
        }

        component OverlayPanel: PanelWindow {
            id: overlayPanel
            property bool fullWidth: false
            property bool keyboardExclusive: false

            screen: Quickshell.screens.find(s => s.name === "HDMI-A-1") ?? Quickshell.screens[0]

            anchors.top:    root.position === "top"
            anchors.bottom: root.position === "bottom"
            anchors.left:   fullWidth
            anchors.right:  true

            margins.top:    root.position === "top"    ? (root.look === "fill" ? 0 : 6) : 0
            margins.bottom: root.position === "bottom" ? (root.look === "fill" ? 0 : 6) : 0
            margins.right:  fullWidth ? 0 : (root.look === "fill" ? 0 : root.layout === "full" ? 6 : Math.round(((root.screen?.width ?? 1920) - 820) / 2))

            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.keyboardFocus: keyboardExclusive && visible ? WlrLayershell.Exclusive : WlrLayershell.None
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
            actionsSupported: true
            imageSupported: true
            bodySupported: true
            persistenceSupported: true

            onNotification: (notif) => {
                if (notifModel.count >= 3) notifModel.remove(0)
                let app = notif.appName ?? ""
                let sum = notif.summary ?? ""
                let bod = notif.body ?? ""
                if (sum === "" && bod === "" && app !== "") sum = app
                if (sum === "" && bod !== "") { sum = bod; bod = "" }
                notifModel.append({
                    nid:     notif.id,
                    app:     app,
                    summary: sum,
                    body:    bod,
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
            property string batState: "--%"
            
            property string wifiState: "󰤪"
            property bool   wifiRadioEnabled: true
            property string wifiConnectedSSID: ""
            property var    wifiNetworks: []
            property string wifiBuf: ""
            property string wifiConnectError: ""
            property string wifiErrBuf: ""
            property int    wifiSelectedIndex: -1
            property bool   wifiConnecting: false

            property string btState: "󰂯"
            property string btConnectedName: ""
            property bool   btPowered: false
            property var    btDevices: []
            property string btBuf: ""
            property int    btSelectedIndex: -1

            function wifiOpen() {
                root.activeMode = "wifi"
                if (!wifiListProc.running) wifiListProc.running = true
            }

            function btOpen() {
                root.activeMode = "bluetooth"
                if (!btListProc.running) btListProc.running = true
            }

            function removeNotif(nid) {
                for (let i = 0; i < notifModel.count; i++) {
                    if (notifModel.get(i).nid === nid) {
                        notifModel.remove(i)
                        break
                    }
                }
            }

            function clearAllNotifs() {
                notifModel.clear()
            }

            function launcherRefilter(q) {
                if (!DesktopEntries.applications?.values || q === "") {
                    launcherTopApp = null; return
                }
                let ql = q.toLowerCase()
                let m = DesktopEntries.applications.values
                    .map(a => ({ app: a, n: a?.name ? a.name.toLowerCase() : "" }))
                    .filter(a => a.n.includes(ql))
                    .sort((a, b) => {
                        if (a.n === ql) return -1
                        if (b.n === ql) return 1
                        if (a.n.startsWith(ql) && !b.n.startsWith(ql)) return -1
                        if (!a.n.startsWith(ql) && b.n.startsWith(ql)) return 1
                        if (a.n.includes("steam") && a.n !== "steam" && b.n === "steam") return 1
                        if (b.n.includes("steam") && b.n !== "steam" && a.n === "steam") return -1
                        return a.n.localeCompare(b.n)
                    })
                    .map(a => a.app)
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
                    launchProc.command = ["${pkgs.systemd}/bin/systemd-run", "--user", "--scope", "${pkgs.bash}/bin/bash", "-c", exec]
                    launchProc.running = true
                }
                launcherClose()
            }

            property string masterLevel:    "root"
            property var    masterStack:    []
            property var    masterCurrent:  []
            property var    masterFiltered: []
            property int    masterSelected: 0

            property var masterTree: {
                "root": [
                    { label: "settings",  sub: "settings"  },
                    { label: "record",    sub: "record"    },
                    { label: "wallpaper", sub: "wallpapers" },
                    { label: "power",     sub: "power"     }
                ],
                "settings": [
                    { label: "animations", sub: "animations" },
                    { label: "bar", sub: "bar" }
                ],
                "animations": [
                    { label: "fade", cmd: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.hyprland}/bin/hyprctl --batch 'eval hl.animation({ leaf = \"workspaces\", enabled = true, speed = 1.94, bezier = \"almostLinear\", style = \"fade\" }) ; eval hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 1.94, bezier = \"almostLinear\", style = \"fade\" })' && ${pkgs.libnotify}/bin/notify-send animations fade"] },
                    { label: "vertical", cmd: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.hyprland}/bin/hyprctl --batch 'eval hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5, bezier = \"hard\", style = \"slidevert\" }) ; eval hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 5, bezier = \"hard\", style = \"slidevert\" })' && ${pkgs.libnotify}/bin/notify-send animations vertical"] },
                    { label: "horizontal", cmd: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.hyprland}/bin/hyprctl --batch 'eval hl.animation({ leaf = \"workspaces\", enabled = true, speed = 5, bezier = \"hard\", style = \"slide\" }) ; eval hl.animation({ leaf = \"specialWorkspace\", enabled = true, speed = 5, bezier = \"hard\", style = \"slide\" })' && ${pkgs.libnotify}/bin/notify-send animations horizontal"] }
                ],
                "bar":         [{ label: "position", sub: "barPosition" }, { label: "layout", sub: "barLayout" }, { label: "mode", sub: "barMode" }, { label: "look", sub: "barLook" }],
                "barPosition": [{ label: "top", barPos: "top" }, { label: "bottom", barPos: "bottom" }],
                "barLayout":   [{ label: "minimal", barLyt: "minimal" }, { label: "full", barLyt: "full" }],
                "barMode":     [{ label: "performance", centerLyt: "performance" }, { label: "default", centerLyt: "default" }, { label: "pile", centerLyt: "pile" }, { label: "alphabet", centerLyt: "alphabet" }, { label: "english", centerLyt: "english" }, { label: "numbers", centerLyt: "numbers" }],
                "barLook":     [{ label: "float", barLook: "float" }, { label: "fill", barLook: "fill" }],
                "power": [
                    { label: "lock",     cmd: [""]                                      },
                    { label: "logout",   cmd: ["${pkgs.hyprland}/bin/hyprctl", "dispatch", "hl.dsp.exit()"]  },
                    { label: "reboot",   cmd: ["${pkgs.systemd}/bin/systemctl", "reboot"]                   },
                    { label: "shutdown", cmd: ["${pkgs.systemd}/bin/systemctl", "poweroff"]                 }
                ]
            }
            property var masterWpItems:      []
            property string masterWpBuf:    ""
            property var masterRcdOutItems: []
            property string masterRcdOutBuf: ""

            function rcdItems() {
                return recProc.running
                    ? [{ label: "stop", rcdStop: true }]
                    : [{ label: "start", sub: "rcdOutput" }]
            }

            function masterItemsForLevel(l) {
                if (l === "wallpapers") return masterWpItems
                if (l === "rcdOutput")  return masterRcdOutItems
                if (l === "record")     return rcdItems()
                return masterTree[l] ?? masterTree["root"]
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
                    if (!wpLsProc.running) wpLsProc.running = true
                } else if (l === "rcdOutput") {
                    masterRcdOutItems = []; masterRcdOutBuf = ""
                    masterCurrent     = []; masterFiltered = []
                    if (!rcdMonProc.running) rcdMonProc.running = true
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
                    mProc.command = ["${pkgs.bash}/bin/bash", "-c", "colors \"${config.home.homeDirectory}/${wpdir}/" + item.wp + "\""]
                    mProc.running = true
                    masterClose(); return
                }
                if (item.rcdOut !== undefined) {
                    recProc.command = ["${pkgs.bash}/bin/bash", "-c", "${pkgs.coreutils}/bin/mkdir -p \"$HOME/videos\" && exec ${pkgs.gpu-screen-recorder}/bin/gpu-screen-recorder -w " + item.rcdOut + " -f 60 -q ultra -k hevc -fm cfr -a default_output -o \"$HOME/videos/meow_$(${pkgs.coreutils}/bin/date +%Y%m%d_%H%M%S).mp4\""]
                    recProc.running = true
                    mProc.command  = ["${pkgs.libnotify}/bin/notify-send", "-t", "2000", "meow", "started on " + item.rcdOut]
                    mProc.running  = true
                    masterClose(); return
                }
                if (item.rcdStop !== undefined) {
                    recProc.signal(2)
                    mProc.command = ["${pkgs.libnotify}/bin/notify-send", "-t", "2000", "meow", "saved"]
                    mProc.running = true
                    masterClose(); return
                }
                if (item.barPos  !== undefined) { barSettings.position = item.barPos; masterClose(); return }
                if (item.barLyt  !== undefined) { barSettings.layout   = item.barLyt; masterClose(); return }
                if (item.barLook !== undefined) { barSettings.look     = item.barLook; masterClose(); return }
                if (item.centerLyt !== undefined) { barSettings.centerMode = item.centerLyt; masterClose(); return }
                if (item.cmd    !== undefined) { mProc.command  = item.cmd; mProc.running  = true }
                masterClose()
            }

            onActiveModeChanged: {
                if (activeMode !== "none" && activeMode !== "calendar" && activeMode !== "wifi" && activeMode !== "tray" && activeMode !== "bluetooth" && typeof barInput !== "undefined") {
                    barInput.text = ""
                    barInput.forceActiveFocus()
                }
            }

            WlrLayershell.keyboardFocus: activeMode !== "none" && activeMode !== "calendar" && activeMode !== "wifi" && activeMode !== "tray" && activeMode !== "bluetooth" ? WlrLayershell.Exclusive : WlrLayershell.None

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
                target: "wifi"
                function toggle(): void {
                    if (root.activeMode === "wifi") root.activeMode = "none"
                    else root.wifiOpen()
                }
            }
            IpcHandler {
                target: "bluetooth"
                function toggle(): void {
                    if (root.activeMode === "bluetooth") root.activeMode = "none"
                    else root.btOpen()
                }
            }
            IpcHandler {
                target: "tray"
                function toggle(): void {
                    if (root.activeMode === "tray") root.activeMode = "none"
                    else root.activeMode = "tray"
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

            Process {
                id: colorProc
                command: ["${pkgs.coreutils}/bin/cat", "${config.home.homeDirectory}/.colors/colors.json"]
                running: true
                stdout: SplitParser {
                    splitMarker: ""
                    onRead: data => { configRoot.colorBuf += data }
                }
                onRunningChanged: {
                    if (!running && configRoot.colorBuf !== "") {
                        try {
                            configRoot.colors = JSON.parse(configRoot.colorBuf)
                        } catch(e) {}
                        configRoot.colorBuf = ""
                    }
                }
            }

            Process { id: launchProc; running: false }
            Process {
                id: mProc
                running: false
                onRunningChanged: if (!running) colorProc.running = true
            }
            Process { id: recProc; running: false }

            Process {
                id: rcdMonProc
                command: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.hyprland}/bin/hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[].name'"]
                running: false
                stdout: SplitParser {
                    splitMarker: ""
                    onRead: data => { root.masterRcdOutBuf += data }
                }
                onRunningChanged: {
                    if (!running && root.masterRcdOutBuf !== "") {
                        let lines = root.masterRcdOutBuf.trim().split("\n").filter(l => l.length > 0)
                        lines.push("portal")
                        root.masterRcdOutItems = lines.map(l => ({ label: l, rcdOut: l }))
                        root.masterRcdOutBuf   = ""
                        if (root.activeMode === "master" && root.masterLevel === "rcdOutput") {
                            root.masterCurrent  = root.masterRcdOutItems
                            root.masterFiltered = root.masterRcdOutItems
                        }
                    }
                }
            }

            Process {
                id: wpLsProc
                command: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.coreutils}/bin/ls ${config.home.homeDirectory}/${wpdir}/"]
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
                interval: 10000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    if (!micProc.running) micProc.running = true
                    if (!wifiStatusProc.running) wifiStatusProc.running = true
                    if (!btStatusProc.running) btStatusProc.running = true
                    ${if isbed then "if (!batProc.running) batProc.running = true" else ""}
                }
            }

            Process {
                id: sysProc
                command: ["${sysstat}/bin/sysstat"]
                running: barSettings.centerMode === "performance"
                stdout: SplitParser {
                    onRead: data => { root.sysStats = data.trim() }
                }
            }

            Process {
                id: micProc
                command: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | ${pkgs.gawk}/bin/awk '{print ($3==\"[MUTED]\"?\"󰍭\":\"󰍬\")}'"]
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

            Process {
                id: batProc
                command: ["${pkgs.bash}/bin/bash", "-c", "b=$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | ${pkgs.coreutils}/bin/head -n1); echo \"''${b:-0}%\""]
                running: ${if isbed then "true" else "false"}
                stdout: SplitParser {
                    onRead: data => { root.batState = data.trim() }
                }
            }

            Process {
                id: wifiStatusProc
                command: ["${pkgs.bash}/bin/bash", "-c", "r=$(${pkgs.networkmanager}/bin/nmcli -t radio wifi); s=$(${pkgs.networkmanager}/bin/nmcli -t -f active,ssid dev wifi | ${pkgs.gnugrep}/bin/grep '^yes:' | ${pkgs.coreutils}/bin/cut -d: -f2-); echo \"$r:$s\""]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        let parts = data.trim().split(":")
                        root.wifiRadioEnabled = (parts[0] === "enabled")
                        let ssid = parts.length > 1 ? parts.slice(1).join(":") : ""
                        if (ssid.length > 0) {
                            root.wifiConnectedSSID = ssid
                            root.wifiState = "󰤨"
                        } else {
                            root.wifiConnectedSSID = ""
                            root.wifiState = "󰤭"
                        }
                    }
                }
            }

            Process {
                id: wifiToggleProc
                running: false
                onRunningChanged: {
                    if (!running) {
                        wifiStatusProc.running = true
                        wifiListProc.running = true
                    }
                }
            }

            Process {
                id: wifiListProc
                command: ["${pkgs.bash}/bin/bash", "-c", "${pkgs.networkmanager}/bin/nmcli -t -f ssid,signal,security dev wifi list | ${pkgs.gawk}/bin/awk -F: 'length($1)>0 {print $1\":\"$2\":\"($3?\"\":\" \")}'"]
                running: false
                stdout: SplitParser {
                    splitMarker: ""
                    onRead: data => { root.wifiBuf += data }
                }
                onRunningChanged: {
                    if (!running && root.wifiBuf !== "") {
                        let lines = root.wifiBuf.trim().split("\n").filter(l => l.length > 0)
                        let seen = new Set()
                        let items = []
                        for (let l of lines) {
                            let parts = l.split(":")
                            let ssid = parts[0]
                            let signal = parseInt(parts[1] || "0") || 0
                            let sec = parts[2] || ""
                            if (!seen.has(ssid)) {
                                seen.add(ssid)
                                items.push({ label: ssid, signal: signal, sec: sec, connected: ssid === root.wifiConnectedSSID })
                            }
                        }
                        items.sort((a, b) => {
                            if (a.connected !== b.connected) return a.connected ? -1 : 1
                            return b.signal - a.signal
                        })
                        root.wifiNetworks = items
                        root.wifiBuf = ""
                    }
                }
            }

            Process {
                id: wifiConnectProc
                running: false
                stderr: SplitParser {
                    splitMarker: ""
                    onRead: data => { root.wifiErrBuf += data }
                }
                onRunningChanged: {
                    root.wifiConnecting = running
                    if (running) root.wifiErrBuf = ""
                }
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        root.wifiConnectError = ""
                        root.activeMode = "none"
                    } else {
                        root.wifiConnectError = root.wifiErrBuf.trim() !== "" ? root.wifiErrBuf.trim() : "connection failed"
                    }
                    wifiStatusProc.running = true
                    wifiListProc.running = true
                }
            }

            Process {
                id: btStatusProc
                command: ["${pkgs.bash}/bin/bash", "-c", "p=$(${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | ${pkgs.gnugrep}/bin/grep -c 'Powered: yes'); c=$(${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null | ${pkgs.coreutils}/bin/cut -d' ' -f3-); echo \"$p|$c\""]
                running: false
                stdout: SplitParser {
                    onRead: data => {
                        let parts = data.trim().split("|")
                        root.btPowered = parts[0] === "1"
                        root.btConnectedName = parts.length > 1 ? parts.slice(1).join("|").trim() : ""
                        root.btState = root.btConnectedName !== "" ? "󰂱" : (root.btPowered ? "󰂯" : "󰂲")
                    }
                }
            }

            Process {
                id: btToggleProc
                running: false
                onRunningChanged: if (!running) btStatusProc.running = true
            }

            Process {
                id: btListProc
                command: ["${pkgs.bash}/bin/bash", "-c", "c=$(${pkgs.bluez}/bin/bluetoothctl devices Connected | ${pkgs.coreutils}/bin/cut -d' ' -f2); ${pkgs.bluez}/bin/bluetoothctl devices | while read -r _ mac name; do is_c=0; if echo \"$c\" | ${pkgs.gnugrep}/bin/grep -q \"$mac\"; then is_c=1; fi; echo \"$mac|$name|$is_c\"; done"]
                running: false
                stdout: SplitParser {
                    splitMarker: ""
                    onRead: data => { root.btBuf += data }
                }
                onRunningChanged: {
                    if (!running && root.btBuf !== "") {
                        let lines = root.btBuf.trim().split("\n").filter(l => l.length > 0)
                        let items = []
                        for (let l of lines) {
                            let parts = l.split("|")
                            if (parts.length >= 3) {
                                items.push({ mac: parts[0], name: parts.slice(1, -1).join("|"), connected: parts[parts.length-1] === "1" })
                            }
                        }
                        root.btDevices = items.sort((a, b) => b.connected - a.connected)
                        root.btBuf = ""
                    }
                }
            }

            Process {
                id: btConnectProc
                running: false
                onRunningChanged: {
                    if (!running) {
                        btStatusProc.running = true
                        btListProc.running = true
                    }
                }
            }

            FontMetrics {
                id: fm
                font.family:    "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight:    Font.Normal
            }

            Rectangle {
                anchors.fill: parent
                color: configRoot.colors.special.background

                MText {
                    anchors.centerIn: parent
                    visible: root.activeMode === "none" || root.activeMode === "calendar" || root.activeMode === "wifi" || root.activeMode === "tray" || root.activeMode === "bluetooth"
                    text: barSettings.centerMode === "performance" ? root.sysStats : ""
                    color: configRoot.colors.special.foreground 
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Row {
                        spacing: 0
                        Layout.fillHeight: true
                        visible: barSettings.centerMode !== "pile"

                        Repeater {
                            model: 10

                            Item {
                                property int   wsId:      index + 1
                                property var   ws:        Hyprland.workspaces?.values?.find(w => w.id === wsId) ?? null
                                property bool  isActive:  Hyprland.focusedWorkspace?.id === wsId
                                property bool  isUrgent:  ws?.urgent ?? false
                                property bool  hovered:   harea.containsMouse
                                property string txt: {
                                    if (barSettings.centerMode === "alphabet") return (["a","b","c","d","e","f","g","h","i","j"])[index]
                                    if (barSettings.centerMode === "english") return (["one","two","three","four","five","six","seven","eight","nine","ten"])[index]
                                    if (barSettings.centerMode === "numbers") return (["1","2","3","4","5","6","7","8","9","10"])[index]
                                    return (["一","二","三","四","五","六","七","八","九","十"])[index]
                                }

                                visible: ws !== null || isActive
                                width:   visible ? Math.round(fm.advanceWidth(txt)) + 16 : 0
                                height:  parent.height

                                Rectangle {
                                    anchors.fill: parent
                                    color: parent.isUrgent ? configRoot.colors.colors.color1 
                                         : parent.isActive ? configRoot.colors.special.foreground 
                                         : parent.hovered  ? configRoot.colors.colors.color8 
                                         : "transparent"
                                }
                                MText {
                                    anchors.centerIn: parent
                                    color: parent.isUrgent ? configRoot.colors.special.background 
                                         : parent.isActive ? configRoot.colors.special.background 
                                         : parent.hovered  ? configRoot.colors.special.foreground 
                                         : configRoot.colors.colors.color7 
                                    text: parent.txt
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

                    Row {
                        spacing: 0
                        Layout.fillHeight: true
                        visible: barSettings.centerMode === "pile"

                        Repeater {
                            model: ["file", "edit", "view", "special"]

                            Item {
                                width: Math.round(fm.advanceWidth(modelData)) + 16
                                height: parent.height

                                Rectangle {
                                    anchors.fill: parent
                                    color: pileArea.containsMouse ? configRoot.colors.colors.color8 : "transparent"
                                }

                                MText {
                                    anchors.centerIn: parent
                                    color: pileArea.containsMouse ? configRoot.colors.special.foreground : configRoot.colors.colors.color7
                                    text: modelData
                                }

                                MouseArea {
                                    id: pileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {}
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

                            MText {
                                Layout.alignment: Qt.AlignVCenter
                                color: configRoot.colors.colors.color7
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
                                color: configRoot.colors.special.foreground
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

                            MText {
                                Layout.alignment:   Qt.AlignVCenter
                                Layout.rightMargin: 4
                                color: configRoot.colors.colors.color7
                                visible: root.activeMode === "launcher" ? root.launcherTopApp !== null : (root.activeMode === "master" ? root.masterFiltered.length > 0 : false)
                                text: root.activeMode === "launcher" ? (root.launcherTopApp?.name ?? "") : (root.activeMode === "master" && root.masterSelected < root.masterFiltered.length ? (root.masterFiltered[root.masterSelected]?.label ?? "") : "")
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        implicitWidth: 16

                        Row {
                            anchors.centerIn: parent

                            Item {
                                width: 16
                                height: 22

                                MText {
                                    anchors.centerIn: parent
                                    text: "^"
                                    color: configRoot.colors.special.foreground
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (root.activeMode === "tray") root.activeMode = "none"
                                        else root.activeMode = "tray"
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        implicitWidth: 16
                        Layout.rightMargin: 6

                        Row {
                            anchors.centerIn: parent

                            Item {
                                width: 16
                                height: 22

                                MText {
                                    id: micText
                                    anchors.centerIn: parent
                                    text: root.micState
                                    color: configRoot.colors.special.foreground
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
                        implicitWidth: 36
                        visible: ${if isbed then "true" else "false"}

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            spacing: 2

                            Item {
                                width: 28
                                height: 22

                                MText {
                                    id: batText
                                    anchors.centerIn: parent
                                    text: root.batState
                                    color: configRoot.colors.special.foreground
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
                            color: configRoot.colors.colors.color8
                        }
                        MText {
                            id: clockText
                            anchors.centerIn:   parent
                            font.letterSpacing: 0.02 * 11
                            color: configRoot.colors.special.foreground
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

        OverlayPanel {
            id: masterOverlay
            visible: root.activeMode === "master" && root.masterFiltered.length > 0
            fullWidth: true

            implicitWidth:  root.implicitWidth
            implicitHeight: root.masterFiltered.length * (root.masterLevel === "wallpapers" ? 38 : 22)

            MouseArea {
                anchors.fill: parent
                onClicked:    root.masterClose()
            }

            Rectangle {
                width:  root.implicitWidth
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                color: configRoot.colors.special.background

                Column {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width

                    Repeater {
                        model: root.masterFiltered

                        Rectangle {
                            width:  parent.width
                            height: root.masterLevel === "wallpapers" ? 38 : 22
                            color:  root.masterSelected === index ? configRoot.colors.colors.color8 : "transparent"

                            Image {
                                visible: root.masterLevel === "wallpapers"
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46; height: 26
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: visible ? "file://${config.home.homeDirectory}/${wpdir}/" + modelData.wp : ""
                            }

                            Rectangle {
                                visible:                root.masterSelected === index
                                anchors.left:           parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2; height: root.masterLevel === "wallpapers" ? 22 : 12
                                color: configRoot.colors.colors.color4
                            }

                            MText {
                                anchors.verticalCenter: parent.verticalCenter
                                x:                      root.masterLevel === "wallpapers" ? 64 : 14
                                text:                   modelData?.label ?? ""
                                color: root.masterSelected === index ? configRoot.colors.special.foreground : configRoot.colors.colors.color7
                            }

                            MText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right:          parent.right
                                anchors.rightMargin:    12
                                visible:                modelData?.sub !== undefined
                                text:                   "›"
                                color: root.masterSelected === index ? configRoot.colors.special.foreground : configRoot.colors.colors.color8
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

        OverlayPanel {
            id: notifOverlay
            visible: notifModel.count > 0
            fullWidth: true

            implicitWidth:  Math.round(root.implicitWidth / 3)
            implicitHeight: notifModel.count * 34

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
                        color: configRoot.colors.special.background
                        clip: true

                        Rectangle {
                            visible: index > 0
                            anchors.top: parent.top
                            width: parent.width; height: 1
                            color: configRoot.colors.colors.color8
                        }

                        Rectangle {
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: 18
                            color: configRoot.colors.colors.color3
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.leftMargin:     12
                            anchors.rightMargin:    10
                            spacing: 2

                            MText {
                                width:          parent.width
                                text:           model.summary !== "" ? model.summary : (model.app !== "" ? model.app : "notification")
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          configRoot.colors.special.foreground
                                elide:          Text.ElideRight
                                maximumLineCount: 1
                            }

                            MText {
                                visible:        model.body !== ""
                                width:          parent.width
                                text:           model.body
                                font.pixelSize: 10
                                color:          configRoot.colors.colors.color7
                                elide:          Text.ElideRight
                                maximumLineCount: 1
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

        OverlayPanel {
            id: trayOverlay
            visible: root.activeMode === "tray"
            keyboardExclusive: true

            implicitWidth: 210
            implicitHeight: 70

            onVisibleChanged: {
                if (visible) trayBox.forceActiveFocus()
            }

            Rectangle {
                id: trayBox
                anchors.fill: parent
                color: configRoot.colors.special.background
                border.color: configRoot.colors.colors.color8
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
                    anchors.margins: 8
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            MText {
                                Layout.preferredWidth: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: root.wifiState
                                color: configRoot.colors.special.foreground
                            }
                            MText {
                                Layout.fillWidth: true
                                text: root.wifiConnectedSSID !== "" ? root.wifiConnectedSSID : "wifi disconnected"
                                color: configRoot.colors.special.foreground
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.activeMode = "none"
                                root.wifiOpen()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: configRoot.colors.colors.color8
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            MText {
                                Layout.preferredWidth: 16
                                horizontalAlignment: Text.AlignHCenter
                                text: root.btState
                                color: configRoot.colors.special.foreground
                            }
                            MText {
                                Layout.fillWidth: true
                                text: root.btConnectedName !== "" ? root.btConnectedName : (root.btPowered ? "bluetooth ready" : "bluetooth off")
                                color: configRoot.colors.special.foreground
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.activeMode = "none"
                                root.btOpen()
                            }
                        }
                    }
                }
            }
        }

        OverlayPanel {
            id: bluetoothOverlay
            visible: root.activeMode === "bluetooth"
            keyboardExclusive: true

            implicitWidth: 240
            implicitHeight: Math.min(240, (root.btDevices.length * 26) + 40)

            onVisibleChanged: {
                if (visible) {
                    root.btSelectedIndex = root.btDevices.length > 0 ? 0 : -1
                    btBox.forceActiveFocus()
                } else {
                    btRefreshTimer.stop()
                }
            }

            Timer {
                id: btRefreshTimer
                interval: 15000
                repeat: true
                running: bluetoothOverlay.visible
                onTriggered: if (!btListProc.running) btListProc.running = true
            }

            function activate(dev) {
                if (dev.connected) {
                    btConnectProc.command = ["${pkgs.bluez}/bin/bluetoothctl", "disconnect", dev.mac]
                } else {
                    btConnectProc.command = ["${pkgs.bluez}/bin/bluetoothctl", "connect", dev.mac]
                }
                btConnectProc.running = true
            }

            Rectangle {
                id: btBox
                anchors.fill: parent
                color: configRoot.colors.special.background
                border.color: configRoot.colors.colors.color8
                border.width: 1
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.activeMode = "none"
                        event.accepted = true
                    } else if (!btConnectProc.running) {
                        if (event.key === Qt.Key_Down) {
                            if (root.btDevices.length > 0)
                                root.btSelectedIndex = (root.btSelectedIndex + 1) % root.btDevices.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.btDevices.length > 0)
                                root.btSelectedIndex = (root.btSelectedIndex - 1 + root.btDevices.length) % root.btDevices.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.btSelectedIndex >= 0 && root.btSelectedIndex < root.btDevices.length)
                                bluetoothOverlay.activate(root.btDevices[root.btSelectedIndex])
                            event.accepted = true
                        } else if (event.key === Qt.Key_R) {
                            if (!btListProc.running) btListProc.running = true
                            event.accepted = true
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        MText {
                            Layout.fillWidth: true
                            text: btConnectProc.running
                                  ? "connecting..."
                                  : (root.btConnectedName !== "" ? root.btConnectedName : "disconnected")
                            color: btConnectProc.running ? configRoot.colors.colors.color3
                                 : root.btConnectedName !== "" ? configRoot.colors.colors.color2
                                 : configRoot.colors.special.foreground
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        MText {
                            text: root.btPowered ? "on" : "off"
                            color: btToggleMouse.containsMouse ? configRoot.colors.special.foreground : configRoot.colors.colors.color7

                            MouseArea {
                                id: btToggleMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                onClicked: {
                                    btToggleProc.command = ["${pkgs.bash}/bin/bash", "-c", root.btPowered ? "${pkgs.bluez}/bin/bluetoothctl power off" : "${pkgs.bluez}/bin/bluetoothctl power on"]
                                    btToggleProc.running = true
                                    root.btPowered = !root.btPowered
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: configRoot.colors.colors.color8
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.btDevices
                        enabled: !btConnectProc.running

                        delegate: Rectangle {
                            width: parent ? parent.width : 224
                            height: 24
                            color: index === root.btSelectedIndex
                                   ? configRoot.colors.colors.color8
                                   : (btMouse.containsMouse ? configRoot.colors.colors.color8 : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4

                                MText {
                                    text: modelData.connected ? "*" : " "
                                    color: configRoot.colors.colors.color2
                                }

                                MText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: configRoot.colors.special.foreground
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: btMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.btSelectedIndex = index
                                    bluetoothOverlay.activate(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        OverlayPanel {
            id: wifiOverlay
            visible: root.activeMode === "wifi"
            keyboardExclusive: true

            implicitWidth: 240
            implicitHeight: Math.min(240, (root.wifiNetworks.length * 26) + 40 + (root.wifiConnectError !== "" ? 16 : 0))

            property string selectedSsid: ""

            onVisibleChanged: {
                if (visible) {
                    selectedSsid = ""
                    root.wifiConnectError = ""
                    root.wifiSelectedIndex = root.wifiNetworks.length > 0 ? 0 : -1
                    wifiBox.forceActiveFocus()
                } else {
                    wifiRefreshTimer.stop()
                }
            }

            Timer {
                id: wifiRefreshTimer
                interval: 15000
                repeat: true
                running: wifiOverlay.visible && wifiOverlay.selectedSsid === ""
                onTriggered: if (!wifiListProc.running) wifiListProc.running = true
            }

            function connectTo(ssid, password) {
                let cmd = "${pkgs.networkmanager}/bin/nmcli dev wifi connect \"" + ssid + "\""
                if (password !== undefined) cmd += " password \"" + password + "\""
                wifiConnectProc.command = ["${pkgs.bash}/bin/bash", "-c", cmd]
                wifiConnectProc.running = true
            }

            function disconnect() {
                wifiConnectProc.command = ["${pkgs.networkmanager}/bin/nmcli", "con", "down", "id", root.wifiConnectedSSID]
                wifiConnectProc.running = true
            }

            function activate(net) {
                if (net.connected) {
                    wifiOverlay.disconnect()
                } else if (net.sec.trim() !== "") {
                    wifiOverlay.selectedSsid = net.label
                    wifiPasswordInput.text = ""
                    root.wifiConnectError = ""
                    wifiPasswordInput.forceActiveFocus()
                } else {
                    root.wifiConnectError = ""
                    wifiOverlay.connectTo(net.label)
                }
            }

            Rectangle {
                id: wifiBox
                anchors.fill: parent
                color: configRoot.colors.special.background
                border.color: configRoot.colors.colors.color8
                border.width: 1
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (wifiOverlay.selectedSsid !== "") {
                            wifiOverlay.selectedSsid = ""
                            wifiBox.forceActiveFocus()
                        } else {
                            root.activeMode = "none"
                        }
                        event.accepted = true
                    } else if (wifiOverlay.selectedSsid === "" && !wifiConnectProc.running) {
                        if (event.key === Qt.Key_Down) {
                            if (root.wifiNetworks.length > 0)
                                root.wifiSelectedIndex = (root.wifiSelectedIndex + 1) % root.wifiNetworks.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (root.wifiNetworks.length > 0)
                                root.wifiSelectedIndex = (root.wifiSelectedIndex - 1 + root.wifiNetworks.length) % root.wifiNetworks.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.wifiSelectedIndex >= 0 && root.wifiSelectedIndex < root.wifiNetworks.length)
                                wifiOverlay.activate(root.wifiNetworks[root.wifiSelectedIndex])
                            event.accepted = true
                        } else if (event.key === Qt.Key_R) {
                            if (!wifiListProc.running) wifiListProc.running = true
                            event.accepted = true
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        MText {
                            Layout.fillWidth: true
                            text: root.wifiConnecting
                                  ? "connecting..."
                                  : (root.wifiConnectedSSID !== "" ? root.wifiConnectedSSID : "disconnected")
                            color: root.wifiConnecting ? configRoot.colors.colors.color3
                                 : root.wifiConnectedSSID !== "" ? configRoot.colors.colors.color2
                                 : configRoot.colors.special.foreground
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        MText {
                            text: root.wifiRadioEnabled ? "on" : "off"
                            color: wifiToggleMouse.containsMouse ? configRoot.colors.special.foreground : configRoot.colors.colors.color7

                            MouseArea {
                                id: wifiToggleMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                onClicked: {
                                    wifiToggleProc.command = ["${pkgs.bash}/bin/bash", "-c", root.wifiRadioEnabled ? "${pkgs.networkmanager}/bin/nmcli radio wifi off" : "${pkgs.networkmanager}/bin/nmcli radio wifi on"]
                                    wifiToggleProc.running = true
                                    root.wifiRadioEnabled = !root.wifiRadioEnabled
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: configRoot.colors.colors.color8
                    }

                    MText {
                        Layout.fillWidth: true
                        visible: root.wifiConnectError !== ""
                        text: root.wifiConnectError
                        color: configRoot.colors.colors.color1
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.wifiNetworks
                        visible: wifiOverlay.selectedSsid === ""
                        enabled: !wifiConnectProc.running

                        delegate: Rectangle {
                            width: parent ? parent.width : 224
                            height: 24
                            color: index === root.wifiSelectedIndex
                                   ? configRoot.colors.colors.color8
                                   : (wifiMouse.containsMouse ? configRoot.colors.colors.color8 : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4

                                MText {
                                    text: modelData.connected ? "*" : " "
                                    color: configRoot.colors.colors.color2
                                }

                                MText {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: configRoot.colors.special.foreground
                                    elide: Text.ElideRight
                                }

                                MText {
                                    text: modelData.sec + " " + modelData.signal + "%"
                                    color: modelData.signal >= 70 ? configRoot.colors.colors.color2
                                         : modelData.signal >= 40 ? configRoot.colors.colors.color3
                                         : configRoot.colors.colors.color1
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: wifiMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.wifiSelectedIndex = index
                                    wifiOverlay.activate(modelData)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: wifiOverlay.selectedSsid !== ""
                        spacing: 6

                        MText {
                            text: wifiOverlay.selectedSsid
                            color: configRoot.colors.special.foreground
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: configRoot.colors.colors.color0
                            border.color: wifiPasswordInput.activeFocus ? configRoot.colors.colors.color4 : configRoot.colors.colors.color8
                            border.width: 1

                            TextInput {
                                id: wifiPasswordInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: configRoot.colors.special.foreground
                                echoMode: TextInput.Password
                                passwordCharacter: "*"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                enabled: !wifiConnectProc.running

                                onAccepted: wifiOverlay.connectTo(wifiOverlay.selectedSsid, text)
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        OverlayPanel {
            id: calendarOverlay
            visible: root.activeMode === "calendar"
            keyboardExclusive: true

            implicitWidth: 216
            implicitHeight: 186

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
                color: configRoot.colors.special.background
                border.color: configRoot.colors.colors.color8
                border.width: 1
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        root.activeMode = "none"
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        calendarOverlay.prevMonth()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        calendarOverlay.nextMonth()
                        event.accepted = true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        MText {
                            text: calendarOverlay.title
                            color: configRoot.colors.special.foreground
                        }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: 12

                            MText {
                                text: "<"
                                color: prevMouse.containsMouse ? configRoot.colors.special.foreground : configRoot.colors.colors.color7
                                MouseArea {
                                    id: prevMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: calendarOverlay.prevMonth()
                                }
                            }

                            MText {
                                text: ">"
                                color: nextMouse.containsMouse ? configRoot.colors.special.foreground : configRoot.colors.colors.color7
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
                            MText {
                                width: 22; height: 14
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: configRoot.colors.colors.color4
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

                                color: modelData.today ? configRoot.colors.special.foreground : (isHovered ? configRoot.colors.colors.color8 : "transparent")

                                MText {
                                    anchors.centerIn: parent
                                    text: modelData.d
                                    color: modelData.today ? configRoot.colors.special.background 
                                         : (isHovered ? configRoot.colors.special.foreground 
                                         : (modelData.cur ? configRoot.colors.special.foreground : configRoot.colors.colors.color8))
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
