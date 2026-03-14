# AGENTS.md - Coder Agent Guide

## Project Overview

**Eswap Margin** - A decentralized exchange (DEX) protocol enabling margin trading with 0% interest rates, built on top of Uniswap V3 and Chainlink price feeds. The protocol supports long/short positions, leverage trading, limit orders, and stop losses.

**Key Features:**

-   Margin trading (long/short) with leverage
-   Limit orders and stop losses
-   0% interest rate leverage via Chainlink price feeds
-   Uniswap V3 integration for liquidity
-   Multi-chain deployment (EVM chains)

## Architecture

### Monorepo Structure

```
Unilev/
├── src/                    # Solidity smart contracts
├── test/                   # Foundry test files
├── scripts/                # Deployment scripts
├── dashboard/              # Next.js frontend application
│   ├── src/
│   │   ├── app/           # Next.js app router pages
│   │   ├── components/    # React components
│   │   ├── hooks/         # Custom React hooks
│   │   ├── utils/         # Utility functions
│   │   ├── config/        # Configuration files
│   │   └── abis/          # Contract ABIs
│   └── package.json
├── javascript/             # Node.js utilities for contract interaction
├── lib/                    # Foundry dependencies (OpenZeppelin, etc.)
└── out/                    # Compiled contract artifacts
```

### Smart Contracts Layer

**Core Contracts:**

-   `Positions.sol` - Main position manager (ERC721), tracks all user positions
-   `Market.sol` - Single entry point for all protocol interactions
-   `LiquidityPool.sol` - ERC4626 vault for leverage/short liquidity
-   `LiquidityPoolFactory.sol` - Factory for creating liquidity pools
-   `PriceFeedL1.sol` - Chainlink oracle integration
-   `UniswapV3Helper.sol` - Helper for Uniswap V3 operations
-   `FeeManager.sol` - Protocol fee management

**Libraries:**

-   `PositionLogic.sol` - Position calculation and management logic
-   `PositionTypes.sol` - Position data structures

**Key Concepts:**

-   Users receive NFTs representing positions
-   Long positions: borrow quote token from liquidity pool
-   Short positions: borrow base token from liquidity pool
-   Liquidations handled via fixed fee mechanism
-   All prices sourced from Chainlink oracles (XXX/ETH pairs)

### Frontend Layer (Dashboard)

**Tech Stack:**

-   **Framework:** Next.js 16 (App Router)
-   **Web3:** Wagmi v3 + Ethers.js v6
-   **UI:** React 19 + Framer Motion + Lucide Icons
-   **State:** TanStack React Query

**Key Components:**

-   `TradeForm.jsx` - Position opening interface
-   `PositionsList.jsx` - Active positions display
-   `LiquidityPoolManager.jsx` - LP management
-   `FeeManager.jsx` - Protocol fee dashboard
-   `Balances.jsx` / `ProtocolBalances.jsx` - Balance displays

**Data Flow:**

1. Contract ABIs synced via `javascript/update-dashboard.js`
2. Wagmi hooks read blockchain state
3. React Query manages caching and state
4. Framer Motion handles animations

## Development Workflow

### Initial Setup

```bash
# 1. Install Foundry dependencies
make setup

# 2. Setup environment variables
cp .env.example .env
# Add: ETH_RPC_URL, PRIVATE_KEY, POLYGON_RPC_URL (optional)

# 3. Install dashboard dependencies
cd dashboard && npm install

# 4. Sync configuration to dashboard
node javascript/update-dashboard.js
```

### Smart Contract Development

**Build Contracts:**

```bash
make build          # Build with via-ir (required for complex contracts)
make compile        # Alternative compile command
make sizer         # View contract sizes
```

**Run Tests:**

```bash
make test          # Run all tests (forks mainnet)
make test-gas      # Run tests with gas reporting
```

**Code Quality:**

```bash
make format        # Format Solidity with Prettier
make lint          # Lint with Solhint
make slither       # Run Slither security analysis
```

**Local Development:**

