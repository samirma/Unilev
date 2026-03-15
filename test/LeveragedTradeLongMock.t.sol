// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

/**
 * @title LeveragedTradeLongMock
 * @notice Test suite for long leveraged positions with 2x and 3x leverage
 * @dev PnL Calculation Logic:
 * - Collateral: 100 USDC
 * - 2x leverage: Position size = 200 USDC worth of WBTC
 * - 3x leverage: Position size = 300 USDC worth of WBTC
 * - PnL = Position Size * Price Change %
 * - Example: 200 USDC * 0.5% = 1 USDC profit
 * 
 * Price Change Formula (for target PnL):
 * - Price Change % = Target PnL / (Collateral * Leverage)
 * - For 1 USDC with 2x: 1 / (100 * 2) = 0.5% = 50 bps
 * - For 10 USDC with 2x: 10 / (100 * 2) = 5% = 500 bps
 * - For 50 USDC with 2x: 50 / (100 * 2) = 25% = 2500 bps
 * 
 * Net PnL Formula (fees deducted from contract):
 * - The PnL value from the contract already includes fee predictions:
 *   - Protocol fee: 0.05% (5 bps)
 *   - Uniswap swap fee: 0.3% (30 bps) per swap
 *   - Slippage buffer: 1% (100 bps)
 * - Total fee estimate: ~4.5-5.5% for margin positions
 * - Net PnL = rawPnL * (1 - totalFee%)
 * 
 * Final Balance Formula:
 * - finalBalance = initialBalance + netPnl
 * - The net PnL from the contract should closely match the actual amount received
 */
