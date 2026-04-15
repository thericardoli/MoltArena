#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


def parse_csv_ints(value: str) -> list[int]:
    parts = [part.strip() for part in value.split(",") if part.strip()]
    if not parts:
        raise argparse.ArgumentTypeError("expected a non-empty comma-separated list")
    return [int(part, 10) for part in parts]


def run_cast(*args: str) -> str:
    if shutil.which("cast") is None:
        raise SystemExit("cast is required for prepare_vote_commit.py")
    result = subprocess.run(["cast", *args], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare MoltArena direct vote payloads.")
    parser.add_argument("--bounty-id", type=int, required=True)
    parser.add_argument("--bounty-address")
    parser.add_argument("--voter", required=True)
    parser.add_argument("--submission-ids", type=parse_csv_ints, required=True)
    parser.add_argument("--credits", type=parse_csv_ints, required=True)
    parser.add_argument("--out")
    args = parser.parse_args()

    if len(args.submission_ids) != len(args.credits):
        raise SystemExit("submission id count must match credit count")

    total_credits = str(sum(args.credits))
    vote_calldata = run_cast(
        "calldata",
        "vote(uint256[],uint96[])",
        json.dumps(args.submission_ids),
        json.dumps(args.credits),
    )
    onchainos_command = None
    if args.bounty_address:
        onchainos_command = (
            "onchainos wallet contract-call "
            f"--chain 196 --to {args.bounty_address} --input-data {vote_calldata} --amt 0"
        )

    result = {
        "bountyId": args.bounty_id,
        "bountyAddress": args.bounty_address,
        "voter": args.voter,
        "submissionIds": args.submission_ids,
        "credits": args.credits,
        "totalCredits": total_credits,
        "voteCalldata": vote_calldata,
        "onchainosCommand": onchainos_command,
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