```bash
make anvil         # Start local fork of mainnet
make deploy-anvil  # Deploy to local network
```

**Deployment:**

```bash
make deploy-polygon  # Deploy to Polygon mainnet
```

### Frontend Development

**Development Server:**

```bash
cd dashboard
npm run dev       # Start Next.js dev server
npm run build     # Build for production
npm run start     # Start production server
```

**Configuration Sync:**
After changing `.env` or deploying new contracts:

```bash
node javascript/update-dashboard.js
```

This script:

-   Syncs `.env` variables to `dashboard/.env.local`
-   Copies contract ABIs to `dashboard/src/abis/`
-   Updates contract addresses

### JavaScript Utilities

The `javascript/` directory contains Node.js scripts for:

**Testing/Interaction:**

-   `openLongPosition.js` / `openShortPosition.js` - Open test positions
-   `closeAllPositions.js` - Close all positions
-   `checkPositions.js` - Query position state
-   `liquidate.js` - Liquidate positions

**Liquidity Management:**

-   `1_add_balance_pool.js` - Add liquidity to pools
-   `2_add_balance_wallet_token.js` - Fund wallet with tokens
-   `2_deposit_all_usdc.js` - Deposit USDC to liquidity pools
-   `redeemLiquidity.js` - Withdraw liquidity

**Configuration:**

-   `update-dashboard.js` - Sync config to frontend
-   `update-env.js` - Update environment variables
-   `network-info.js` - Get network information
-   `balance.js` - Check balances

## Code Conventions

### Smart Contracts (Solidity)

**Naming:**

-   Contracts: PascalCase (`Positions`, `LiquidityPool`)
-   Functions: camelCase (`openPosition`, `closePosition`)
-   Constants: UPPER_SNAKE_CASE (`MIN_LEVERAGE`, `MAX_LEVERAGE`)
-   Structs: PascalCase (`Position`, `PoolInfo`)

**Structure:**

```solidity
// 1. SPDX license
// 2. Pragma
// 3. Imports
// 4. Contract declaration
// 5. State variables
// 6. Events
// 7. Errors
// 8. Modifiers
// 9. Constructor
// 10. External functions
// 11. Public functions
// 12. Internal functions
// 13. Private functions
// 14. View/pure functions
```

**Patterns:**

-   Use OpenZeppelin contracts for standard implementations (ERC721, ERC4626)
-   Custom errors for gas efficiency
-   Events for all state changes
-   NatSpec comments for all public functions
-   `--via-ir` compilation required (due to complex math)

**Testing:**

-   Use Foundry test framework
-   Fork mainnet for integration tests
-   Mock contracts in `test/mocks/`
-   Test setup utilities in `test/utils/`

### Frontend (React/Next.js)

**File Naming:**

-   Components: PascalCase (`TradeForm.jsx`, `PositionsList.jsx`)
-   Utilities: camelCase (`formatContractError.js`)
-   Hooks: camelCase with `use` prefix (`useDeFi.js`)

**Component Structure:**

```jsx
// 1. Imports
// 2. Component definition
// 3. Hooks (wagmi, react-query, custom)
// 4. Derived state
// 5. Handlers
// 6. Effects
// 7. Render
```

**State Management:**

-   Use Wagmi hooks for blockchain interactions (`useAccount`, `useReadContract`, `useWriteContract`)
-   Use React Query for caching (`useQuery`, `useMutation`)
-   Local state for UI-only concerns

**Web3 Patterns:**

```jsx
// Read contract data
const { data, isLoading, error } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: ContractABI,
    functionName: "getPosition",
    args: [tokenId],
})

// Write to contract
const { writeContract } = useWriteContract()
writeContract({
    address: CONTRACT_ADDRESS,
    abi: ContractABI,
    functionName: "openPosition",
    args: [...args],
})
```

**Error Handling:**

-   Use `formatContractError.js` for user-friendly error messages
-   Handle transaction reverts gracefully
-   Display loading states during transactions

## Important Patterns

