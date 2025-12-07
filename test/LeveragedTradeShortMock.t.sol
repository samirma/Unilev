// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeShortMock is TestSetupMock {
    // ----------------------------------------------------------------------
    // Scenario: Short - Profit 2x
    // ----------------------------------------------------------------------
    function test_Short_Profit_2x() public {
        uint128 amount = 1e18; // 1 WETH
        uint24 fee = 3000;

        // 1. Initial State
        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        // 2. Open Position (Short WBTC with WETH Collateral)
        // isShort=true. token0 (Quote/Collateral)=WETH. token1 (Base)=WBTC.
        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, true, 2, amount, 0, 0);
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
        // Table Target: 1.3712 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 1.3712e18, 0.001e18);

        // Treasure check: ~0.018024 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.018024e18, 0.001e18);
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - Loss 2x
    // ----------------------------------------------------------------------
    function test_Short_Loss_2x() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, true, 2, amount, 0, 0);
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
        // Table Target: 0.862 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 0.862e18, 0.001e18);

        // Treasure check: ~0.020558 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.020558e18, 0.001e18);
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - Profit No Leverage
    // (Note: In this protocol, isShort implies Margin/Borrowing even if leverage is 1)
    // ----------------------------------------------------------------------
    function test_Short_Profit_NoLeverage() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        // Leverage = 1
        market.openPosition(conf.addWeth, conf.addWbtc, fee, true, 1, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);

        // 3. Mock Price Change (ETH -> $5,000)
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(5000 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        // Table Target: 1.1856 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 1.1856e18, 0.001e18);

        // Treasure check: ~0.009012 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.009012e18, 0.001e18);
    }

    // ----------------------------------------------------------------------
    // Scenario: Short - Loss No Leverage
    // ----------------------------------------------------------------------
    function test_Short_Loss_NoLeverage() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        // Leverage = 1
        market.openPosition(conf.addWeth, conf.addWbtc, fee, true, 1, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);

        // 3. Mock Price Change (ETH -> $3,800)
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(3800 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        // Table Target: 0.931 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 0.931e18, 0.008e18);

        // Treasure check: ~0.010279 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.010279e18, 0.008e18);
    }
}
