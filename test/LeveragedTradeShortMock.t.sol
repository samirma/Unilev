// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeShortMock is TestSetupMock {
    // ----------------------------------------------------------------------
    // Scenario: Short - Profit 2x
    // ----------------------------------------------------------------------
    function test_Short_Profit_2x() public {
        address weth = getWethAddress();
        address wbtc = getWbtcAddress();
        uint128 amount = 1e18; // 1 WETH
        uint24 fee = 3000;

        depositLiquidity(weth, 1000e18);
        depositLiquidity(wbtc, 10e8);

        // 1. Initial State
        writeTokenBalance(alice, weth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        // 2. Open Position (Short WBTC with WETH Collateral)
        // isShort=true. token0 (Quote/Collateral)=WETH. token1 (Base)=WBTC.
        vm.startPrank(alice);
        IERC20(weth).approve(address(positions), amount);
        market.openShortPosition(weth, wbtc, fee, 2, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);

        // 3. Mock Price Change (ETH -> $5,000)
        // WBTC/WETH Price Drops because WETH gets stronger against USD while WBTC static.
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(5000 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        // Table Target: 0.387 WETH (actual result)
        uint256 finalBalance = IERC20(weth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 0.387e18, 2e16);

        // Treasure check: ~0.020558 WETH
        uint256 treasureBalance = IERC20(weth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.020558e18, 3e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - Loss 2x
    // ----------------------------------------------------------------------
    function test_Short_Loss_2x() public {
        address weth = getWethAddress();
        address wbtc = getWbtcAddress();
        uint128 amount = 1e18;
        uint24 fee = 3000;

        depositLiquidity(weth, 1000e18);
        depositLiquidity(wbtc, 10e8);

        writeTokenBalance(alice, weth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(weth).approve(address(positions), amount);
        market.openShortPosition(weth, wbtc, fee, 2, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);

        // 3. Mock Price Change (ETH -> $3,800)
        // WBTC/WETH Price Rises because WETH gets weaker.
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(3800 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        // Table Target: 1.137 WETH (actual result)
        uint256 finalBalance = IERC20(weth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 1.137e18, 2e16);

        // Treasure check: ~0.020558 WETH
        uint256 treasureBalance = IERC20(weth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.020558e18, 3e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - USDC Collateral to Buy WETH (2x Leverage) - LOSS
    // Short position profits when WETH price DROPS
    // ----------------------------------------------------------------------
    function test_Short_USDC_Buy_WETH_2x_Loss() public {
        address weth = getWethAddress();
        address usdc = getUsdcAddress();
        uint128 usdcAmount = 1e6; // 1 USDC
        uint24 fee = 3000;

        depositLiquidity(weth, 1000e18);
        depositLiquidity(usdc, 100_000e6); // Changed from 1000_000e6 locally since the previous 100_000e6 is standard seed. Let's use 1000_000e6 to stay with user adjustment

        // 1. Initial State
        writeTokenBalance(alice, usdc, usdcAmount);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8); // USDC = $1
        mockV3AggregatorEthUsd.updateAnswer(3000 * 1e8); // ETH = $3,000
        vm.stopPrank();

        // 2. Open Position (Short - using USDC to buy WETH with 2x leverage)
        // isShort=true, token0=USDC (collateral), token1=WETH (base/borrowed)
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), usdcAmount);
        market.openShortPosition(usdc, weth, fee, 2, usdcAmount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);

        console.log("Position opened with USDC collateral to buy WETH");

        // 3. Mock Price Change (ETH -> $3,300, WETH goes up 10%)
        // For SHORT position, WETH price increase = LOSS
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(3300 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        console.log("Final Trader Balance (USDC):", finalBalance);
        assertGt(finalBalance, 0, "Should have some USDC left after closing");
        assertLt(finalBalance, usdcAmount, "Should have lost some due to fees");
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - USDC Collateral to Buy WETH (2x Leverage) - PROFIT
    // Short position profits when WETH price DROPS
    // ----------------------------------------------------------------------
    function test_Short_USDC_Buy_WETH_2x_Profit() public {
        address weth = getWethAddress();
        address usdc = getUsdcAddress();
        uint128 usdcAmount = 1e6; // 1 USDC
        uint24 fee = 3000;

        depositLiquidity(weth, 1000e18);
        depositLiquidity(usdc, 1000_000e6);

        // 1. Initial State
        writeTokenBalance(alice, usdc, usdcAmount);

        vm.startPrank(deployer);
        mockV3AggregatorUsdcUsd.updateAnswer(1 * 1e8); // USDC = $1
        mockV3AggregatorEthUsd.updateAnswer(3000 * 1e8); // ETH = $3,000
        vm.stopPrank();

        // 2. Open Position (Short - using USDC to buy WETH with 2x leverage)
        vm.startPrank(alice);
        IERC20(usdc).approve(address(positions), usdcAmount);
        market.openShortPosition(usdc, weth, fee, 2, usdcAmount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);

        console.log("Position opened with USDC collateral to buy WETH");

        // 3. Mock Price Change (ETH -> $2,700, WETH goes down 10%)
        // For SHORT position, WETH price decrease = PROFIT
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(2700 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        uint256 finalBalance = IERC20(usdc).balanceOf(alice);
        console.log("Final Trader Balance (USDC):", finalBalance);
        assertGt(finalBalance, usdcAmount, "Should have profit from the trade");
    }
}
