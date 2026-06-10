#!/usr/bin/env python3
"""Parity runner for legacy-built and Bazel-built binaries."""

import argparse
import difflib
import json
import os
import shlex
import subprocess
import sys


def normalize(data: bytes, legacy: str, bazel: str) -> str:
    text = data.decode("utf-8", errors="replace")
    return text.replace(legacy, "<BIN>").replace(bazel, "<BIN>")


def run_case(binary: str, argv: list[str], stdin: str | None, env: dict[str, str]):
    merged_env = os.environ.copy()
    merged_env.update(env)
    return subprocess.run(
        [binary] + argv,
        input=None if stdin is None else stdin.encode(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=merged_env,
        check=False,
    )


def compare(label: str, legacy_result, bazel_result, legacy: str, bazel: str, state: dict):
    state["checks"] += 1
    legacy_out = normalize(legacy_result.stdout, legacy, bazel)
    bazel_out = normalize(bazel_result.stdout, legacy, bazel)
    legacy_err = normalize(legacy_result.stderr, legacy, bazel)
    bazel_err = normalize(bazel_result.stderr, legacy, bazel)
    code_ok = legacy_result.returncode == bazel_result.returncode
    out_diff = list(
        difflib.unified_diff(
            legacy_out.splitlines(),
            bazel_out.splitlines(),
            fromfile="legacy stdout",
            tofile="bazel stdout",
            lineterm="",
        )
    )
    err_diff = list(
        difflib.unified_diff(
            legacy_err.splitlines(),
            bazel_err.splitlines(),
            fromfile="legacy stderr",
            tofile="bazel stderr",
            lineterm="",
        )
    )
    if code_ok and not out_diff and not err_diff:
        print(f"ok {state['checks']} - {label}")
        return
    print(f"not ok {state['checks']} - {label}")
    if not code_ok:
        print(
            f"  exit codes differ: legacy={legacy_result.returncode} "
            f"bazel={bazel_result.returncode}"
        )
    if out_diff:
        print("  stdout differs (legacy vs bazel):")
        for line in out_diff:
            print(f"    {line}")
    if err_diff:
        print("  stderr differs (legacy vs bazel):")
        for line in err_diff:
            print(f"    {line}")
    state["fails"] += 1


def run_text_cases(path: str, legacy: str, bazel: str, state: dict):
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            argv = line.split()
            compare(
                f"case: {line}",
                run_case(legacy, argv, None, {}),
                run_case(bazel, argv, None, {}),
                legacy,
                bazel,
                state,
            )


def run_jsonl_cases(path: str, legacy: str, bazel: str, state: dict):
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            case = json.loads(line)
            argv = case.get("args", [])
            if not isinstance(argv, list) or not all(isinstance(arg, str) for arg in argv):
                raise ValueError(f"{path}:{lineno}: args must be a list of strings")
            stdin = case.get("stdin")
            env = case.get("env", {})
            if stdin is not None and not isinstance(stdin, str):
                raise ValueError(f"{path}:{lineno}: stdin must be a string")
            if not isinstance(env, dict) or not all(
                isinstance(k, str) and isinstance(v, str) for k, v in env.items()
            ):
                raise ValueError(f"{path}:{lineno}: env must be an object of strings")
            label = case.get("label") or "jsonl case: " + shlex.join(argv)
            compare(
                label,
                run_case(legacy, argv, stdin, env),
                run_case(bazel, argv, stdin, env),
                legacy,
                bazel,
                state,
            )


def run_suite(path: str, bin_env: str, legacy: str, bazel: str, state: dict):
    def run(binary: str):
        env = os.environ.copy()
        env[bin_env] = binary
        return subprocess.run(
            ["sh", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )

    legacy_result = run(legacy)
    bazel_result = run(bazel)
    compare(
        f"suite: {path} runs identically on both binaries",
        legacy_result,
        bazel_result,
        legacy,
        bazel,
        state,
    )
    state["checks"] += 1
    if legacy_result.returncode == 0:
        print(f"ok {state['checks']} - suite passes")
    else:
        print(
            f"not ok {state['checks']} - suite passes "
            f"(exit {legacy_result.returncode}); identical failure is not parity evidence"
        )
        state["fails"] += 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--legacy", required=True)
    parser.add_argument("--bazel", required=True)
    parser.add_argument("--cases")
    parser.add_argument("--cases-jsonl")
    parser.add_argument("--suite")
    parser.add_argument("--suite-bin-env")
    args = parser.parse_args()

    if args.cases and args.cases_jsonl:
        parser.error("--cases and --cases-jsonl are mutually exclusive")
    if args.suite and not args.suite_bin_env:
        parser.error("--suite requires --suite-bin-env")
    if not args.cases and not args.cases_jsonl and not args.suite:
        parser.error("provide --cases, --cases-jsonl, or --suite")

    state = {"checks": 0, "fails": 0}
    if args.cases:
        run_text_cases(args.cases, args.legacy, args.bazel, state)
    if args.cases_jsonl:
        run_jsonl_cases(args.cases_jsonl, args.legacy, args.bazel, state)
    if args.suite:
        run_suite(args.suite, args.suite_bin_env, args.legacy, args.bazel, state)

    print(
        f"# parity: {state['checks']} checks, {state['fails']} failures "
        f"(legacy={args.legacy} bazel={args.bazel})"
    )
    return 0 if state["fails"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
