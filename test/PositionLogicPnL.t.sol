// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./utils/TestSetupMock.sol";
import {PositionLogic} from "../src/libraries/PositionLogic.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title PositionLogicPnLTest
 * @notice Unit tests for PositionLogic.calculatePnL function
 * @dev Tests all scenarios from requeriments.md:
 * - Long positions: profit/loss with 2x and 3x leverage
 * - Short positions: profit/loss with 2x and 3x leverage
 * - USDC collateral (6 decimals) and WETH collateral (18 decimals)
 */
contract PositionLogicPnLTest is TestSetupMock {
    
    // Price constants (8 decimals for Chainlink)
    int256 constant WBTC_BASE_PRICE = 100_000e8; // $100,000
    
    function setUp() public override {
        super.setUp();
        
        // Set initial prices for the mocks
        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1e8);           // $1
        mockV3AggregatorWbtcUsd.updateAnswer(WBTC_BASE_PRICE); // $100,000
        mockV3AggregatorEthUsd.updateAnswer(4000e8);        // $4,000
        vm.stopPrank();
    }
    
    // ===================================================================
    // HELPER FUNCTIONS
    // ===================================================================
    
    function updateWbtcPrice(int256 newPrice) internal {
        mockV3AggregatorWbtcUsd.updateAnswer(newPrice);
    }
    
    function getUsdc() internal view returns (address) {
        return getUsdcAddress();
    }
    
    function getWbtc() internal view returns (address) {
        return getWbtcAddress();
    }
    
    function getWeth() internal view returns (address) {
        return getWethAddress();
    }
    
    // ===================================================================
    // LONG POSITION TESTS - USDC COLLATERAL - 2x LEVERAGE
    // ===================================================================
    
    function test_Long_2x_Profit_1_USDC() public {
        // Setup: 100 USDC collateral, 2x leverage, target +1 USDC
        // Position size = 200 USDC, need 0.5% price increase
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        // Get initial price BEFORE updating
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        
        // Now update price
        updateWbtcPrice(100_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(int256(result.currentPnL)), 1e6, 0.5e6, "PnL should be ~1 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_Profit_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 10e6, 1e6, "PnL should be ~10 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_Profit_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(125_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 50e6, 3e6, "PnL should be ~50 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_Loss_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(99_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 1e6, 0.5e6, "PnL should be ~-1 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_2x_Loss_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(95_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 10e6, 1e6, "PnL should be ~-10 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_2x_Loss_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(75_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 50e6, 3e6, "PnL should be ~-50 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // LONG POSITION TESTS - USDC COLLATERAL - 3x LEVERAGE
    // ===================================================================
    
    function test_Long_3x_Profit_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(100_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 1e6, 0.5e6, "PnL should be ~1 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_Profit_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(103_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 10e6, 1e6, "PnL should be ~10 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_Profit_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(116_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 50e6, 3e6, "PnL should be ~50 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_Loss_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(99_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 1e6, 0.5e6, "PnL should be ~-1 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_3x_Loss_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(96_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 10e6, 1e6, "PnL should be ~-10 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_3x_Loss_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(83_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 50e6, 3e6, "PnL should be ~-50 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // SHORT POSITION TESTS - USDC COLLATERAL - 2x LEVERAGE
    // ===================================================================
    
    function test_Short_2x_Profit_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(99_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 1e6, 0.5e6, "PnL should be ~1 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_Profit_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(95_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 10e6, 1e6, "PnL should be ~10 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_Profit_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(75_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 50e6, 3e6, "PnL should be ~50 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_Loss_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(100_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 1e6, 0.5e6, "PnL should be ~-1 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_2x_Loss_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 10e6, 1e6, "PnL should be ~-10 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_2x_Loss_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(125_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 50e6, 3e6, "PnL should be ~-50 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // SHORT POSITION TESTS - USDC COLLATERAL - 3x LEVERAGE
    // ===================================================================
    
    function test_Short_3x_Profit_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(99_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 1e6, 0.5e6, "PnL should be ~1 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_Profit_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(96_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 10e6, 1e6, "PnL should be ~10 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_Profit_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(83_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 50e6, 3e6, "PnL should be ~50 USDC");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_Loss_1_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(100_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 1e6, 0.5e6, "PnL should be ~-1 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_3x_Loss_10_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(103_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 10e6, 1e6, "PnL should be ~-10 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_3x_Loss_50_USDC() public {
        uint128 collateral = 100e6;
        uint8 leverage = 3;
        uint256 totalBorrow = 200e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(116_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 50e6, 3e6, "PnL should be ~-50 USDC");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // WETH COLLATERAL TESTS - LONG POSITIONS
    // ===================================================================
    
    function test_Long_2x_WETH_Profit_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(100_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~0.01 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_WETH_Profit_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~0.1 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_WETH_Profit_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(125_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~0.5 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_2x_WETH_Loss_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(99_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~-0.01 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_2x_WETH_Loss_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(95_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~-0.1 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_2x_WETH_Loss_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(75_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~-0.5 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // WETH COLLATERAL TESTS - LONG POSITIONS - 3x LEVERAGE
    // ===================================================================
    
    function test_Long_3x_WETH_Profit_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(100_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~0.01 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_WETH_Profit_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(103_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~0.1 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_WETH_Profit_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(116_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~0.5 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Long_3x_WETH_Loss_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(99_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~-0.01 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_3x_WETH_Loss_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(96_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~-0.1 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Long_3x_WETH_Loss_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(83_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~-0.5 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // WETH COLLATERAL TESTS - SHORT POSITIONS
    // ===================================================================
    
    function test_Short_2x_WETH_Profit_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(99_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~0.01 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_WETH_Profit_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(95_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~0.1 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_WETH_Profit_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(75_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~0.5 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_2x_WETH_Loss_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(100_500e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~-0.01 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_2x_WETH_Loss_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~-0.1 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_2x_WETH_Loss_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 2;
        uint256 totalBorrow = 1e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(125_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~-0.5 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // WETH COLLATERAL TESTS - SHORT POSITIONS - 3x LEVERAGE
    // ===================================================================
    
    function test_Short_3x_WETH_Profit_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(99_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~0.01 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_WETH_Profit_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(96_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~0.1 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_WETH_Profit_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(83_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~0.5 WETH");
        assertTrue(result.currentPnL > 0, "PnL should be positive");
    }
    
    function test_Short_3x_WETH_Loss_001() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(100_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.01e18, 0.005e18, "PnL should be ~-0.01 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_3x_WETH_Loss_01() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(103_333e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.1e18, 0.02e18, "PnL should be ~-0.1 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    function test_Short_3x_WETH_Loss_05() public {
        uint128 collateral = 1e18;
        uint8 leverage = 3;
        uint256 totalBorrow = 2e18;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(116_667e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: true,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertApproxEqAbs(uint256(uint128(-result.currentPnL)), 0.5e18, 0.05e18, "PnL should be ~-0.5 WETH");
        assertTrue(result.currentPnL < 0, "PnL should be negative");
    }
    
    // ===================================================================
    // EDGE CASE TESTS
    // ===================================================================
    
    function test_ZeroPriceChange() public view {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: initialPrice,
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        assertEq(result.currentPnL, 0, "PnL should be zero when price doesn't change");
        assertEq(result.collateralLeft, int128(collateral), "Collateral left should equal initial collateral");
    }
    
    function test_CollateralLeftCalculation() public {
        uint128 collateral = 100e6;
        uint8 leverage = 2;
        uint256 totalBorrow = 100e6;
        
        uint256 initialPrice = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(110_000e8);
        
        PositionLogic.PnLCalculationParams memory params = PositionLogic.PnLCalculationParams({
            initialPrice: initialPrice,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: totalBorrow,
            collateralSize: collateral,
            leverage: leverage,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory result = PositionLogic.calculatePnL(params);
        
        int256 expectedCollateralLeft = int256(int128(collateral)) + int256(int128(result.currentPnL));
        assertEq(result.collateralLeft, int128(expectedCollateralLeft), "Collateral left should be collateral + PnL");
    }
    
    function test_DifferentDecimalsHandling() public {
        // USDC test (6 decimals)
        uint128 usdcCollateral = 100e6;
        uint256 initialPriceUSDC = priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory paramsUSDC = PositionLogic.PnLCalculationParams({
            initialPrice: initialPriceUSDC,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()),
            totalBorrow: 100e6,
            collateralSize: usdcCollateral,
            leverage: 2,
            isShort: false,
            initialToken: getUsdc(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory resultUSDC = PositionLogic.calculatePnL(paramsUSDC);
        
        // WETH test (18 decimals)
        // Reset price first, then update again
        updateWbtcPrice(100_000e8);
        uint128 wethCollateral = 1e18;
        uint256 initialPriceWETH = priceFeedL1.getPairLatestPrice(getWbtc(), getWeth());
        updateWbtcPrice(105_000e8);
        
        PositionLogic.PnLCalculationParams memory paramsWETH = PositionLogic.PnLCalculationParams({
            initialPrice: initialPriceWETH,
            currentPrice: priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()),
            totalBorrow: 1e18,
            collateralSize: wethCollateral,
            leverage: 2,
            isShort: false,
            initialToken: getWeth(),
            priceFeed: address(priceFeedL1)
        });
        
        PositionLogic.PnLCalculationResult memory resultWETH = PositionLogic.calculatePnL(paramsWETH);
        
        // Both should show positive PnL
        assertTrue(resultUSDC.currentPnL > 0, "USDC PnL should be positive");
        assertTrue(resultWETH.currentPnL > 0, "WETH PnL should be positive");
    }
}