### Position Management

**Opening a Position:**

1. User calls `Market.openPosition()` with parameters
2. Market validates parameters and checks liquidity pool balance
3. If valid, creates position NFT and transfers tokens
4. For long: borrow quote token, swap to base token
5. For short: borrow base token, swap to quote token

**Closing a Position:**

1. User calls `Market.closePosition()` with NFT ID
2. Position settles (swap tokens back, calculate P&L)
3. Return borrowed amount to liquidity pool
4. Transfer profit/remaining collateral to user
5. Burn position NFT

**Liquidation:**

1. Liquidator calls `Market.liquidatePosition()`
2. Check if position is liquidatable (stop loss, limit order, or collateral)
3. Close position and distribute liquidation reward
4. Remaining collateral returns to user

### Price Feed System

**Chainlink Integration:**

-   Use XXX/ETH price feeds
-   Derive XXX/YYY price by combining feeds
-   Example: WBTC/MATIC = (WBTC/ETH) / (MATIC/ETH)
-   Staleness checks for price validity
-   Fallback mechanisms for price failures

### Liquidity Pool System

**ERC4626 Vault Pattern:**

-   Users deposit base/quote token
-   Receive vault shares
-   Shares represent pool ownership
-   Yield from trading fees
-   Instant withdrawal (if sufficient liquidity)

## Common Tasks

### Add New Trading Pair

1. **Add Chainlink Price Feed:**

    - Update `PriceFeedL1.sol` with new feed address
    - Add feed configuration in constructor

2. **Create Liquidity Pool:**

    - Call `LiquidityPoolFactory.createPool(token)`
    - Fund pool with initial liquidity

3. **Update Dashboard:**
    - Add token to `dashboard/src/config/supported_tokens.json`
    - Run `node javascript/update-dashboard.js`

### Modify Position Logic

1. **Update Contract:**

    - Edit `src/libraries/PositionLogic.sol`
    - Update tests in `test/` directory
    - Run `make test` to verify

2. **Handle State Changes:**
    - If adding new fields, consider migration strategy
    - Update `PositionTypes.sol` if needed
    - Update ABI in dashboard

### Add New Dashboard Feature

1. **Create Component:**

    - Place in `dashboard/src/components/`
    - Use existing components as templates
    - Import Wagmi hooks for blockchain interaction

2. **Add Page (if needed):**

    - Create in `dashboard/src/app/`
    - Follow Next.js App Router conventions

3. **Update Configuration:**
    - Add contract addresses to `.env`
    - Run `node javascript/update-dashboard.js`

### Debug Contract Issues

1. **Local Testing:**

    ```bash
    make anvil           # Start local fork
    make deploy-anvil    # Deploy contracts
    node javascript/openLongPosition.js  # Test interaction
    ```

2. **Fork Testing:**

    ```bash
    make test           # Tests use forked mainnet
    ```

3. **Check State:**
    ```bash
    node javascript/balance.js
    node javascript/checkPositions.js
    ```

## Security Considerations

### Smart Contract Security

**Critical Areas:**

-   Price feed manipulation/staleness
-   Liquidation timing and rewards
-   Collateral calculations
-   Token decimal handling
-   Reentrancy in position operations

**Best Practices:**

-   Always check return values from external calls
-   Use `nonReentrant` modifier where appropriate
-   Validate all inputs
-   Use SafeMath for arithmetic (though Solidity 0.8+ has built-in overflow checks)
-   Test edge cases (max/min leverage, zero amounts, etc.)

**Auditing:**

-   Run `make slither` before deployment
-   Review all external function calls
-   Test with forked mainnet state
-   Consider professional audit for mainnet

### Frontend Security

**Private Key Handling:**

-   Never expose private keys in frontend code
-   Use environment variables for sensitive data
-   Frontend uses browser wallets (MetaMask) - no server-side signing

**Transaction Security:**

-   Always validate user inputs before transactions
-   Display transaction simulations when possible
-   Warn users about gas costs and slippage

