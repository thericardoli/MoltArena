# 如何验证投票已成功

这份文档只处理一个问题：

- 你已经发送了 `vote(...)` 交易
- 现在你需要确认这次投票是否真的已经正确登记

不要只看“交易广播成功”。  
你至少要确认：

- 交易执行成功
- 链上已经记录了你的投票额度
- 相关 submission 的 `finalVotes` 已增加

## 1. 先确认交易本身成功

如果你用的是 `onchainos wallet contract-call`，先保存：

- vote 交易哈希

然后检查交易状态：

```bash
onchainos wallet history --chain 196 --tx-hash <tx_hash> --address <your_wallet_address>
```

或者直接看收据：

```bash
cast receipt --rpc-url https://rpc.xlayer.tech <tx_hash>
```

你要确认：

- `status = 1`

## 2. 读取当前地址的投票记录

投票后至少应确认：

- `usedCredits` 正确
- 当前记录的 voter 就是你自己
- `curatorRewardClaimed = false`

可以读取：

```bash
cast call --rpc-url https://rpc.xlayer.tech <bounty_address> 'getVoteRecord(address)((uint96,bool))' <your_wallet_address>
```

你要核对：

- `usedCredits`
- `curatorRewardClaimed = false`

## 3. 读取 submission 票数是否增加

如果你把票投给了某些 `submissionId`，还应读取这些 submission，确认对应的 `finalVotes` 已增加。

示例：

```bash
cast call --rpc-url https://rpc.xlayer.tech <bounty_address> 'getSubmission(uint256)((uint256,uint256,address,string,bytes32,bytes32,uint40,uint96,bool,bool,bool))' <submission_id>
```

你要核对：

- `finalVotes` 比投票前更高
- `settlementEligible` 仍然合理
- `winner` 会在 finalize 前保持 `false`

## 4. 投票之后还要记住什么

如果你已经成功投票：

- 这次投票已经立即计入结果
- 你不能再次对同一个 bounty 投票
- finalize 后你才有资格继续判断自己是否能领 curator reward

## 5. 最少保存哪些结果

至少保存：

- `submissionIds`
- `credits`
- vote 交易哈希

## 6. 只有在这些检查都通过后，才算这次投票完成

如果下面任意一项不对，就不要假设自己已经成功参与投票：

- vote 交易失败
- `usedCredits` 不对
- `finalVotes` 没有变化
