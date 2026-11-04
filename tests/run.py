#!/usr/bin/env python3
"""Runs the Luau tests in tests/*.test.luau with the plain `luau` CLI.

The CLI cannot read files at run time, so each test is bundled with
tests/shim.luau (Roblox datatype stand-ins), a small module loader and the
source of every module it may require (src/shared/*.luau, the client Traffic
controller and the server Router). Inside a test, `load("Config")` returns a module.

Usage: python3 tests/run.py [path/to/luau]
"""
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"

MODULES = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(os.path.join(ROOT, "src/shared/*.luau"))}
MODULES["Traffic"] = os.path.join(ROOT, "src/client/Controllers/Traffic.luau")
MODULES["Router"] = os.path.join(ROOT, "src/server/Router.luau")


def module_source(name, path):
    src = open(path, encoding="utf-8").read()
    # Types may not be exported from inside a function.
    src = "\n".join(line[len("export "):] if line.startswith("export type") else line for line in src.splitlines())
    return f"MODULES[{name!r}] = function(script, require)\n{src}\nend\n"


def bundle(test_path):
    parts = [open(os.path.join(ROOT, "tests/shim.luau"), encoding="utf-8").read()]
    parts.append(open(os.path.join(ROOT, "tests/loader.luau"), encoding="utf-8").read())
    for name, path in sorted(MODULES.items()):
        parts.append(module_source(name, path))
    parts.append(open(test_path, encoding="utf-8").read())
    return "\n".join(parts)


def main():
    failed = 0
    tests = sorted(glob.glob(os.path.join(ROOT, "tests/*.test.luau")))
    out_dir = os.path.join(ROOT, "tests/.build")
    os.makedirs(out_dir, exist_ok=True)
    for test in tests:
        name = os.path.basename(test)
        bundled = os.path.join(out_dir, name)
        with open(bundled, "w", encoding="utf-8") as f:
            f.write(bundle(test))
        result = subprocess.run([LUAU, bundled], capture_output=True, text=True)
        ok = result.returncode == 0 and "FAIL" not in result.stdout
        print(("PASS " if ok else "FAIL ") + name)
        if result.stdout.strip():
            print("  " + result.stdout.strip().replace("\n", "\n  "))
        if not ok:
            failed += 1
            print("  " + result.stderr.strip().replace("\n", "\n  "))
    print(f"{len(tests) - failed}/{len(tests)} test files passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