## Environment Variables

### Root `.env`

```bash
ETH_RPC_URL=<mainnet-rpc-url>           # Required for tests
PRIVATE_KEY=<deployer-private-key>      # Required for deployment
POLYGON_RPC_URL=<polygon-rpc-url>       # Optional, for Polygon deployment
ETHERSCAN_API_KEY=<etherscan-key>       # Optional, for verification
```

### Dashboard `.env.local`

Generated automatically by `update-dashboard.js`:

```bash
NEXT_PUBLIC_CHAIN_ID=137
NEXT_PUBLIC_MARKET_ADDRESS=<market-contract>
NEXT_PUBLIC_POSITIONS_ADDRESS=<positions-contract>
NEXT_PUBLIC_LIQUIDITY_POOL_FACTORY_ADDRESS=<factory>
# ... other contract addresses
```

## Testing Strategy

### Smart Contract Tests

**Test Categories:**

-   Unit tests: Test individual functions
-   Integration tests: Test contract interactions
-   Fork tests: Test with real mainnet state

**Test Structure:**

```solidity
contract TestPositions is Test {
    // 1. Setup
    function setUp() public { ... }

    // 2. Test cases
    function test_OpenLongPosition() public { ... }
    function testFail_InvalidLeverage() public { ... }

    // 3. Edge cases
    function test_MaxLeverage() public { ... }
}
```

**Coverage:**

-   All external functions
-   All state transitions
-   All access control modifiers
-   All error conditions
-   Boundary conditions (min/max values)

### Frontend Testing

Currently minimal - consider adding:

-   Component tests with React Testing Library
-   Integration tests with Wagmi mock providers
-   E2E tests with Playwright/Cypress

## Deployment

### Local Deployment

```bash
make anvil          # Terminal 1: Start local chain
make deploy-anvil   # Terminal 2: Deploy contracts
```

### Mainnet Deployment

```bash
# 1. Verify environment
node javascript/network-info.js

# 2. Deploy
make deploy-polygon

# 3. Update frontend
node javascript/update-dashboard.js

# 4. Test deployment
node javascript/balance.js
node javascript/checkPositions.js
```

### Contract Verification

```bash
# Auto-verification in deployment script
# Or manual verification via Etherscan
```

## Useful Resources

### Documentation

-   [Foundry Book](https://book.getfoundry.sh/)
-   [OpenZeppelin Contracts](https://docs.openzeppelin.com/)
-   [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
-   [Uniswap V3 Docs](https://docs.uniswap.org/contracts/v3/overview)
-   [Wagmi Documentation](https://wagmi.sh/)
-   [Next.js Documentation](https://nextjs.org/docs)

### Project-Specific

-   Architecture diagram: `images/intro.png`
-   Position examples: `images/pos*.png`
-   README.md for overview

### Tools

-   **Foundry:** Smart contract development, testing, deployment
-   **Slither:** Static security analysis
-   **Solhint:** Solidity linting
-   **Prettier:** Code formatting

## Known Issues & Considerations

1. **Via-IR Compilation:** Contracts require `--via-ir` flag due to complex math. Don't remove this.

2. **Price Feed Dependency:** Protocol relies on Chainlink XXX/ETH feeds. Not all pairs may be supported.

3. **Liquidity Depth:** Protocol success depends on sufficient liquidity in pools.

4. **Gas Costs:** Complex position operations can be gas-intensive.

5. **Oracle Risk:** Price feed failures can lead to incorrect liquidations or unfair trades.

6. **Dashboard ABIs:** Must run `update-dashboard.js` after contract changes to sync ABIs.

## Support & Contribution

**Code Style:**

-   Follow existing patterns
-   Run linters before committing
-   Add tests for new features
-   Update documentation

**Pull Requests:**

-   Test thoroughly on local fork
-   Update README if needed
-   Follow conventional commit messages
-   Request review from maintainers

# Mocking strategy
Never create mock ERC classes. In case it is requeried use Utils.writeTokenBalance

