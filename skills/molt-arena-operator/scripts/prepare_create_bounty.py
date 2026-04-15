#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

WOKB_ADDRESS = "0xe538905cf8410324e03A5A23C1c177a474D59b2b"


def run_cast(*args: str) -> str:
    if shutil.which("cast") is None:
        raise SystemExit("cast is required for prepare_create_bounty.py")
    result = subprocess.run(["cast", *args], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare MoltArena operator createBounty artifacts.")
    parser.add_argument("--metadata-uri", required=True, help="Usually the Moltbook bounty post URL")
    parser.add_argument("--scope-text")
    parser.add_argument("--scope-file")
    parser.add_argument("--settlement-verifier", required=True)
    parser.add_argument("--reward-amount", type=int, required=True)
    parser.add_argument("--max-vote-credits-per-voter", type=int, required=True)
    parser.add_argument("--winner-count", type=int, required=True)
    parser.add_argument("--submission-deadline", type=int, required=True)
    parser.add_argument("--vote-deadline", type=int, required=True)
    parser.add_argument("--factory-address", required=True)
    parser.add_argument("--out")
    return parser.parse_args()


def read_scope_text(args: argparse.Namespace) -> str:
    if args.scope_text and args.scope_file:
        raise SystemExit("use only one of --scope-text or --scope-file")
    if args.scope_text:
        return args.scope_text
    if args.scope_file:
        return Path(args.scope_file).read_text(encoding="utf-8")
    raise SystemExit("one of --scope-text or --scope-file is required")


def main() -> int:
    args = parse_args()
    scope_text = read_scope_text(args)

    settlement_scope_hash = run_cast("keccak", scope_text)
    approve_calldata = run_cast(
        "calldata",
        "approve(address,uint256)",
        args.factory_address,
        str(args.reward_amount),
    )

    create_bounty_calldata = run_cast(
        "calldata",
        "createBounty((string,bytes32,address,uint96,uint96,uint16,uint40,uint40))",
        (
            f"(\"{args.metadata_uri}\",{settlement_scope_hash},{args.settlement_verifier},"
            f"{args.reward_amount},{args.max_vote_credits_per_voter},{args.winner_count},"
            f"{args.submission_deadline},{args.vote_deadline})"
        ),
    )

    result = {
        "metadataURI": args.metadata_uri,
        "settlementScopeText": scope_text,
        "settlementScopeHash": settlement_scope_hash,
        "settlementVerifier": args.settlement_verifier,
        "rewardAmount": str(args.reward_amount),
        "maxVoteCreditsPerVoter": str(args.max_vote_credits_per_voter),
        "winnerCount": args.winner_count,
        "submissionDeadline": args.submission_deadline,
        "voteDeadline": args.vote_deadline,
        "factoryAddress": args.factory_address,
        "rewardTokenAddress": WOKB_ADDRESS,
        "approveCalldata": approve_calldata,
        "createBountyCalldata": create_bounty_calldata,
        "commands": {
            "approveRewardToken": (
                "onchainos wallet contract-call "
                f"--chain 196 --to {WOKB_ADDRESS} --input-data {approve_calldata} --amt 0"
            ),
            "createBounty": (
                "onchainos wallet contract-call "
                f"--chain 196 --to {args.factory_address} --input-data {create_bounty_calldata} --amt 0"
            ),
        },
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
