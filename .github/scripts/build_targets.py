"""Select application builds; release/manual runs always build all artifacts."""
import json
import os
import subprocess
from pathlib import Path


def classify(paths):
    game = web = False
    for path in paths:
        if path in {"CREDITS.md", ".dockerignore", ".gitattributes", "compose.yaml"} or path.startswith((".github/workflows/", ".github/scripts/")):
            return True, True
        if path.endswith(".md"):
            continue
        if path.startswith("apps/game/"):
            game = True
        elif path.startswith(("apps/web/", "apps/api/")):
            web = True
        elif path.startswith("apps/"):
            return True, True
    return game, web


def select(event_name, ref, release, event):
    if release or ref.startswith("refs/tags/") or event_name not in {"push", "pull_request"}:
        return True, True
    if event_name == "pull_request":
        base = event["pull_request"]["base"]["sha"]
        head = event["pull_request"]["head"]["sha"]
        revision = [f"{base}...{head}"]
    else:
        base, head = event.get("before", ""), event.get("after", "")
        if not base or not head or set(base) == {"0"}:
            return True, True
        revision = [base, head]
    # Treat moves as a deletion and addition so moving across apps selects both.
    # Fail the job on missing history instead of silently omitting a build.
    paths = subprocess.check_output(["git", "diff", "--no-renames", "--name-only", "-z", *revision, "--"]).decode().split("\0")
    return classify(paths)


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    game, web = select(os.environ["GITHUB_EVENT_NAME"], os.environ["GITHUB_REF"], os.environ.get("DO_RELEASE_BUILD") == "true", event)
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"game={str(game).lower()}\nweb={str(web).lower()}\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f"## Build targets\n\n- Game clients and server: {game}\n- Website and API: {web}\n\nVue and Go tests must pass before any selected build.\n")


if __name__ == "__main__":
    main()
