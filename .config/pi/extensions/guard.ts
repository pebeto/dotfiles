import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Hard limits for the model's bash calls, from the rules in AGENTS.md. pi has no permission
// system, so these are the only ones enforced. Commands are parsed the way the shell would
// split them: quoted text and heredoc bodies are data, while $(...), backticks, bash -c,
// eval and find -exec are checked as commands. It is still a guardrail and not a sandbox.
// The user's own `!` commands are not checked. Tests: bun test .config/pi/tests

const GIT_READ_ONLY = new Set([
	"status", "log", "diff", "show", "blame", "grep", "ls-files", "ls-tree", "rev-parse",
	"describe", "shortlog", "reflog", "cat-file", "merge-base", "rev-list", "name-rev",
	"check-ignore", "fetch", "help", "version", "var", "whatchanged", "show-ref", "for-each-ref",
]);
const BRANCH_WRITE = new Set(["-d", "-D", "--delete", "-m", "-M", "--move", "-c", "-C", "--copy", "-u", "--set-upstream-to", "--unset-upstream", "--edit-description", "-f", "--force"]);
const TAG_WRITE = new Set(["-d", "--delete", "-a", "--annotate", "-s", "--sign", "-f", "--force", "-m", "-F"]);
const CONFIG_WRITE = new Set(["--add", "--unset", "--unset-all", "--replace-all", "--rename-section", "--remove-section", "-e", "--edit"]);
const DOCKER_STOP = new Set(["stop", "kill", "rm", "rmi", "restart", "pause", "prune", "down"]);
const DOCKER_OBJECTS = new Set(["container", "compose", "image", "volume", "network", "system", "builder"]);
const RM_BROAD = new Set(["/", "/*", "~", "~/*", ".", "./*", "..", "../*", "*", ".*"]);
const RESERVED = new Set(["if", "then", "else", "elif", "do", "while", "until", "!", "{", "}"]);

const REASONS = {
	git: "Jose runs every git operation that changes the repository himself. Tell him the exact command instead of running it.",
	sudo: "sudo needs Jose's password and would hang. Tell him the command to run with `! <command>`.",
	pkill: "Killing by process name can hit Jose's sway session (sway, foot, woverview). Kill test processes by the PID you saved when starting them.",
	pgrep: "Looking up PIDs by name can hit Jose's sway session. Kill test processes by the PID you saved when starting them.",
	sway: "That would end Jose's sway session.",
	rmVar: "rm paths must be written out literally, never built from shell variables. Expand the path yourself and check it first.",
	rmBroad: "That rm target is too broad. Name the files or directories explicitly.",
	rmGit: "Deleting a .git directory destroys the repository's history. Ask Jose first.",
	uvInit: "uv init runs git init, and Jose runs every git operation himself. Use `uv init --vcs none`.",
	docker: "The GPU's vLLM server runs in Docker. Ask Jose before stopping or changing containers.",
	llm: "That would stop the local LLM server. Ask Jose first.",
};

export interface Parsed {
	// Simple commands, with quotes removed and redirections dropped.
	commands: string[][];
	// Command lines nested in $(...), backticks or <(...), checked separately.
	nested: string[];
}

// Index just past the `)` that closes a $( opened before `start`.
function closingParen(src: string, start: number): number {
	let depth = 1;
	let i = start;
	while (i < src.length) {
		const c = src[i];
		if (c === "\\") i += 2;
		else if (c === "'") i = (src.indexOf("'", i + 1) + 1) || src.length;
		else if (c === '"') {
			i++;
			while (i < src.length && src[i] !== '"') i += src[i] === "\\" ? 2 : 1;
			i++;
		} else {
			if (c === "(") depth++;
			else if (c === ")" && --depth === 0) return i + 1;
			i++;
		}
	}
	return src.length;
}

function closingBacktick(src: string, start: number): number {
	let i = start;
	while (i < src.length && src[i] !== "`") i += src[i] === "\\" ? 2 : 1;
	return Math.min(i + 1, src.length);
}

