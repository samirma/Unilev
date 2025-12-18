// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeLongMock is TestSetupMock {
    // ----------------------------------------------------------------------
    // Scenario: Long - Profit 2x (ETH Price Rise)
    // ----------------------------------------------------------------------
    function test_Long_Profit_2x_ETH_Rise() public {
        uint128 amount = 1e18; // 1 WETH
        uint24 fee = 3000;

        // 1. Initial State
        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8); // ETH = $4,000
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Position (Long WETH/WBTC 2x)
        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        // token0=WETH, token1=WBTC, isShort=false (Long), leverage=2
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        // Verify Position State (Approximate check based on table)
        // Table: "Collateral (0.995) + Swap (0.997) = 1.992 WETH" in position
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(posAlice.length, 1);

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

        // Using a relative error tolerance to account for minor fee calculation differences in mocks
        // Target: 1.1856e18
        assertApproxEqAbs(finalBalance, 1.1856e18, 1e16);

        // Treasure check: ~0.009012 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        console.log("Treasure Balance (WETH):", treasureBalance);
        assertApproxEqAbs(treasureBalance, 0.009012e18, 1e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Profit 2x (WBTC Price Drop)
    // ----------------------------------------------------------------------
    function test_Long_Profit_2x_WBTC_Drop() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        // 1. Initial State
        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        // 2. Open Position
        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);

        // 3. Mock Price Change (WBTC -> $80,000)
        vm.startPrank(deployer);
        mockV3AggregatorWbtcUsd.updateAnswer(80000 * 1e8);
        vm.stopPrank();

        // 4. Close Position
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        // 5. Final Assertions
        // Table Target: 1.3469 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 1.3469e18, 2e17);

        // Treasure check: ~0.00821 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        console.log("Treasure Balance (WETH):", treasureBalance);
        assertApproxEqAbs(treasureBalance, 0.00821e18, 1e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Loss 2x (ETH Price Drop)
    // ----------------------------------------------------------------------
    function test_Long_Loss_2x_ETH_Drop() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
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
        assertApproxEqAbs(finalBalance, 0.931e18, 1e16);

        // Treasure check: ~0.010279 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.010279e18, 1e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Profit No Leverage
    // ----------------------------------------------------------------------
    function test_Long_NoLeverage_Profit() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        // Leverage = 1 (No Leverage)
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 1, amount, 0, 0);
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
        // Table Target: 0.995 WETH (Just holding minus fees)
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 0.995e18, 1e16); // Slightly higher tolerance due to fee model

        // Treasure check: ~0.009976 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.009976e18, 1e16);
    }

    // ----------------------------------------------------------------------
    // Scenario: Long - Loss No Leverage
    // ----------------------------------------------------------------------
    function test_Long_NoLeverage_Loss() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;

        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 1, amount, 0, 0);
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
        // Table Target: 0.995 WETH
        uint256 finalBalance = IERC20(conf.addWeth).balanceOf(alice);
        console.log("Final Trader Balance (WETH):", finalBalance);
        assertApproxEqAbs(finalBalance, 0.995e18, 1e16);

        // Treasure check: ~0.009976 WETH
        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        assertApproxEqAbs(treasureBalance, 0.009976e18, 1e16);
    }
    // ----------------------------------------------------------------------
    // Scenario: Whitelist Fees Test
    // ----------------------------------------------------------------------
    function test_WhitelistFees() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;
        address whitelistedUser = address(0x88);

        // 1. Initial State
        writeTokenBalance(whitelistedUser, conf.addWeth, amount);

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
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        // 4. Verification of Treasure Fee
        // Liquidation Reward = 0
        // Amount used for fee calc = 1e18
        // Treasure Fee = 1e18 * 1 / 10000 = 1e14

        uint256 treasureBalance = IERC20(conf.addWeth).balanceOf(conf.treasure);
        console.log("Treasure Balance (Whitelisted):", treasureBalance);
        assertApproxEqAbs(treasureBalance, 1e14, 100); // Allow small rounding
    }
}
