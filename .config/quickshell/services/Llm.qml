pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The local LLM server (.config/llm/run.sh: vLLM in Docker on port 8000), for
// the workstation's bar block and panel. It's "ready" when the OpenAI
// endpoint answers, "starting" while its container is up (or run.sh is
// waiting for VRAM) but vLLM isn't, "stopping" after a stop until the
// container is gone, and "off" otherwise.
//
// Start runs run.sh as a transient systemd user unit, llm-<model>, so it
// keeps going in the background with its log in the journal. Stop is a
// `docker stop`, which also ends a server started from a terminal with
// `llm <model>`. Asking for another model while one runs stops it first.
// The model a container is loading comes from its --served-model-name, so
// one started from a terminal shows up too.
Singleton {
    id: root

    readonly property string url: "http://127.0.0.1:8000"
    readonly property string runSh: Quickshell.env("HOME") + "/.config/llm/run.sh"
    property var models: []
    property string state: "off"
    property string served: ""
    property string container: ""
    // A model asked for and not yet ready, and one to start once the
    // current server is down.
    property string starting: ""
    property string next: ""
    // When start() last ran: the unit can take a moment to appear, and
    // until then a poll would find nothing running.
    property real startedAt: 0
    property int requests: 0
    property int waiting: 0
    property real kvUsage: NaN
    property real tokensPerSecond: 0
    property real lastTokens: NaN
    property real lastPoll: 0

    function start(model) {
        if (state === "ready" || state === "starting" || state === "stopping") {
            next = model;
            stop();
            return;
        }
        starting = model;
        startedAt = Date.now();
        state = "starting";
        Quickshell.execDetached(["systemd-run", "--user", "--collect", "--unit=llm-" + model, runSh, model]);
        poll();
    }

    function stop() {
        if (container)
            Quickshell.execDetached(["docker", "stop", container]);
        else if (starting)
            Quickshell.execDetached(["systemctl", "--user", "stop", "llm-" + starting]);
        state = "stopping";
    }

    function showLog() {
        if (container)
            Quickshell.execDetached(["foot", "-e", "docker", "logs", "-f", "--tail", "300", container]);
        else if (starting)
            Quickshell.execDetached(["foot", "-e", "journalctl", "--user", "-fu", "llm-" + starting]);
    }

    function poll() {
        lister.running = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let id = "";
            try {
                id = JSON.parse(xhr.responseText).data[0].id;
            } catch (e) {}
            if (xhr.status === 200 && id) {
                root.served = id;
                if (root.state !== "stopping")
                    root.state = "ready";
                root.starting = "";
                root.readMetrics();
            } else {
                root.served = "";
                root.requests = 0;
                root.waiting = 0;
                root.tokensPerSecond = 0;
                root.kvUsage = NaN;
                root.lastTokens = NaN;
            }
        };
        xhr.open("GET", url + "/v1/models");
        xhr.timeout = 1500;
        xhr.send();
    }

    // Sums one metric over its label sets in Prometheus text.
    function metric(text, name) {
        let sum = NaN;
        for (const line of text.split("\n")) {
            if (!line.startsWith(name + "{") && !line.startsWith(name + " "))
                continue;
            const v = parseFloat(line.slice(line.lastIndexOf(" ") + 1));
            sum = (isNaN(sum) ? 0 : sum) + v;
        }
        return sum;
    }

    function readMetrics() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return;
            const t = xhr.responseText;
            root.requests = root.metric(t, "vllm:num_requests_running") || 0;
            root.waiting = root.metric(t, "vllm:num_requests_waiting") || 0;
            root.kvUsage = root.metric(t, "vllm:kv_cache_usage_perc");
            const tokens = root.metric(t, "vllm:generation_tokens_total");
            const now = Date.now();
            if (!isNaN(root.lastTokens) && now > root.lastPoll)
                root.tokensPerSecond = Math.max(0, (tokens - root.lastTokens) * 1000 / (now - root.lastPoll));
            root.lastTokens = tokens;
            root.lastPoll = now;
        };
        xhr.open("GET", url + "/metrics");
        xhr.timeout = 1500;
        xhr.send();
    }

    // The container publishing the port and the model it serves, if any,
    // and whether the unit of a model being started is still running
    // (run.sh may be waiting for VRAM before it creates the container).
    Process {
        id: lister

        command: ["sh", "-c", `id=$(docker ps -q --filter publish=8000 | head -1)
model=
[ -n "$id" ] && model=$(docker inspect -f '{{range .Args}}{{println .}}{{end}}' "$id" | grep -x -A1 -- --served-model-name | tail -n1)
unit=
[ -n "$1" ] && unit=$(systemctl --user is-active "llm-$1" 2>/dev/null)
printf '%s\\n%s\\n%s\\n' "$id" "$model" "$unit"`, "sh", root.starting]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim());
                root.container = lines[0] ?? "";
                const model = lines[1] ?? "";
                const unit = lines[2] ?? "";
                if (root.served)
                    return;
                if (root.container) {
                    if (root.state !== "stopping") {
                        root.state = "starting";
                        root.starting = model || root.starting;
                    }
                } else if (root.state !== "stopping" && root.starting && (unit === "active" || unit === "activating" || Date.now() - root.startedAt < 5000)) {
                    root.state = "starting";
                } else {
                    root.starting = "";
                    root.state = "off";
                    if (root.next) {
                        const m = root.next;
                        root.next = "";
                        root.start(m);
                    }
                }
            }
        }
    }

    Process {
        running: Theme.profile.llm
        command: [root.runSh, "--list"]
        stdout: StdioCollector {
            onStreamFinished: root.models = text.split("\n").map(s => s.trim()).filter(s => s)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: Theme.profile.llm
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
