import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";

// Desktop notification when a run finishes or an extension asks a question (plan mode's
// "what next?"). It sends OSC 777, which foot and Ghostty turn into a notification; foot
// skips it while its window has keyboard focus, so only an unattended terminal notifies.

// Model text goes inside an escape sequence, so control characters and the separator are
// stripped first.
function clean(text: string, max: number): string {
	const flat = text
		.replace(/[\x00-\x1f\x7f-\x9f]+/g, " ")
		.replace(/[*_`#>]+/g, "")
		.replace(/;/g, ",")
		.replace(/\s+/g, " ")
		.trim();
	return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat;
}

function lastAssistantText(messages: unknown[]): string | undefined {
	for (let i = messages.length - 1; i >= 0; i--) {
		const m = messages[i] as { role?: string; content?: unknown };
		if (m?.role !== "assistant") continue;
		const parts = Array.isArray(m.content) ? m.content : [{ type: "text", text: m.content }];
		const text = parts
			.filter((p: { type?: string; text?: unknown }) => p?.type === "text" && typeof p.text === "string")
			.map((p: { text: string }) => p.text)
			.join("\n")
			.split("\n")
			.find((line: string) => line.trim());
		if (text) return text;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	let summary: string | undefined;

	const notify = (cwd: string, body: string) => {
		process.stdout.write(`\x1b]777;notify;${clean(`pi · ${basename(cwd)}`, 60)};${clean(body, 140)}\x1b\\`);
	};

	pi.on("agent_end", async (event) => {
		summary = lastAssistantText(event.messages ?? []) ?? summary;
	});

	pi.on("agent_settled", async (event, ctx) => {
		if (ctx.mode !== "tui" || event.aborted) return;
		notify(ctx.cwd, summary ?? "Ready for input");
		summary = undefined;
	});

	pi.on("ui_prompt_start", async (event, ctx) => {
		if (ctx.mode !== "tui") return;
		notify(ctx.cwd, event.title ? `Waiting: ${event.title}` : "Waiting for your answer");
	});
}