// Substitutions inside an unquoted heredoc body still run.
function substitutionsIn(text: string, nested: string[]) {
	for (let i = 0; i < text.length; i++) {
		if (text[i] === "\\") i++;
		else if (text.startsWith("$(", i)) {
			const end = closingParen(text, i + 2);
			nested.push(text.slice(i + 2, end - 1));
			i = end - 1;
		} else if (text[i] === "`") {
			const end = closingBacktick(text, i + 1);
			nested.push(text.slice(i + 1, end - 1));
			i = end - 1;
		}
	}
}

export function parse(src: string): Parsed {
	const commands: string[][] = [];
	const nested: string[] = [];
	const heredocs: { delim: string; strip: boolean; expand: boolean }[] = [];
	let words: string[] = [];
	let word = "";
	let inWord = false;
	let redirectTarget = false;

	const endWord = () => {
		if (inWord) {
			if (redirectTarget) redirectTarget = false;
			else words.push(word);
		}
		word = "";
		inWord = false;
	};
	const endCommand = () => {
		endWord();
		if (words.length) commands.push(words);
		words = [];
		redirectTarget = false;
	};
	const substitution = (from: number): number => {
		const end = closingParen(src, from);
		nested.push(src.slice(from, end - 1));
		word += "$()";
		inWord = true;
		return end;
	};

	let i = 0;
	while (i < src.length) {
		const c = src[i];
		if (c === "\\") {
			if (src[i + 1] !== "\n") {
				word += src[i + 1] ?? "";
				inWord = true;
			}
			i += 2;
		} else if (c === "'") {
			const end = src.indexOf("'", i + 1);
			word += src.slice(i + 1, end < 0 ? src.length : end);
			inWord = true;
			i = end < 0 ? src.length : end + 1;
		} else if (c === "$" && src[i + 1] === "'") {
			i++;
		} else if (c === '"') {
			inWord = true;
			i++;
			while (i < src.length && src[i] !== '"') {
				if (src[i] === "\\" && '"\\$`\n'.includes(src[i + 1] ?? "")) {
					word += src[i + 1];
					i += 2;
				} else if (src.startsWith("$(", i)) {
					i = substitution(i + 2);
				} else if (src[i] === "`") {
					const end = closingBacktick(src, i + 1);
					nested.push(src.slice(i + 1, end - 1));
					i = end;
				} else {
					word += src[i++];
				}
			}
			i++;
		} else if (src.startsWith("$(", i)) {
			i = substitution(i + 2);
		} else if (c === "`") {
			const end = closingBacktick(src, i + 1);
			nested.push(src.slice(i + 1, end - 1));
			word += "$()";
			inWord = true;
			i = end;
		} else if (c === "#" && !inWord) {
			while (i < src.length && src[i] !== "\n") i++;
		} else if (c === "\n") {
			endCommand();
			i++;
			for (const doc of heredocs) {
				const body: string[] = [];
				while (i < src.length) {
					let end = src.indexOf("\n", i);
					if (end < 0) end = src.length;
					const line = src.slice(i, end);
					i = end + 1;
					if ((doc.strip ? line.replace(/^\t+/, "") : line) === doc.delim) break;
					body.push(line);
				}
				if (doc.expand) substitutionsIn(body.join("\n"), nested);
			}
			heredocs.length = 0;
		} else if (c === " " || c === "\t") {
			endWord();
			i++;
		} else if ((c === "<" || c === ">") && src[i + 1] === "(") {
			endWord();
			i = substitution(i + 2);
		} else if (src.startsWith("<<<", i)) {
			endWord();
			redirectTarget = true;
			i += 3;
		} else if (src.startsWith("<<", i)) {
			endWord();
			let j = i + 2;
			const strip = src[j] === "-";
			if (strip) j++;
			while (src[j] === " " || src[j] === "\t") j++;
			const m = /^(\\?)(['"]?)([^\s'"<>;&|()]+)\2/.exec(src.slice(j));
			if (m) {
				heredocs.push({ delim: m[3], strip, expand: !m[1] && !m[2] });
				j += m[0].length;
			}
			i = j;
		} else if (c === "<" || c === ">" || (c === "&" && src[i + 1] === ">")) {
			if (inWord && /^\d+$/.test(word)) {
				word = "";
				inWord = false;
			} else {
				endWord();
			}
			i++;
			while (i < src.length && "<>&|".includes(src[i])) i++;
			redirectTarget = true;
		} else if (";&|()".includes(c)) {
			endCommand();
			i++;
		} else {
			word += c;
			inWord = true;
			i++;
		}
	}
	endCommand();
	return { commands, nested };
}

// Drop env assignments, reserved words and wrappers such as `timeout 60` or `xargs -0` to
// reach the real command.
function unwrap(words: string[]): string[] {
	let w = words;
	for (;;) {
		while (w.length && (/^\w+=/.test(w[0]) || RESERVED.has(w[0]))) w = w.slice(1);
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

function rmBroad(target: string): boolean {
	const t = target.length > 1 ? target.replace(/\/+$/, "") || "/" : target;
	return RM_BROAD.has(t);
}

function dockerStops(args: string[]): boolean {
	const positional = args.filter((a) => !a.startsWith("-"));
	if (DOCKER_STOP.has(positional[0] ?? "")) return true;
	return DOCKER_OBJECTS.has(positional[0] ?? "") && positional.slice(1).some((a) => DOCKER_STOP.has(a));
}

function checkWords(raw: string[], depth: number): string | undefined {
	const [cmd, ...args] = unwrap(raw);
	if (!cmd) return undefined;
	const name = cmd.split("/").pop() ?? cmd;

	if (["bash", "sh", "zsh", "dash"].includes(name)) {
		const i = args.findIndex((a) => /^-[a-z]*c[a-z]*$/.test(a));
		return i >= 0 && args[i + 1] !== undefined ? check(args[i + 1], depth + 1) : undefined;
	}
	if (name === "eval") return check(args.join(" "), depth + 1);
	if (name === "find") {
		for (let i = 0; i < args.length; i++) {
			if (!["-exec", "-execdir", "-ok", "-okdir"].includes(args[i])) continue;
			let end = i + 1;
			while (end < args.length && args[end] !== ";" && args[end] !== "+") end++;
			const reason = checkWords(args.slice(i + 1, end), depth + 1);
			if (reason) return reason;
			i = end;
		}
		return undefined;
	}
	if (name === "sudo" || name === "doas" || name === "pkexec") return REASONS.sudo;
	if (name === "git") return gitWrites(args) ? REASONS.git : undefined;
	if (name === "pkill" || name === "killall") return REASONS.pkill;
	if (name === "swaymsg" && args.includes("exit")) return REASONS.sway;
	if (name === "rm") {
		const dash = args.indexOf("--");
		const targets = args.filter((a, i) => (dash >= 0 && i > dash) || !a.startsWith("-"));
		if (targets.some((t) => t.includes("$"))) return REASONS.rmVar;
		if (targets.some(rmBroad)) return REASONS.rmBroad;
		if (targets.some((t) => /(^|\/)\.git\/*$/.test(t))) return REASONS.rmGit;
	}
	if (name === "uv" && args[0] === "init" && !args.some((a, i) => a === "--vcs=none" || (a === "--vcs" && args[i + 1] === "none"))) return REASONS.uvInit;
	if ((name === "docker" && dockerStops(args)) || (name === "docker-compose" && dockerStops(["compose", ...args]))) return REASONS.docker;
	if (name === "systemctl" && args.some((a) => /^(stop|restart|kill|disable)$/.test(a)) && args.some((a) => a.startsWith("llm-"))) return REASONS.llm;
	return undefined;
}

// Names of every command a line runs, nested ones included.
function commandNames(command: string, depth: number): string[] {
	if (depth > 8) return [];
	const { commands, nested } = parse(command);
	return [
		...commands.map((words) => (unwrap(words)[0] ?? "").split("/").pop() ?? ""),
		...nested.flatMap((inner) => commandNames(inner, depth + 1)),
	];
}

export function check(command: string, depth = 0): string | undefined {
	if (depth > 8) return undefined;
	const { commands, nested } = parse(command);
	for (const words of commands) {
		const reason = checkWords(words, depth);
		if (reason) return reason;
	}
	for (const inner of nested) {
		const reason = check(inner, depth + 1);
		if (reason) return reason;
	}
	const names = commandNames(command, depth);
	if (names.includes("kill") && names.some((n) => n === "pgrep" || n === "pidof")) return REASONS.pgrep;
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (event.toolName !== "bash") return;
		const reason = check(String((event.input as { command?: unknown }).command ?? ""));
		if (reason) return { block: true, reason };
	});
}
