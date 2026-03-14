# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eswap Margin is a decentralized exchange (DEX) protocol enabling margin trading with 0% interest rates, built on top of Uniswap V3 and Chainlink price feeds. The protocol supports long/short positions, leverage trading, limit orders, and stop losses.

## Common Commands

### Smart Contracts (Foundry)
```bash
make setup          # Clean, install deps, build (first time setup)
make clean          # Clean build artifacts
make build          # Build contracts with via-ir
make test           # Run all tests (forks mainnet via ETH_RPC_URL)
make test-gas      # Run tests with gas report
make format        # Format Solidity with Prettier
make lint          # Lint with Solhint
make anvil         # Start local fork (mnemonic: test test test... junk)
make deploy-anvil # Deploy contracts to local fork
```

### Dashboard (Next.js)
```bash
cd dashboard && npm install    # Install dependencies
npm run dev                    # Start dev server (localhost:3000)
npm run build                  # Production build
npm run test                   # Run Jest tests
```

### Configuration Sync
After changing contracts or `.env`:
```bash
node javascript/update-dashboard.js
```

## Architecture

### Monorepo Structure
```
Unilev/
├── src/                    # Solidity smart contracts (12 files)
├── test/                   # Foundry tests + mocks + utilities
├── scripts/                # Deployment scripts
├── dashboard/              # Next.js 16 frontend (wagmi + react-query)
├── javascript/             # Node.js utilities for contract interaction
└── lib/                    # Foundry dependencies
```

### Core Smart Contracts

| Contract | Purpose |
|----------|---------|
| `Market.sol` | Single entry point for all protocol interactions |
| `Positions.sol` | Position manager (ERC721), tracks user positions as NFTs |
| `LiquidityPool.sol` | ERC4626 vault for leverage/short liquidity |
| `LiquidityPoolFactory.sol` | Factory for creating liquidity pools |
| `PriceFeedL1.sol` | Chainlink oracle integration (XXX/ETH feeds) |
| `UniswapV3Helper.sol` | Uniswap V3 swap and liquidity operations |
| `FeeManager.sol` | Protocol fee management |
| `PositionLogic.sol` | Position calculation logic (library) |
| `PositionTypes.sol` | Position data structures |

### Key Patterns

**Position Management:**
- Users receive NFTs representing their positions
- Long: borrow quote token → swap to base token
- Short: borrow base token → swap to quote token
- Liquidation via fixed fee mechanism

**Price Feed:**
- Uses Chainlink XXX/ETH price feeds
- Staleness checks for price validity

**Liquidity Pools:**
- ERC4626 vault pattern
- Users deposit tokens, receive vault shares

### Frontend Stack
- Next.js 16 (App Router)
- Wagmi v3 + Ethers.js v6
- React 19 + Framer Motion
- TanStack React Query

## Environment Setup

Create `.env` from `.env.example` with:
```bash
ETH_RPC_URL=<mainnet-rpc-url>    # Required for tests
PRIVATE_KEY=<deployer-key>       # Required for deployment
POLYGON_RPC_URL=<polygon-rpc>    # Optional, for Polygon deployment
```

## Important Notes

1. **Via-IR Required**: Contracts require `--via-ir` flag due to complex math. Never remove this.
2. **ABIs Must Sync**: Run `update-dashboard.js` after contract changes.
3. **Test Forking**: Tests fork mainnet - ensure `ETH_RPC_URL` is valid.
4. **Contract Addresses**: Stored in `.env`, synced to dashboard via update script.

# Mocking strategy
Never create mock ERC classes. In case it is requeried use Utils.writeTokenBalance

