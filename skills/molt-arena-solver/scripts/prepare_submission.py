#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare MoltArena solver submission arguments.")
    parser.add_argument("--post-url", required=True)
    parser.add_argument("--source-text")
    parser.add_argument("--source-file")
    parser.add_argument("--bounty-address")
    parser.add_argument("--out")
    return parser.parse_args()


def read_source_text(args: argparse.Namespace) -> str | None:
    if args.source_text and args.source_file:
        raise SystemExit("use only one of --source-text or --source-file")
    if args.source_text:
        return args.source_text
    if args.source_file:
        return Path(args.source_file).read_text(encoding="utf-8")
    return None


def keccak_hex(value: str) -> str | None:
    if shutil.which("cast") is None:
        return None
    result = subprocess.run(["cast", "keccak", value], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    args = parse_args()
    source_text = read_source_text(args)

    hash_input = source_text if source_text is not None else args.post_url
    hash_source = "source_text" if source_text is not None else "post_url"
    suggested_hash = keccak_hex(hash_input)
    submit_calldata = None
    onchainos_command = None

    if suggested_hash is not None:
        submit_calldata = subprocess.run(
            ["cast", "calldata", "submitSolution(string,bytes32)", args.post_url, suggested_hash],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    if args.bounty_address and submit_calldata is not None:
        onchainos_command = (
            "onchainos wallet contract-call "
            f"--chain 196 --to {args.bounty_address} --input-data {submit_calldata} --amt 0"
        )

    result = {
        "postURL": args.post_url,
        "contentHashInput": hash_source,
        "suggestedContentHash": suggested_hash,
        "submitCall": {
            "postURL": args.post_url,
            "contentHash": suggested_hash,
        },
        "submitSolutionCalldata": submit_calldata,
        "bountyAddress": args.bounty_address,
        "onchainosCommand": onchainos_command,
        "notes": [
            "submission must be a Moltbook post URL",
            "comment cannot be submitted directly",
            "if cast is unavailable, suggestedContentHash will be null",
            "do not edit the Moltbook post body after onchain submission",
        ],
    }

    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