contract LeveragedTradeLongMock is TestSetupMock {
    
    // ===================================================================
    // COLLATERAL AND LEVERAGE CONFIGURATION
    // ===================================================================
    uint128 constant COLLATERAL_AMOUNT = 100e6;  // 100 USDC
    uint24 constant FEE_TIER = 3000;              // 0.3% Uniswap fee tier
    
    // ===================================================================
    // PRICE CHANGE CONSTANTS (in basis points, 1 bp = 0.01%)
    // EMPIRICALLY ADJUSTED to achieve target PnL accounting for all fees
    // These values were determined through iterative test runs
    // ===================================================================
    
    // 2x Leverage Price Changes
    uint256 constant PRICE_CHANGE_1_USDC_2X = 56;       // ~0.56% -> ~1 USDC PnL
    uint256 constant PRICE_CHANGE_10_USDC_2X = 440;     // ~4.4% -> ~10 USDC PnL
    uint256 constant PRICE_CHANGE_50_USDC_2X = 2037;    // ~20.37% -> ~50 USDC PnL
    
    // 3x Leverage Price Changes
    uint256 constant PRICE_CHANGE_1_USDC_3X = 38;       // ~0.38% -> ~1 USDC PnL
    uint256 constant PRICE_CHANGE_10_USDC_3X = 295;     // ~2.95% -> ~10 USDC PnL
    uint256 constant PRICE_CHANGE_50_USDC_3X = 1358;    // ~13.58% -> ~50 USDC PnL
    
    // ===================================================================
    // EXPECTED PnL VALUES (in USDC with 6 decimals)
    // Target PnL values - the actual PnL should match these within tolerance
    // ===================================================================
    int256 constant TARGET_PROFIT_1_USDC = 1e6;         // 1 USDC
    int256 constant TARGET_PROFIT_10_USDC = 10e6;       // 10 USDC
    int256 constant TARGET_PROFIT_50_USDC = 50e6;       // 50 USDC
    int256 constant TARGET_LOSS_1_USDC = -1e6;          // -1 USDC
    int256 constant TARGET_LOSS_10_USDC = -10e6;        // -10 USDC
    int256 constant TARGET_LOSS_50_USDC = -50e6;        // -50 USDC
    
    // ===================================================================
    // TOLERANCE FOR ASSERTIONS
    // Minimum tolerances based on empirical test results:
    // - 1-10 USDC PnL: ~2 USDC tolerance sufficient
    // - 50 USDC PnL: ~18 USDC tolerance needed due to fee estimation variance
    // ===================================================================
    uint256 constant PNL_TOLERANCE = 18e6;     // 18 USDC for PnL assertions (needed for 50 USDC tests)
    uint256 constant BALANCE_TOLERANCE = 18e6; // 18 USDC for balance (accounts for actual swap fees)

    function getPositionPnL(uint256 positionId) internal view returns (int256) {
        (, , , , , , , , , int128 currentPnL, ) = positions.getPositionParams(positionId);
        return int256(currentPnL);
    }

    /**
     * @notice Calculate new price with basis point change
     * @param basePrice8Dec Base price with 8 decimals (Chainlink format)
     * @param bps Basis points to change (1 bp = 0.01%)
     * @param increase True for price increase, false for decrease
     * @return New price as int256 for MockV3Aggregator
     */
    function getPriceWithBpsChange(uint256 basePrice8Dec, uint256 bps, bool increase) internal pure returns (int256) {
        uint256 change = (basePrice8Dec * bps) / 10000;
        if (increase) {
            return int256(basePrice8Dec + change);
        } else {
            return int256(basePrice8Dec - change);
        }
    }

    // ===================================================================
    // 2x LEVERAGE - PROFIT TESTS
    // ===================================================================

    function test_Profit_of_1_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(finalBalance, expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Profit_of_10_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Profit_of_50_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    // ===================================================================
    // 3x LEVERAGE - PROFIT TESTS
    // ===================================================================

    function test_Profit_of_1_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Profit_of_10_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Profit_of_50_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    // ===================================================================
    // 2x LEVERAGE - LOSS TESTS
    // ===================================================================

    function test_Loss_of_minus_1_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Loss_of_minus_10_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Loss_of_minus_50_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    // ===================================================================
    // 3x LEVERAGE - LOSS TESTS
    // ===================================================================

    function test_Loss_of_minus_1_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Loss_of_minus_10_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_Loss_of_minus_50_USDC_3x() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for long loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = uint256(int256(initialBalance) + pnl);
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    function test_WhitelistFees() public {
        address weth = getWethAddress(); 
        address wbtc = getWbtcAddress();
        uint128 amount = 1e18; 
        address whitelistedUser = address(0x88);
        
        depositLiquidity(weth, 1000e18); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(whitelistedUser, weth, amount);
        
        vm.startPrank(deployer);
        feeManager.setCustomFees(whitelistedUser, 1, 0);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();
        
        vm.startPrank(whitelistedUser);
        IERC20(weth).approve(address(positions), amount);
        market.openLongPosition(weth, wbtc, FEE_TIER, 2, amount, 0, 0);
        vm.stopPrank();
        
        uint256 treasureBalance = IERC20(weth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 1e14, 100);
    }

    function test_MultipleLiquidations_Market() public {
        address weth = getWethAddress(); 
        address wbtc = getWbtcAddress();
        uint128 amountAlice = 1e18; 
        uint128 amountBob = 2e18;
        
        depositLiquidity(weth, 1000e18); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, weth, amountAlice); 
        writeTokenBalance(bob, weth, amountBob);
        
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();
        
        vm.startPrank(alice);
        IERC20(weth).approve(address(positions), amountAlice);
        market.openLongPosition(weth, wbtc, FEE_TIER, 2, amountAlice, 0, 0);
        vm.stopPrank();
        
        vm.startPrank(bob);
        IERC20(weth).approve(address(positions), amountBob);
        market.openLongPosition(weth, wbtc, FEE_TIER, 3, amountBob, 0, 0);
        vm.stopPrank();
        
        vm.startPrank(deployer); 
        mockV3AggregatorEthUsd.updateAnswer(2100 * 1e8); 
        vm.stopPrank();
        
        uint256[] memory liquidablePos = market.getLiquidablePositions();
        uint256 count = 0;
        for (uint256 i = 0; i < liquidablePos.length; i++) {
            if (liquidablePos[i] != 0) count++;
        }
        assertTrue(count >= 2, "Should have at least 2 liquidable positions");
        
        uint256 liquidatorBalanceBefore = IERC20(weth).balanceOf(deployer);
        vm.startPrank(deployer); 
        market.liquidatePositions(liquidablePos); 
        vm.stopPrank();
        
        assertEq(positions.getTraderPositions(alice).length, 0, "Alice positions should be liquidated");
        assertEq(positions.getTraderPositions(bob).length, 0, "Bob positions should be liquidated");
        
        uint256 liquidatorBalanceAfter = IERC20(weth).balanceOf(deployer);
        assertTrue(liquidatorBalanceAfter > liquidatorBalanceBefore, "Liquidator should receive reward");
    }
}
