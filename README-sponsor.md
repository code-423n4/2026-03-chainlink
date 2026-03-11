# Payment Abstraction v2

The goal of Payment Abstraction v2 is to replace the current [Payment Abstraction v1](https://github.com/smartcontractkit/payment-abstraction) system by:
- Implementing a permissionless dutch auction mechanism where any participant can bid on auctioned allowlisted assets. This model improves flexibility and resiliency by supporting multiple liquidity venues.
- Integrating with CowSwap to relay auctions to the protocol’s solvers to ensure sufficient participation.
- Building a backward and forward compatible solution allowing to integrate with multiple liquidity venues.

## Usage

### Pre-requisites

- [pnpm](https://pnpm.io/installation)
- [foundry](https://book.getfoundry.sh/getting-started/installation)
- [slither](https://github.com/crytic/slither) (for static analysis)
- Create an `.env` file, following the `.env.example` (some tests will fail without a configured mainnet RPC)

### Build

```shell
$ pnpm foundry
$ pnpm install
$ forge build
```

### Test

**Run all tests:**

```shell
$ forge test
```

**Detailed gas report:**

```shell
$ forge test --gas-report --isolate
```

**Coverage report:**

```shell
$ pnpm test:coverage && open coverage/index.html
```

**Run static analysis on all files:**

```shell
$ slither .
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

**Generate snapshot:**

```shell
$ pnpm run snapshot
```

**Compare against existing snapshot:**

```shell
$ pnpm run snapshot --diff
```
