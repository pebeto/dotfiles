pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Answers for the launcher's "?": the local LLM server when it's serving a
// model (services/Llm.qml), Claude Code otherwise. Either way the reply
// streams in as it's written, at medium effort like every other client
// (Claude Code's default took ten times as long on a one-line answer).
// Claude Code runs without tools or MCP servers, so a question can't make
// it touch anything.
Singleton {
    id: root

    readonly property string prompt: "You answer questions typed into a desktop launcher. Be brief: a few sentences or a short list, in Markdown."
    // Sent the way omp and opencode send them (.config/omp/models.yml).
    readonly property var sampling: ({
            "qwen3.8-27b": {
                temperature: 1.0,
                top_p: 0.95,
                top_k: 20,
                chat_template_kwargs: {
                    reasoning_effort: "medium"
                }
            },
            "gpt-oss-20b": {
                temperature: 1.0,
                top_p: 1.0,
                reasoning_effort: "medium"
            }
        })

    // Who answers a question asked now.
    readonly property string answerer: Llm.state === "ready" ? Llm.served : "Claude"
    property string question: ""
    property string by: ""
    property string answer: ""
    property string error: ""
    property bool busy: false
    // Reasoning came in, but no answer yet.
    property bool thinking: false

    function ask(q) {
        cancel();
        question = q;
        by = answerer;
        answer = "";
        error = "";
        thinking = false;
        busy = true;
        if (by === "Claude") {
            claude.running = true;
        } else {
            const body = Object.assign({
                model: by,
                stream: true,
                max_tokens: 4096,
                messages: [
                    {
                        role: "system",
                        content: prompt
                    },
                    {
                        role: "user",
                        content: q
                    }
                ]
            }, sampling[by] ?? {});
            local.command = ["curl", "-sN", "--fail-with-body", Llm.url + "/v1/chat/completions", "-H", "Content-Type: application/json", "-d", JSON.stringify(body)];
            local.running = true;
        }
    }

    function cancel() {
        for (const p of [local, claude]) {
            if (p.running) {
                p.dropped = true;
                p.running = false;
            }
        }
        busy = false;
        thinking = false;
    }

    function reset() {
        cancel();
        question = "";
        answer = "";
        error = "";
    }

    // OpenAI-style server-sent events: "data: {json}" lines, then
    // "data: [DONE]".
    Process {
        id: local

        // Killed by cancel(), so its exit says nothing about the next run.
        property bool dropped: false

        // Events are separated by blank lines, and SplitParser leaves the
        // second newline on the next one.
        stdout: SplitParser {
            onRead: raw => {
                const line = raw.trim();
                // A failed request answers with a plain JSON error.
                if (!line.startsWith("data: ")) {
                    if (line)
                        root.error = line;
                    return;
                }
                if (line === "data: [DONE]")
                    return;
                try {
                    const delta = JSON.parse(line.slice(6)).choices?.[0]?.delta ?? {};
                    if (delta.content) {
                        root.answer += delta.content;
                        root.thinking = false;
                    } else if (delta.reasoning_content || delta.reasoning)
                        root.thinking = true;
                } catch (e) {
                    root.error = line.slice(6);
                }
            }
        }
        onExited: code => {
            if (dropped) {
                dropped = false;
                return;
            }
            if (code !== 0 && root.answer === "" && root.error === "")
                root.error = "The local server didn't answer (curl exited with " + code + ")";
            root.busy = false;
            root.thinking = false;
        }
    }

    // stream-json with partial messages: text arrives as text_delta events,
    // and a final "result" says whether it worked.
    Process {
        id: claude

        property bool dropped: false

        workingDirectory: Quickshell.env("HOME")
        command: ["sh", "-c", "printf '%s' \"$1\" | claude -p --effort medium --output-format stream-json --include-partial-messages --verbose --tools '' --strict-mcp-config --no-session-persistence --append-system-prompt \"$2\"", "sh", root.question, root.prompt]
        stdout: SplitParser {
            onRead: line => {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const delta = m.type === "stream_event" ? m.event?.delta : null;
                if (delta?.type === "text_delta") {
                    root.answer += delta.text;
                    root.thinking = false;
                } else if (delta?.type === "thinking_delta") {
                    root.thinking = true;
                } else if (m.type === "result" && m.is_error) {
                    root.error = m.result || "Claude Code reported an error";
                }
            }
        }
        onExited: code => {
            if (dropped) {
                dropped = false;
                return;
            }
            if (code !== 0 && root.answer === "" && root.error === "")
                root.error = "Claude Code exited with " + code;
            root.busy = false;
            root.thinking = false;
        }
    }
}
