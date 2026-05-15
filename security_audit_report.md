# Unilev Protocol Security Audit Report
**Date:** April 10, 2026
**Target Architecture:** Unilev Margin Trading Protocol (`Positions.sol`, `Market.sol`, `LiquidityPool.sol`, `PositionLogic.sol`, `FeeManager.sol`, `PriceFeedL1.sol`)

## 1. Executive Summary
An in-depth security analysis and emulation of edge cases were conducted on the Unilev Protocol. The protocol showcases an excellent overarching architectural design—particularly in standardizing cross-token math and protecting positional opening swaps against flash-loan attacks by strongly coupling exact-sizing requirements to Chainlink Oracles. 

However, **two CRITICAL vulnerabilities** were discovered during position closure logic, specifically involving how the `UniswapV3SwapRouter` is interfaced when reimbursing borrowed funds. These flaws represent an immediate threat to user funds (via 100% MEV extraction) and protocol solvency (via denial-of-service on bad-debt liquidations).

---

## 2. Security Findings (Categorized)

### [CRITICAL-1] Denial of Service (DoS) / Insolvency via Unliquidatable Bad Debt
**Attack Vector:** Logic flow revert on insolvency.
**Location:** `Positions.sol` -> `_closePosition()`

**Description:**
To refund the `LiquidityPool` during closure, the protocol uses `swapMaxTokenPossible()`, which inherently delegates to Uniswap V3's `exactOutputSingle`:
```solidity
uint256 swapCost = UNISWAP_V3_HELPER.swapExactOutputSingle(
    _token0,           /* addTokenReceived (Remaining positionSize) */
    _token1,           /* addTokenBorrowed (tokenToTrader) */
    _fee,
    amountOut,         /* MUST be exactly posParms.totalBorrow */
    amountInMaximum    /* Hard limited to amountTokenReceived */
);
```
Uniswap's exact-output swaps mandate that the `amountOut` is purchased strictly using `<= amountInMaximum`. If a position enters `PositionState.BAD_DEBT`, the aggregate value of the remaining collateral (`amountTokenReceived`) mathematically drops below the cost required to buy `totalBorrow`.

Because the required cost exceeds `amountInMaximum`, the Uniswap Router will cleanly revert the transaction (typically with `"Too much requested"`). 

**Impact:**
Any position that becomes insolvent or drops sufficiently far into negative equity will **revert on every liquidation attempt**. The position remains permanently unclosed, preventing the `LiquidityPool` from ever recovering its funds or marking down the structural loss. This constitutes a permanent lock of LP capital.

**Recommendation:**
Refactor the margin refund logic to act as a fallback:
1. Try to query the required swap cost using the oracle or standard swap quotes.
2. If `requiredCost > amountTokenReceived` (indicating bad debt), switch routing methods. Use `exactInputSingle` to dump `100%` of `amountTokenReceived` to retrieve *as much of the borrowed token as possible*.
3. The remaining deficit between `totalBorrow` and the received amount becomes the absolute `loss`, which is then correctly processed by `LiquidityPool.refund()`.

---

### [CRITICAL-2] Guaranteed MEV Sandwich Extraction on Position Closure
**Attack Vector:** Missing Oracle Bounds (Sandwich Attack / Slippage Extraction).
**Location:** `Positions.sol` -> `_closePosition()` (and `swapMaxTokenPossible()`)

**Description:**
While opening a position is safely protected against slippage via `minOutBorrow` deriving from the `PRICE_FEED`, **closing the position lacks this protection**. 
When repaying the pool via `swapExactOutputSingle`, the protocol blindly sets `amountInMaximum` to be the user's *entire outstanding position size*:
```solidity
(uint256 inAmount, uint256 outAmount) = swapMaxTokenPossible(
    addTokenReceived,
    tokenToTrader,
    poolFee,
    posParms.totalBorrow,
    amountTokenReceived /* The entire position balance */
);
```

