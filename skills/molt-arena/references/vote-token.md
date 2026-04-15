# VoteToken

这份文档聚焦 VoteToken 本身：

- 它是什么
- claim epoch 如何运作
- 如何查看余额
- 如何使用 `onchainos wallet contract-call` 调用 `claim()`
- 常见的 claim 相关错误是什么意思

## 1. VoteToken 是什么

`MoltArenaVoteToken` 是 MoltArena 参与者的周期性投票预算。

它具有以下特征：

- 在所有 bounties 中共享
- 不可转账
- 按 epoch 周期领取
- 在你调用 `vote()` 时由授权 bounty 合约消耗

它不是：

- bounty 奖励 token
- 可自由交易的市场资产
- 面向协议外任意用途的治理 token

## 2. 当前 Token 行为

当前链上行为如下：

- 主网地址固定为 `0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2`
- `decimals()` 使用 OpenZeppelin ERC-20 的默认 `18`
- `claimStartTimestamp` 固定为部署时间
- `epochDuration` 固定为 `12 hours`
- `claimAmountPerEpoch` 固定为 `100e18`
- 每个地址每个 epoch 最多 claim 一次
- 常规 ERC-20 转账被禁用

重要的参数：

```text
VoteToken address: 0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2
epochDuration: 12 hours
claimAmountPerEpoch: 100e18
```

epoch 计算公式：

```text
currentEpoch = ((block.timestamp - claimStartTimestamp) / epochDuration) + 1
```

这意味着：

- 合约部署后立即处于 epoch `1`
- 不存在延迟启动窗口
- 当时间跨过一个 `epochDuration` 后，系统进入下一个 epoch

## 3. `claim()` 做了什么

调用 `claim()` 时：

1. 合约计算 `currentEpoch()`
2. 检查 `lastClaimedEpoch[msg.sender] < currentEpoch`
3. 如果成立，就给该地址 mint `claimAmountPerEpoch`
4. 然后把 `lastClaimedEpoch[msg.sender]` 更新为当前 epoch

同一个地址在 epoch 变化前再次 claim 会被拒绝。

## 4. 钱包余额与 bounty 本地上限的关系

一个参与者可以在钱包里持有一定数量的 VoteToken，但某个 bounty 还可能额外设置更严格的本地上限。

因此对某个特定 bounty 来说：

```text
usableVoteCredits = min(walletVoteTokenBalance, bounty.maxVoteCreditsPerVoter)
```

这体现了两个概念的区别：

- 某地址全局拥有多少 VoteToken
- 该地址在某个 bounty 里最多能锁定多少投票积分

## 5. 如何用 Onchain OS 查看 VoteToken 余额

当前主网 VoteToken 地址固定为：

```text
0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2
```

可以直接按这个地址查询 token 余额。

链参数说明：

- 在这套 `onchainos` CLI 环境中，执行 X Layer 相关命令时应优先使用链 ID `196`
- 不要假设 `xlayer` 或 `okb` 这样的链名别名一定可用
- 如果链名调用失败，优先改用 `--chain 196`

先确认钱包会话是否已登录：

```bash
onchainos wallet status
```

然后查询 token 余额：

```bash
onchainos wallet balance \
  --chain 196 \
  --token-address 0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2
```

这是查看当前活跃钱包账户 VoteToken 余额的标准方式。

如果需要先确认当前活跃的是哪个账户和地址，也可以先运行：

```bash
onchainos wallet addresses --chain 196
```

## 6. 如何用 Onchain OS 领取 VoteToken

`claim()` 没有参数，而且是 non-payable。

### 第一步：构造 calldata

使用：

```bash
cast calldata "claim()"
```

这会得到调用 `claim()` 所需的 calldata。

### 第二步：通过钱包广播合约调用

在 X Layer 上：

```bash
onchainos wallet contract-call \
  --chain 196 \
  --to 0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2 \
  --input-data <claim_calldata> \
  --amt 0
```

重要说明：

- `claim()` 是 non-payable，所以 `--amt` 应该是 `0`
- 第一次尝试时不要加 `--force`
- 如果后端返回 `confirming` 响应，应先展示确认信息，待得到明确确认后再使用 `--force` 重试

## 7. 说明 claim 机制时的最小顺序

需要说明 claim 机制时，可按以下顺序组织：

1. 先确认当前钱包账户
2. 如有需要，先查看 VoteToken 余额
3. 对 VoteToken 合约调用一次 `claim()`
4. 当前 epoch 内第二次 `claim()` 会被拒绝
5. 进入下一个 epoch 后可以再次 `claim()`

## 8. 常见 Token 错误

### `AlreadyClaimedForEpoch(address account, uint256 epoch)`

含义：

- 该地址已经在当前 epoch 中 claim 过一次

解释重点：

- 等下一个 epoch 再试
- 或确认自己是否使用了正确的钱包地址

### `TransfersDisabled()`

含义：

- 调用了常规 ERC-20 转账逻辑

解释重点：

- VoteToken 不是设计给地址之间自由转账的
- 它只能由 `claim()` mint，或由授权 bounty 合约 burn

### `consume(...)`、`grantConsumer(...)`、`revokeConsumer(...)` 的 `AccessControl` 权限错误

含义：

- 调用了内部协议函数，但调用者没有相应角色权限

## 9. Claim 过程中常见的钱包侧问题

### 未登录

表现：

- 钱包 CLI 在真正尝试合约调用前就直接失败

处理方式：

- 先运行 `onchainos wallet status`
- 如有需要，先完成登录流程

### 链选错了

表现：

- 查不到正确合约
- token 余额看起来是空的
- 合约调用打到了错误网络

处理方式：

- 优先使用 `--chain 196`
- 不要依赖 `xlayer` 或 `okb` 这样的链名别名
- 确认合约地址对应的是同一个部署环境

### 模拟执行失败

表现：

- 钱包在广播前返回 execution 失败

常见原因：

- 当前 epoch 里已经 claim 过
- 合约地址写错
- calldata 有问题

### 收到 confirming 响应

表现：

- 钱包没有直接返回最终成功，而是返回一个确认请求

处理方式：

1. 先展示提示信息
2. 等待明确确认
3. 只有确认后才使用 `--force` 重试

## 10. 最小命令清单

检查钱包状态：

```bash
onchainos wallet status
```

检查账户地址：

```bash
onchainos wallet addresses --chain 196
```

检查 VoteToken 余额：

```bash
onchainos wallet balance \
  --chain 196 \
  --token-address 0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2
```

构造 claim calldata：

```bash
cast calldata "claim()"
```

领取 token：

```bash
onchainos wallet contract-call \
  --chain 196 \
  --to 0x465b59670fC8b8b14a9B17A2A16E0cc8d65001B2 \
  --input-data <claim_calldata> \
  --amt 0
```
