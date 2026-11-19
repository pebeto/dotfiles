import { describe, expect, test } from "bun:test";
import { check } from "../extensions/guard.ts";

const BLOCK = [
	// git writes, also behind options, wrappers, quotes and escapes
	"git commit -m x", "git push", "git add .", "git checkout main", "git reset --hard", "git rebase main",
	"git clean -fd", "git init", "git -C sub commit", "git -c user.name=x commit", "git branch new",
	"git branch -D old", "git tag v1", "git remote add o url", "git stash", "git worktree add ../x",
	"git config user.name x", "cd x && git add .", "git status; git commit -am x", "FOO=1 git push",
	"timeout 60 git push", "timeout -k 10 60 git push", "env -i git push", "nohup git push",
	"xargs -0 git add", "command git push", "\\git push", '"git" commit -m x', "'git' push",
	"if git commit; then echo ok; fi", "{ git add .; }", "(git add .)",
	// commands nested in other commands
	'bash -c "echo hi && git commit"', "sh -c 'git push'", 'bash -lc "git push"', 'zsh -c "cd x; git add ."',
	'eval "git commit -m x"', "echo $(git commit -m x)", 'echo "$(git push)"', "echo `git push`",
	"diff <(git stash) b", "find . -name '*.py' -exec git add {} \\;", "find . -exec rm -rf $d {} +",
	"cat <<EOF > f\nbody\nEOF\ngit init", "cat <<EOF\n$(git push)\nEOF",
	// privilege, processes, session
	"sudo pacman -Syu", "doas ls", "pkexec ls", "pkill foot", "killall sway", "kill $(pgrep foot)",
	"pgrep foot | xargs kill", "kill `pidof sway`", "swaymsg exit", "swaymsg 'exit'",
	// rm
	"rm -rf $HOME/x", 'rm -rf "$dir"', "rm -rf ${d}", "rm $1", "rm -rf /", "rm -rf /*", "rm -rf ~",
	"rm -rf ~/", "rm -rf ~/*", "rm -rf .", "rm -rf ./", "rm -rf ..", "rm -rf ../", "rm -rf *", "rm -rf ./*",
	"rm -rf .*", "rm -f -- -x $y", "rm -rf .git", "rm -rf ./.git/", "rm -rf sub/.git",
	"uv init", "uv init --package", "cd x && uv init --lib",
	// docker and the llm units
	"docker stop vllm", "docker kill x", "docker rm x", "docker restart x", "docker pause x",
	"docker container stop x", "docker container rm x", "docker volume rm v", "docker network rm n",
	"docker system prune -f", "docker image rm vllm/vllm-openai", "docker rmi x", "docker compose down",
	"docker compose -f a.yml down", "docker-compose down", "systemctl --user stop llm-qwen3.8-27b",
	"systemctl --user restart llm-x",
];

const ALLOW = [
	// git reads
	"git status", "git log --oneline | head", "git diff HEAD~1", "git show HEAD", "git --no-pager log",
	"git -C sub status", "git fetch", "git branch", "git branch -l", "git branch --contains x", "git tag -l",
	"git remote -v", "git stash list", "git worktree list", "git config --get user.name", "git config -l",
	'bash -c "git status && echo ok"', 'bash -c "echo hi && git status"', "git log --grep='git push'",
	// dangerous words as data
	'echo "git push"', "echo 'git commit -m x'", "grep -nE 'vllm|llm-|rm |pkill|killall|sudo|git ' guard.ts",
	'python -c "import os; os.system(\'git init\')"', 'python -c "x = \\"git init\\""',
	"cat <<'EOF' > t.py\ngit init\nrm -rf $HOME\nsudo x\nEOF\npython t.py",
	"cat <<-EOF\n\tgit push\n\tEOF\necho ok", "cat <<EOF\nkill $$ is fine to write here\nEOF",
	"cat <<< 'git push'", "printf '%s\\n' 'pkill foot'", "kill 12345 # pgrep'd earlier",
	"echo it's && git init", "swaymsg reload", "swaymsg 'workspace 1'",
	// ordinary commands
	"kill 12345", "kill -TERM $pid", "pgrep -a vllm", "ls -la 2>&1 | head", "make >/dev/null 2>&1",
	"rm -rf build", "rm -f /tmp/x.log 2>/dev/null", "rm -rf ./build/", "rm -rf ~/.cache/llm-eval/runs/x",
	"find . -name '*.pyc' -delete", "find . -exec grep -l x {} +", "docker ps", "docker logs -f x",
	"docker exec x nvidia-smi", "docker images", "docker compose ps", "docker container ls",
	"systemctl --user status llm-x", "systemctl --user stop foo", "timeout 120 pytest -q",
	"uv run pytest", "uv init --vcs none", "uv init --package --vcs=none", "rm -f .gitignore",
	"rm -rf .github/old", "FOO=1 make test", "for f in *.py; do echo $f; done",
];

describe("blocked", () => {
	for (const command of BLOCK) test(JSON.stringify(command), () => expect(check(command)).toBeDefined());
});

describe("allowed", () => {
	for (const command of ALLOW) test(JSON.stringify(command), () => expect(check(command)).toBeUndefined());
});

test("the reason names what to do", () => {
	expect(check("git push")).toContain("Tell him the exact command");
	expect(check("kill $(pgrep foot)")).toContain("PID you saved");
});
