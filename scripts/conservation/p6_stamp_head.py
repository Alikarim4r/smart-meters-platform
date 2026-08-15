from pathlib import Path
import re
import subprocess

# Resolved from this file's location: the previous hard-coded absolute path
# only existed on one machine, so the script could not run anywhere else.
root = Path(__file__).resolve().parents[2]
tip = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
p = root / "docs/conservation/PHASE_6_COMPLETION_REPORT.md"
t = p.read_text()
t = re.sub(
    r"(Exact `git rev-parse HEAD` \| `)[0-9a-f]{40}(`)",
    rf"\g<1>{tip}\2",
    t,
)
t = re.sub(
    r"(```text\ngit rev-parse HEAD\n)[0-9a-f]{40}(\n```)",
    rf"\g<1>{tip}\2",
    t,
)
p.write_text(t)
(root / "docs/conservation/PHASE_6_GIT_HEAD.txt").write_text(tip + "\n")
print(tip)
