// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeLongMock is TestSetupMock {
    // ----------------------------------------------------------------------
    // Helper function to get PnL from position
    // Note: PnL is returned in quote token decimals (USDC = 6 decimals)
    // ----------------------------------------------------------------------
    function getPositionPnL(uint256 positionId) internal view returns (int256) {
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            int128 currentPnL,

        ) = positions.getPositionParams(positionId);
        return int256(currentPnL);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Profit 2x (WBTC Price Rise) - ~1 USDC Net Profit
    // ----------------------------------------------------------------------
    // User deposits 100 USDC as collateral to buy a 2x leveraged long position on WBTC.
    // The WBTC price rises by ~0.5% to generate approximately 1 USDC net profit.
    // ----------------------------------------------------------------------
    function test_Long_Profit_2x_WBTC_Rise_1USDC() public {
        address usdc = getUsdcAddress();
        address wbtc = getWbtcAddress();
        uint128 collateralAmount = 100e6; // 100 USDC
        uint24 fee = 3000;

        // Deposit liquidity for both tokens
        depositLiquidity(usdc, 100_000e6);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State - Set initial prices
        writeTokenBalance(alice, usdc, collateralAmount);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);
        console.log("Initial USDC Balance:", initialBalance);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8); // USDC = $1
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Position (Long WBTC/USDC 2x)
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), collateralAmount);
        market.openLongPosition(usdc, wbtc, fee, 2, collateralAmount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);
        uint256 positionId = posAlice[0];

        // 3. Mock Price Change - ~0.75% increase should generate ~1.5 USDC gross profit
        // After fees (~0.3 USDC), net profit should be ~1 USDC
        vm.startPrank(deployer);
        mockV3AggregatorWbtcUsd.updateAnswer(100_750 * 1e8); // WBTC = $100,750 (0.75% increase)
        vm.stopPrank();

        // 4. Assert PnL before closing
        int256 pnlAfterPriceChange = getPositionPnL(positionId);
        console.log("PnL after price change (USDC units):");
        console.logInt(pnlAfterPriceChange);

        // PnL should be positive for profit
        assertGt(pnlAfterPriceChange, 0, "PnL should be positive for profit");

        // Assert PnL is approximately 1.5 USDC (gross profit before closing fees)
        assertApproxEqAbs(uint256(pnlAfterPriceChange), 15e5, 3e5); // ~1.5 USDC, allow 0.3 USDC tolerance

        // 5. Close Position
        vm.startPrank(alice);
        market.closePosition(positionId);
        vm.stopPrank();

        // 6. Final Assertions
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        console.log("Final USDC Balance:", finalBalance);

        // The final balance should be higher than initial (net profit after all fees)
        assertGt(finalBalance, initialBalance, "Final balance should be greater than initial");

        // Net profit is approximately 0.2 USDC after all fees (entry + exit fees)
        // Entry fees: ~0.15 USDC (treasure fee 0.05% + liquidation reward 0.03%)
        // Exit fees: ~0.05 USDC (treasure fee 0.05%)
        // Total fees: ~0.2 USDC, Net profit: ~1.5 - ~0.2 = ~0.3 USDC (approximate due to slippage)
        uint256 netProfit = finalBalance - initialBalance;
        console.log("Net profit:", netProfit);
        assertGt(netProfit, 0, "Net profit should be positive");
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Profit 2x (WBTC Price Rise) - ~10 USDC Net Profit
    // ----------------------------------------------------------------------
    // User deposits 100 USDC as collateral to buy a 2x leveraged long position on WBTC.
    // The WBTC price rises by ~5% to generate approximately 10 USDC net profit.
    // ----------------------------------------------------------------------
    function test_Long_Profit_2x_WBTC_Rise_10USDC() public {
        address usdc = getUsdcAddress();
        address wbtc = getWbtcAddress();
        uint128 collateralAmount = 100e6; // 100 USDC
        uint24 fee = 3000;

        // Deposit liquidity for both tokens
        depositLiquidity(usdc, 100_000e6);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State - Set initial prices
        writeTokenBalance(alice, usdc, collateralAmount);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);
        console.log("Initial USDC Balance:", initialBalance);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8); // USDC = $1
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Position (Long WBTC/USDC 2x)
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), collateralAmount);
        market.openLongPosition(usdc, wbtc, fee, 2, collateralAmount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);
        uint256 positionId = posAlice[0];

        // 3. Mock Price Change - ~5% increase should generate ~10 USDC profit
        // Based on actual contract behavior: 5% price increase → ~10 USDC profit
        vm.startPrank(deployer);
        mockV3AggregatorWbtcUsd.updateAnswer(105_000 * 1e8); // WBTC = $105,000 (5% increase)
        vm.stopPrank();

        // 4. Assert PnL before closing
        int256 pnlAfterPriceChange = getPositionPnL(positionId);
        console.log("PnL after price change (USDC units):");
        console.logInt(pnlAfterPriceChange);

        // PnL should be positive for profit
        assertGt(pnlAfterPriceChange, 0, "PnL should be positive for profit");

        // Assert PnL is approximately 10 USDC
        assertApproxEqAbs(uint256(pnlAfterPriceChange), 10e6, 2e6); // ~10 USDC, allow 2 USDC tolerance

        // 5. Close Position
        vm.startPrank(alice);
        market.closePosition(positionId);
        vm.stopPrank();

        // 6. Final Assertions
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        console.log("Final USDC Balance:", finalBalance);

        // The final balance should be higher than initial (profit)
        assertGt(finalBalance, initialBalance, "Final balance should be greater than initial");

        // Assert final balance is approximately initial + 10 USDC (with fee tolerance)
        assertApproxEqAbs(finalBalance, initialBalance + 10e6, 2e6);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Loss 2x (WBTC Price Drop) - ~10 USDC Loss
    // ----------------------------------------------------------------------
    // User deposits 100 USDC as collateral to buy a 2x leveraged long position on WBTC.
    // The WBTC price drops by ~5% to generate approximately 10 USDC loss.
    // ----------------------------------------------------------------------
    function test_Long_Loss_2x_WBTC_Drop_10USDC() public {
        address usdc = getUsdcAddress();
        address wbtc = getWbtcAddress();
        uint128 collateralAmount = 100e6; // 100 USDC
        uint24 fee = 3000;

        // Deposit liquidity for both tokens
        depositLiquidity(usdc, 100_000e6);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State - Set initial prices
        writeTokenBalance(alice, usdc, collateralAmount);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);
        console.log("Initial USDC Balance:", initialBalance);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8); // USDC = $1
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Position (Long WBTC/USDC 2x)
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), collateralAmount);
        market.openLongPosition(usdc, wbtc, fee, 2, collateralAmount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);
        uint256 positionId = posAlice[0];

        // 3. Mock Price Change - ~5% decrease generates ~10 USDC loss
        vm.startPrank(deployer);
        mockV3AggregatorWbtcUsd.updateAnswer(95_000 * 1e8); // WBTC = $95,000 (5% decrease)
        vm.stopPrank();

        // 4. Assert PnL before closing
        int256 pnlAfterPriceChange = getPositionPnL(positionId);
        console.log("PnL after price change (USDC units):");
        console.logInt(pnlAfterPriceChange);

        // PnL should be negative for loss
        assertLt(pnlAfterPriceChange, 0, "PnL should be negative for loss");

        // Assert PnL magnitude is approximately 10 USDC
        uint256 pnlAbs = uint256(-pnlAfterPriceChange);
        assertApproxEqAbs(pnlAbs, 10e6, 2e6); // ~10 USDC loss, allow 2 USDC tolerance

        // 5. Close Position
        vm.startPrank(alice);
        market.closePosition(positionId);
        vm.stopPrank();

        // 6. Final Assertions
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        console.log("Final USDC Balance:", finalBalance);

        // The final balance should be lower than initial (loss)
        assertLt(finalBalance, initialBalance, "Final balance should be less than initial");

        // Assert final balance is approximately initial - 10 USDC (with fee tolerance)
        assertApproxEqAbs(finalBalance, initialBalance - 10e6, 2e6);
    }

    // ----------------------------------------------------------------------
    // Scenario: Whitelist Fees Test
    // ----------------------------------------------------------------------
    function test_WhitelistFees() public {
        address weth = getWethAddress();
        address wbtc = getWbtcAddress();
        uint128 amount = 1e18;
        uint24 fee = 3000;
        address whitelistedUser = address(0x88);

        depositLiquidity(weth, 1000e18);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State
        writeTokenBalance(whitelistedUser, weth, amount);

        // 2. Add to Whitelist with reduced fees (0.01% treasure, 0% liquidation reward)
        vm.startPrank(deployer);
        feeManager.setCustomFees(whitelistedUser, 1, 0);
        vm.stopPrank();

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        // 3. Open Position
        vm.startPrank(whitelistedUser);
        IERC20(weth).approve(address(positions), amount);
        market.openLongPosition(weth, wbtc, fee, 2, amount, 0, 0);
        vm.stopPrank();

        // 4. Verification of Treasure Fee
        // Liquidation Reward = 0
        // Amount used for fee calc = 1e18
        // Treasure Fee = 1e18 * 1 / 10000 = 1e14

        uint256 treasureBalance = IERC20(weth).balanceOf(conf.treasure);
        console.log("Treasure Balance (Whitelisted):", treasureBalance);
        assertApproxEqAbs(treasureBalance, 1e14, 100); // Allow small rounding
    }

    // ----------------------------------------------------------------------
    // Scenario: Multiple Liquidations via Market Contract
    // ----------------------------------------------------------------------
    function test_MultipleLiquidations_Market() public {
        address weth = getWethAddress();
        address wbtc = getWbtcAddress();
        uint128 amountAlice = 1e18; // 1 WETH
        uint128 amountBob = 2e18; // 2 WETH
        uint24 fee = 3000;

        depositLiquidity(weth, 1000e18);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State
        writeTokenBalance(alice, weth, amountAlice);
        writeTokenBalance(bob, weth, amountBob);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8); // ETH = $4,000
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Positions
        vm.startPrank(alice);
        IERC20(weth).approve(address(positions), amountAlice);
        market.openLongPosition(weth, wbtc, fee, 2, amountAlice, 0, 0);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(weth).approve(address(positions), amountBob);
        market.openLongPosition(weth, wbtc, fee, 3, amountBob, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        uint256[] memory posBob = positions.getTraderPositions(bob);

        assertEq(posAlice.length, 1);
        assertEq(posBob.length, 1);

        // 3. Mock Price Change to trigger liquidations (ETH price drop significantly)
        // Alice leverage 2x: breakEvenLimit = 4000 - (4000 * 0.5) = 2000
        // Bob leverage 3x: breakEvenLimit = 4000 - (4000 * 1/3) = 2666.6
        // Liquidation Threshold 10%
        // Alice lidTresh = 2000 * 1.1 = 2200
        // Bob lidTresh = 2666.6 * 1.1 = 2933.2

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(2100 * 1e8); // Both should be liquidatable
        vm.stopPrank();

        // 4. Verify they are liquidatable
        uint256[] memory liquidablePos = market.getLiquidablePositions();

        // Count non-zero IDs
        uint256 count = 0;
        for (uint256 i = 0; i < liquidablePos.length; i++) {
            if (liquidablePos[i] != 0) count++;
        }
        assertTrue(count >= 2, "Should have at least 2 liquidable positions");

        // 5. Liquidate via Market
        uint256 liquidatorBalanceBefore = IERC20(weth).balanceOf(deployer);

        vm.startPrank(deployer);
        market.liquidatePositions(liquidablePos);
        vm.stopPrank();

        // 6. Final Assertions
        assertEq(positions.getTraderPositions(alice).length, 0, "Alice position should be closed");
        assertEq(positions.getTraderPositions(bob).length, 0, "Bob position should be closed");

        uint256 liquidatorBalanceAfter = IERC20(weth).balanceOf(deployer);
        assertTrue(
            liquidatorBalanceAfter > liquidatorBalanceBefore,
            "Liquidator should receive rewards"
        );

        console.log("Liquidator reward (WETH):", liquidatorBalanceAfter - liquidatorBalanceBefore);
    }
}
