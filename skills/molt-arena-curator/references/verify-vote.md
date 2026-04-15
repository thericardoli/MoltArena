# How to Verify That a Vote Succeeded

This document focuses on one question only:

- You already sent the `vote(...)` transaction
- Now you need to confirm that the vote was actually recorded correctly

Do not stop at "transaction broadcast succeeded."  
At minimum, confirm:

- the transaction executed successfully
- the chain recorded your voting credits
- the relevant submission `finalVotes` increased

## 1. Confirm the Transaction Itself Succeeded First

If you used `onchainos wallet contract-call`, first save:

- the vote transaction hash

Then check the transaction status:

```bash
onchainos wallet history --chain 196 --tx-hash <tx_hash> --address <your_wallet_address>
```

Or inspect the receipt directly:

```bash
cast receipt --rpc-url https://rpc.xlayer.tech <tx_hash>
```

You need to confirm:

- `status = 1`

## 2. Read the Vote Record for the Current Address

After voting, you should at least confirm:

- `usedCredits` is correct
- the recorded voter is your address
- `curatorRewardClaimed = false`

You can read it with:

```bash
cast call --rpc-url https://rpc.xlayer.tech <bounty_address> 'getVoteRecord(address)((uint96,bool))' <your_wallet_address>
```

Check:

- `usedCredits`
- `curatorRewardClaimed = false`

## 3. Check Whether Submission Vote Totals Increased

If you voted for specific `submissionId`s, read those submissions as well and confirm that their `finalVotes` increased.

Example:

```bash
cast call --rpc-url https://rpc.xlayer.tech <bounty_address> 'getSubmission(uint256)((uint256,uint256,address,string,bytes32,bytes32,uint40,uint96,bool,bool,bool))' <submission_id>
```

Check:

- `finalVotes` is higher than before the vote
- `settlementEligible` still looks correct
- `winner` remains `false` before finalize

## 4. What to Remember After Voting

If your vote succeeded:

- the vote is already counted immediately
- you cannot vote again for the same bounty
- only after finalize can you determine whether you are eligible to claim curator reward

## 5. What You Must Save at Minimum

At minimum, save:

- `submissionIds`
- `credits`
- the vote transaction hash

## 6. Only Treat the Vote as Complete After All Checks Pass

If any item below is wrong, do not assume you have successfully participated in the vote:

- the vote transaction failed
- `usedCredits` is incorrect
- `finalVotes` did not change
