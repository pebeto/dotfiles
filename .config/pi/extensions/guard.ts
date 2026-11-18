import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// Hard limits for the model's bash calls, from the rules in AGENTS.md. pi has no permission
// system, so these are the only ones enforced. They parse ordinary commands, not every shell
// construct, so they are a guardrail and not a sandbox. The user's own `!` commands are not
// checked.

const GIT_READ_ONLY = new Set([
	"status", "log", "diff", "show", "blame", "grep", "ls-files", "ls-tree", "rev-parse",
	"describe", "shortlog", "reflog", "cat-file", "merge-base", "rev-list", "name-rev",
	"check-ignore", "fetch", "help", "version", "var", "whatchanged", "show-ref", "for-each-ref",
]);
const BRANCH_WRITE = new Set(["-d", "-D", "--delete", "-m", "-M", "--move", "-c", "-C", "--copy", "-u", "--set-upstream-to", "--unset-upstream", "--edit-description", "-f", "--force"]);
const TAG_WRITE = new Set(["-d", "--delete", "-a", "--annotate", "-s", "--sign", "-f", "--force", "-m", "-F"]);
const CONFIG_WRITE = new Set(["--add", "--unset", "--unset-all", "--replace-all", "--rename-section", "--remove-section", "-e", "--edit"]);

const REASONS = {
	git: "Jose runs every git operation that changes the repository himself. Tell him the exact command instead of running it.",
	sudo: "sudo needs Jose's password and would hang. Tell him the command to run with `! <command>`.",
	pkill: "Killing by process name can hit Jose's sway session (sway, foot, woverview). Kill test processes by the PID you saved when starting them.",
	pgrep: "Looking up PIDs by name can hit Jose's sway session. Kill test processes by the PID you saved when starting them.",
	sway: "That would end Jose's sway session.",
	rmVar: "rm paths must be written out literally, never built from shell variables. Expand the path yourself and check it first.",
	rmBroad: "That rm target is too broad. Name the files or directories explicitly.",
	docker: "The GPU's vLLM server runs in Docker. Ask Jose before stopping or changing containers.",
	llm: "That would stop the local LLM server. Ask Jose first.",
};

// Split a command line into simple commands at control operators and command substitutions.
export function segments(command: string): string[][] {
	return command
		.replace(/\$\(|`|\)/g, "\n")
		.split(/&&|\|\||[;|&\n]/)
		.map((part) => part.trim().split(/\s+/).filter(Boolean))
		.filter((words) => words.length > 0);
}

// Drop env assignments and wrappers such as `timeout 60` or `xargs -0` to reach the real command.
function unwrap(words: string[]): string[] {
	let w = words;
	for (;;) {
		while (w.length && /^\w+=/.test(w[0])) w = w.slice(1);
		const name = (w[0] ?? "").split("/").pop();
		if (["command", "exec", "nohup", "time", "env", "stdbuf"].includes(name ?? "")) {
			w = w.slice(1);
			while (w.length && w[0].startsWith("-")) w = w.slice(1);
		} else if (name === "timeout" || name === "nice" || name === "ionice" || name === "xargs") {
			w = w.slice(1);
			while (w.length && w[0].startsWith("-")) w = w.slice(["-n", "-s", "-k", "-I", "-P", "-L", "-d", "-c"].includes(w[0]) ? 2 : 1);
			if (name === "timeout") w = w.slice(1);
		} else {
			return w;
		}
	}
}

function gitWrites(args: string[]): boolean {
	let i = 0;
	while (i < args.length && args[i].startsWith("-")) {
		i += ["-C", "-c", "--git-dir", "--work-tree", "--namespace"].includes(args[i]) ? 2 : 1;
	}
	const sub = args[i];
	const rest = args.slice(i + 1);
	const positional = rest.filter((a) => !a.startsWith("-"));
	if (!sub || GIT_READ_ONLY.has(sub)) return false;
	switch (sub) {
		case "branch":
			return rest.some((a) => BRANCH_WRITE.has(a)) || (positional.length > 0 && !rest.some((a) => ["-l", "--list", "--contains", "--merged", "--no-merged", "--points-at"].includes(a)));
		case "tag":
			return rest.some((a) => TAG_WRITE.has(a)) || (positional.length > 0 && !rest.some((a) => ["-l", "--list", "--contains", "--points-at"].includes(a)));
		case "remote":
			return !(rest.length === 0 || ["-v", "--verbose", "show", "get-url"].includes(rest[0]));
		case "stash":
			return !["list", "show"].includes(rest[0] ?? "");
		case "worktree":
			return rest[0] !== "list";
		case "config":
			return rest.some((a) => CONFIG_WRITE.has(a)) || (positional.length > 1 && !rest.some((a) => a.startsWith("--get")));
		default:
			return true;
	}
}

function checkWords(raw: string[], full: string): string | undefined {
	const words = unwrap(raw);
	const [cmd, ...args] = words;
	if (!cmd) return undefined;
	const name = cmd.split("/").pop() ?? cmd;

	if (["bash", "sh", "zsh", "dash"].includes(name)) {
		const i = args.indexOf("-c");
		if (i >= 0 && args[i + 1]) return check(args.slice(i + 1).join(" ").replace(/^['"]|['"]$/g, ""));
		return undefined;
	}
	if (name === "sudo" || name === "doas" || name === "pkexec") return REASONS.sudo;
	if (name === "git") return gitWrites(args) ? REASONS.git : undefined;
	if (name === "pkill" || name === "killall") return REASONS.pkill;
	if (name === "kill" && /\b(pgrep|pidof)\b/.test(full)) return REASONS.pgrep;
	if (name === "swaymsg" && args.includes("exit")) return REASONS.sway;
	if (name === "rm") {
		const targets = args.filter((a) => !a.startsWith("-"));
		if (targets.some((t) => t.includes("$"))) return REASONS.rmVar;
		if (targets.some((t) => ["/", "/*", "~", "~/", "~/*", ".", "..", "*", "./*"].includes(t.replace(/^['"]|['"]$/g, "")))) return REASONS.rmBroad;
	}
	if (name === "docker" && /^(stop|kill|rm|restart|pause)$/.test(args[0] ?? "")) return REASONS.docker;
	if (name === "systemctl" && args.some((a) => /^(stop|restart|kill|disable)$/.test(a)) && args.some((a) => a.startsWith("llm-"))) return REASONS.llm;
	return undefined;
}

export function check(command: string): string | undefined {
	for (const words of segments(command)) {
		const reason = checkWords(words, command);
		if (reason) return reason;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (!isToolCallEventType("bash", event)) return;
		const reason = check(event.input.command);
		if (reason) return { block: true, reason };
	});
}
