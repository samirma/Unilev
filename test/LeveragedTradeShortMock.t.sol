// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

/**
 * @title LeveragedTradeShortMock
 * @notice Test suite for short leveraged positions with 2x and 3x leverage
 * @dev PnL Calculation Logic for Shorts:
 * - Collateral: 100 USDC
 * - 2x leverage: Position size = 200 USDC worth of WBTC borrowed and sold
 * - 3x leverage: Position size = 300 USDC worth of WBTC borrowed and sold
 * - Short PnL = Position Size * (Entry Price - Exit Price) / Entry Price
 * - Example: 200 USDC short, price drops 0.5% = 1 USDC profit
 * 
 * Price Change Formula (for target PnL):
 * - Same as longs: Price Change % = Target PnL / (Collateral * Leverage)
 * - For 1 USDC with 2x: 1 / (100 * 2) = 0.5% = 50 bps
 * - For 10 USDC with 2x: 10 / (100 * 2) = 5% = 500 bps
 * - For 50 USDC with 2x: 50 / (100 * 2) = 25% = 2500 bps
 * 
 * Note: For shorts, price DECREASE creates profit, price INCREASE creates loss
 */
contract LeveragedTradeShortMock is TestSetupMock {
    
    // ===================================================================
    // COLLATERAL AND LEVERAGE CONFIGURATION
    // ===================================================================
    uint128 constant COLLATERAL_AMOUNT = 100e6;  // 100 USDC
    uint24 constant FEE_TIER = 3000;              // 0.3% Uniswap fee tier
    
    // ===================================================================
    // PRICE CHANGE CONSTANTS (in basis points, 1 bp = 0.01%)
    // Same as longs - price movement magnitude determines PnL
    // ===================================================================
    
    // 2x Leverage Price Changes
    uint256 constant PRICE_CHANGE_1_USDC_2X = 50;      // 0.5% for 1 USDC PnL
    uint256 constant PRICE_CHANGE_10_USDC_2X = 500;    // 5% for 10 USDC PnL  
    uint256 constant PRICE_CHANGE_50_USDC_2X = 2500;   // 25% for 50 USDC PnL
    
    // 3x Leverage Price Changes (smaller % needed due to higher leverage)
    uint256 constant PRICE_CHANGE_1_USDC_3X = 34;      // 0.34% for 1 USDC PnL
    uint256 constant PRICE_CHANGE_10_USDC_3X = 334;    // 3.34% for 10 USDC PnL
    uint256 constant PRICE_CHANGE_50_USDC_3X = 1667;   // 16.67% for 50 USDC PnL
    
    // ===================================================================
    // EXPECTED PnL VALUES (in USDC with 6 decimals)
    // Target PnL values - same magnitude as longs
    // ===================================================================
    int256 constant TARGET_PROFIT_1_USDC = 1e6;        // 1 USDC
    int256 constant TARGET_PROFIT_10_USDC = 10e6;      // 10 USDC
    int256 constant TARGET_PROFIT_50_USDC = 50e6;      // 50 USDC
    int256 constant TARGET_LOSS_1_USDC = -1e6;         // -1 USDC
    int256 constant TARGET_LOSS_10_USDC = -10e6;       // -10 USDC
    int256 constant TARGET_LOSS_50_USDC = -50e6;       // -50 USDC
    
    // ===================================================================
    // EXPECTED NET BALANCE CHANGES (PnL after all fees)
    // Shorts have slightly different fee structure due to borrowing
    // ===================================================================
    uint256 constant NET_PROFIT_1_USDC = 1e6 - 6e5;     // ~0.4 USDC net
    uint256 constant NET_PROFIT_10_USDC = 10e6 - 7e5;   // ~9.3 USDC net
    uint256 constant NET_PROFIT_50_USDC = 50e6 - 1e6;   // ~49 USDC net
    uint256 constant NET_LOSS_1_USDC = 1e6 + 6e5;       // ~1.6 USDC total loss
    uint256 constant NET_LOSS_10_USDC = 10e6 + 7e5;     // ~10.7 USDC total loss
    uint256 constant NET_LOSS_50_USDC = 50e6 + 1e6;     // ~51 USDC total loss
    
    // ===================================================================
    // TOLERANCE FOR ASSERTIONS
    // ===================================================================
    uint256 constant PNL_TOLERANCE = 1e6;
    uint256 constant BALANCE_TOLERANCE = 1e6;

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
    // 2x LEVERAGE - PROFIT TESTS (Price drops for short profit)
    // ===================================================================

    function test_Profit_of_1_USDC() public {
        address usdc = getUsdcAddress(); 
        address wbtc = getWbtcAddress();
        
        depositLiquidity(usdc, 100_000e6); 
        depositLiquidity(wbtc, 10e8);
        writeTokenBalance(alice, usdc, COLLATERAL_AMOUNT);
        uint256 initialBalance = IERC20(usdc).balanceOf(alice);

        // Setup: WBTC = $100,000, USDC = $1
        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100_000 * 1e8);
        vm.stopPrank();

        // Open short position with 2x leverage
        // Borrows WBTC, sells for USDC
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Decrease price by 0.5% to get ~1 USDC profit
        // Math: 200 USDC position * 0.5% = 1 USDC profit for short
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        // Verify PnL
        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit (price dropped)");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_1_USDC), PNL_TOLERANCE);

        // Close position and verify net result
        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_1_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Decrease price by 5% to get ~10 USDC profit
        // Math: 200 USDC position * 5% = 10 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_10_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Decrease price by 25% to get ~50 USDC profit
        // Math: 200 USDC position * 25% = 50 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_2X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_50_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // With 3x leverage, need smaller price drop for same PnL
        // Math: 300 USDC position * 0.34% ≈ 1 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_1_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Math: 300 USDC position * 3.34% ≈ 10 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_10_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Math: 300 USDC position * 16.67% ≈ 50 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_3X, false);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for short profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT + NET_PROFIT_50_USDC;
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }

    // ===================================================================
    // 2x LEVERAGE - LOSS TESTS (Price increases for short loss)
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Increase price by 0.5% to get ~1 USDC loss for short
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss (price increased)");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_1_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Increase price by 5% to get ~10 USDC loss
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_10_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Increase price by 25% to get ~50 USDC loss
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_50_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_1_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_1_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_10_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_10_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_10_USDC;
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
        market.openShortPosition(usdc, wbtc, FEE_TIER, 3, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_50_USDC_3X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        int256 pnl = getPositionPnL(positionId);
        assertLt(pnl, 0, "PnL should be negative for short loss");
        assertApproxEqAbs(uint256(-pnl), uint256(-TARGET_LOSS_50_USDC), PNL_TOLERANCE);

        vm.startPrank(alice); 
        market.closePosition(positionId); 
        vm.stopPrank();
        
        uint256 expectedBalance = initialBalance - COLLATERAL_AMOUNT - NET_LOSS_50_USDC;
        assertApproxEqAbs(IERC20(usdc).balanceOf(alice), expectedBalance, BALANCE_TOLERANCE);
    }
}