Because `amountInMaximum` has no oracle-derived limiter, it mathematically gives permission to the Uniswap pool to consume up to 100% of the trader's balance to fulfill `totalBorrow`. 
An MEV searcher observing a `closePosition`, `TAKE_PROFIT`, or `STOP_LOSS` transaction in the mempool will:
1. Front-run the transaction by flash-loaning and skewing the Uniswap pool price aggressively.
2. The `swapExactOutputSingle` executes, forcing the user to pay an astronomical spread, draining their entire `amountTokenReceived` value solely to buy `totalBorrow`.
3. The MEV searcher back-runs the closure and casually arbitrage-extracts the user's drained collateral and trading profits as pure profit.

**Impact:**
Traders using leverage are guaranteed to lose virtually all of their collateral and profit when closing positions on networks with active MEV searchers. Limit orders (`TAKE_PROFIT`) are especially susceptible as liquidators themselves can orchestrate the sandwich attack while simultaneously collecting the `liquidationReward`.

**Recommendation:**
Enforce strict oracle bounds on `amountInMaximum` using `PRICE_FEED`:
```solidity
uint256 fairSwapCost = (posParms.totalBorrow * priceFeedRate) / baseDecimalsPow;
uint256 maxSwapCost = (fairSwapCost * SLIPPAGE_TOLERANCE) / 10000;
// Only allow 'maxSwapCost' as the ceiling, replacing 'amountTokenReceived'
```

---

### [LOW-1] Read-Only Reentrancy & Checks-Effects-Interactions (CEI) Violation 
**Location:** `Positions.sol` -> `_closePosition()`

**Description:**
During positon settlement, ERC20 tokens are externally sent to the trader prior to clearing the position tracking mapping and burning the NFT:
```solidity
tokenToTraderErc20.safeTransfer(trader, netReceived);
// ...
delete openPositions[_posId];
safeBurn(_posId);
```
**Impact:**
Although standard reentrancy attacks into Unilev's state-modifying functions are mitigated because of `nonReentrant`, an external contract querying `getPositionState()` or `getPositionParams()` during the token transfer hook will read the position as fully open and populated, despite its underlying funds having been drained and distributed. 

**Recommendation:**
Shift `delete openPositions[_posId];` and `safeBurn(_posId);` above external token transfers to adhere linearly to Checks-Effects-Interactions (CEI).

---

### [INFO-1] Missing L2 Sequencer Uptime Validation 
**Location:** `PriceFeedL1.sol`
**Background:** The repository specifications (`AGENTS.md`) define deployment to L2s like Base and Polygon (zkEVM/PoS).

**Description:**
While standard chainlink criteria (`latestRoundData`, `timestamp` staleness checks) are perfectly implemented:
```solidity
uint256 priceAge = block.timestamp - updatedAt;
if (priceAge > stalenessThreshold) revert PriceFeedL1__PRICE_TOO_OLD();
```
Chainlink explicitly advises that feeds natively deployed on Optimistic rollups (such as Base) *must* check the Sequencer Uptime feed. If the Base sequencer suffers an outage, L2 trades and oracles hang. Upon restarting, massive retroactive volatility can cascade before Chainlink has a chance to update the price, causing unfair liquidations.

**Recommendation:**
Incorporate the Chainlink Sequencer Uptime feature block in `PriceFeedL1` specifically for L2 deployments (e.g. Base, Arbitrum) which reverts or gracefully delays actions if the sequencer was flagged as recently down. 

---

## 3. Highly Commendable Design / Structural Strengths
During the audit process, several common vulnerabilities were vetted and verified as perfectly mitigated by your existing structural design:
* **Flash Loan Attacks Mitigated:** You calculate `totalBorrow` leveraging off-chain oracles instead of AMM TWAPs. A flash-loan attacker cannot skew your entry sizing/debt assumptions.
* **Safe Asset Scaling Mitigated:** PositionLogic’s logic natively and beautifully resolves cross-currency interactions across drastically disconnected decimals (e.g., matching WBTC's 8 decimal parameters into USDC's 6 decimal bounds securely.)
* **Loss Distribution:** Your mechanism properly passes `loss` variables to the `LiquidityPool` via `refund(totalBorrow, 0, loss)`, dynamically pulling out bad debt from pool shares without bricking total asset scaling or reverting.
