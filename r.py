#!/usr/bin/env python3

import subprocess
import sys
from pathlib import Path


APPLY_FILE = Path("apply.txt")


def main() -> int:
    if not APPLY_FILE.exists():
        print(f"Erro: arquivo não encontrado: {APPLY_FILE}")
        return 1

    lines = APPLY_FILE.read_text(encoding="utf-8").splitlines()

    commands = []
    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        commands.append((idx, line))

    if not commands:
        print("Nenhum comando encontrado em apply.txt")
        return 0

    for line_no, command in commands:
        print(f"\n[LINHA {line_no}] Executando:")
        print(command)

        result = subprocess.run(
            command,
            shell=True,
            text=True,
            capture_output=True,
            executable="/bin/bash",
        )

        if result.stdout:
            print("\n[STDOUT]")
            print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")

        if result.stderr:
            print("\n[STDERR]")
            print(result.stderr, end="" if result.stderr.endswith("\n") else "\n")

        if result.returncode != 0:
            print(f"\nFalhou na linha {line_no} com código {result.returncode}.")
            return result.returncode

    print("\nTodos os comandos foram executados com sucesso.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())