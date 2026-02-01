# Security Improvements

This document outlines the security issues identified and fixed in the Eswap Margin Protocol.

## 1. Oracle Price Validation (Chainlink)

**Issue**: The contract `PriceFeedL1.sol` was using `latestRoundData()` from Chainlink AggregatorV3Interface but failed to validate the returned data for staleness. This could allow the protocol to use outdated prices if the oracle stopped updating.
**Fix**: Added checks for `price > 0`, `updatedAt != 0`, and `answeredInRound >= roundId`.
**Location**: `src/PriceFeedL1.sol`

## 2. Sandwich Attack Protection (Slippage Control)

**Issue**: The `UniswapV3Helper.sol` contract (and its usage in `Positions.sol`) hardcoded `amountOutMinimum` to `0` when calling `swapExactInputSingle`. This allowed front-running bots (sandwich attacks) to manipulate the pool price before the transaction, causing the protocol to receive significantly fewer tokens than expected during margin trades (borrowing/shorting) or liquidations.
**Fix**:
- Updated `UniswapV3Helper.swapExactInputSingle` to accept `amountOutMinimum`.
- Updated `Positions.sol` to calculate the expected output amount using the Oracle Price (via `PriceFeedL1`) and apply a 5% slippage tolerance. This value is passed as `amountOutMinimum`.
**Location**: `src/UniswapV3Helper.sol`, `src/Positions.sol`

## 3. Decimal Handling Safety

**Issue**: In `PriceFeedL1.sol`, the calculation `10**(18 - decimals)` could underflow if a token had more than 18 decimals, causing a revert (DoS).
**Fix**: Added a check to handle cases where `decimals > 18` by dividing instead of multiplying.
**Location**: `src/PriceFeedL1.sol`

## 4. Reentrancy Protection

**Issue**: The `openPosition` function in `Positions.sol` interacts with external contracts (Tokens, Uniswap, LiquidityPool) and mints an ERC721 token (which triggers `onERC721Received` on the recipient). While `safeMint` handles the state variable update (`posId`) before minting, it is best practice to prevent reentrancy, especially as the function performs complex state changes and external calls.
**Fix**: Added `nonReentrant` modifier to `openPosition`.
**Location**: `src/Positions.sol`

## 5. Mock Testing Security

**Update**: Updated `MockUniswapV3Helper` to respect the new `amountOutMinimum` parameter and verify slippage constraints in tests.
**Location**: `test/mocks/MockUniswapV3Helper.sol`
