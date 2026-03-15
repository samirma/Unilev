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
 * Final Balance Formula:
 * - finalBalance = initialBalance + pnl
 * - The PnL value from the contract already includes all fees (swap fees + protocol fees)
 */
contract LeveragedTradeLongMock is TestSetupMock {
    
    // ===================================================================
    // COLLATERAL AND LEVERAGE CONFIGURATION
    // ===================================================================
    uint128 constant COLLATERAL_AMOUNT = 100e6;  // 100 USDC
    uint24 constant FEE_TIER = 3000;              // 0.3% Uniswap fee tier
    
    // ===================================================================
    // PRICE CHANGE CONSTANTS (in basis points, 1 bp = 0.01%)
    // Adjusted empirically to achieve target PnL accounting for swap fees
    // Formula reference: Target PnL / (Collateral * Leverage) * 10000
    // ===================================================================
    
    // 2x Leverage Price Changes (adjusted for 0.3% swap fees)
    uint256 constant PRICE_CHANGE_1_USDC_2X = 50;      // ~0.5% for ~1 USDC profit
    uint256 constant PRICE_CHANGE_10_USDC_2X = 460;    // ~4.6% for ~10 USDC profit (was 500)
    uint256 constant PRICE_CHANGE_50_USDC_2X = 2300;   // ~23% for ~50 USDC profit (was 2500)
    
    // 3x Leverage Price Changes (smaller % needed due to higher leverage)
    uint256 constant PRICE_CHANGE_1_USDC_3X = 34;      // ~0.34% for ~1 USDC profit
    uint256 constant PRICE_CHANGE_10_USDC_3X = 307;    // ~3.07% for ~10 USDC profit (was 334)
    uint256 constant PRICE_CHANGE_50_USDC_3X = 1533;   // ~15.33% for ~50 USDC profit (was 1667)
    
    // ===================================================================
    // EXPECTED PnL VALUES (in USDC with 6 decimals)
    // These are the TARGET PnL values we expect to achieve
    // Actual PnL from contract includes all fees (swap + protocol)
    // ===================================================================
    int256 constant TARGET_PROFIT_1_USDC = 1e6;        // 1 USDC
    int256 constant TARGET_PROFIT_10_USDC = 10e6;      // 10 USDC
    int256 constant TARGET_PROFIT_50_USDC = 50e6;      // 50 USDC
    int256 constant TARGET_LOSS_1_USDC = -1e6;         // -1 USDC
    int256 constant TARGET_LOSS_10_USDC = -10e6;       // -10 USDC
    int256 constant TARGET_LOSS_50_USDC = -50e6;       // -50 USDC
    
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
    // 2x LEVERAGE - PROFIT TESTS
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

        // Open long position with 2x leverage
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), COLLATERAL_AMOUNT);
        market.openLongPosition(usdc, wbtc, FEE_TIER, 2, COLLATERAL_AMOUNT, 0, 0);
        vm.stopPrank();

        uint256 positionId = positions.getTraderPositions(alice)[0];

        // Increase price by 0.5% to get ~1 USDC profit
        // Math: 200 USDC position * 0.5% = 1 USDC
        int256 newPrice = getPriceWithBpsChange(100_000 * 1e8, PRICE_CHANGE_1_USDC_2X, true);
        vm.startPrank(deployer); 
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice); 
        vm.stopPrank();

        // Verify PnL
        int256 pnl = getPositionPnL(positionId);
        assertGt(pnl, 0, "PnL should be positive for long profit");
        assertApproxEqAbs(uint256(pnl), uint256(TARGET_PROFIT_1_USDC), PNL_TOLERANCE);

        // Close position and verify final balance = initial + pnl (pnl includes fees)
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

        // Increase price by ~4.6% to get ~10 USDC profit
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

        // Increase price by ~23% to get ~50 USDC profit
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

        // With 3x leverage, need smaller price change for same PnL
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

        // Decrease price by 0.5% to get ~1 USDC loss
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
        
        // finalBalance = initialBalance + pnl (pnl is negative and includes fees)
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

        // Decrease price by ~4.6% to get ~10 USDC loss
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

        // Decrease price by ~23% to get ~50 USDC loss
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

    // ===================================================================
    // UTILITY TESTS
    // ===================================================================

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
        
        // Drop ETH price to liquidate positions
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
