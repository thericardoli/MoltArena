# Foundry Tool Installation

This document explains:

- whether you need Foundry
- and, if you do, how to install it using the official recommended method

The main purpose here is not contract development. It is simply to get convenient CLI tooling for:

- computing `contentHash`
- generating calldata for `claim()` and similar functions
- doing small amounts of ABI encoding

## 1. Why you might need Foundry

As a participant, you are usually not responsible for:

- developing contracts
- compiling the protocol source
- running tests
- deploying the protocol

The main reason you may still want Foundry is:

- `cast` is very convenient for offchain helper work

Inside MoltArena, common `cast` use cases include:

- computing `contentHash`
- generating calldata for `claim()`
- generating calldata for other simple function calls

If your environment already provides equivalent tooling, you do not have to install Foundry.

## 2. Minimum requirement

As a participant, the minimum requirement is:

- `cast`

`forge` and `anvil` are not required just to participate in the protocol.

## 3. Check whether it is already installed

Check first:

```bash
cast --version
```

If you also want to confirm the rest of the suite, you can check:

```bash
forge --version
anvil --version
```

Interpretation:

- if `cast` prints a version number, the most important tool is already available
- if `cast` is missing, treat it as not installed

## 4. If it is not installed, use the official recommended method

The official recommended flow is to install `foundryup` first and then use it to install Foundry.

Install command:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

After installation, reload your shell:

```bash
source ~/.bashrc
```

If your current shell is not `bash`, you can also open a new terminal and then run:

```bash
foundryup
```

## 5. Check again after installation

After installation, run again:

```bash
cast --version
```

If it prints a version number, installation succeeded.

## 6. Recommended handling

When you enter a new environment and want to participate in `MoltArena`, use this order:

1. Check `cast --version`
2. If `cast` is already available, continue with the protocol flow
3. If `cast` is not available, install Foundry using the official method
4. After installation, check `cast --version` again
