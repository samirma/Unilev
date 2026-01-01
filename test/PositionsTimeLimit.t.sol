// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract PositionsTimeLimitTest is TestSetupMock {
    function test_DefaultTimeLimit_30Days() public {
        uint128 amount = 1e18; // 1 WETH
        uint24 fee = 3000;

        // 1. Initial State
        writeTokenBalance(alice, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8); // ETH = $4,000
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8); // WBTC = $100,000
        vm.stopPrank();

        // 2. Open Position
        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        uint256 posId = posAlice[0];

        // 3. Check State before time limit (e.g. 29 days)
        vm.warp(block.timestamp + 29 days);
        uint256 state = positions.getPositionState(posId);
        assertEq(state, 2, "State should be 2 (Active) before 30 days");

        // 4. Check State after time limit (e.g. 30 days + 1 second)
        vm.warp(block.timestamp + 1 days + 1);
        state = positions.getPositionState(posId);
        assertEq(state, 6, "State should be 6 (Time Limit) after 30 days");

        // 5. Liquidate
        vm.startPrank(deployer); // Liquidator
        market.liquidatePosition(posId);
        vm.stopPrank();

        // Position should be closed
        uint256[] memory posAliceAfter = positions.getTraderPositions(alice);
        assertEq(posAliceAfter.length, 0, "Position should be closed after liquidation");
    }

    function test_CustomTimeLimit_SpecificUser() public {
        uint128 amount = 1e18; // 1 WETH
        uint24 fee = 3000;

        // 1. Setup
        writeTokenBalance(alice, conf.addWeth, amount);
        writeTokenBalance(bob, conf.addWeth, amount);

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8);
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8);

        // Set custom time limit only for Alice: 1 day
        feeManager.setCustomPositionLifeTime(alice, 1 days);
        vm.stopPrank();

        // 2. Open Positions (Alice and Bob)
        vm.startPrank(alice);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, fee, false, 2, amount, 0, 0);
        vm.stopPrank();

        uint256 posIdAlice = positions.getTraderPositions(alice)[0];
        uint256 posIdBob = positions.getTraderPositions(bob)[0];

        // 3. Forward time (Alice should expire, Bob should not)
        vm.warp(block.timestamp + 1 days + 1 hours);

        // Alice: State 6
        uint256 stateAlice = positions.getPositionState(posIdAlice);
        assertEq(stateAlice, 6, "Alice should be expired (1 day limit)");

        // Bob: State 2 (using default 30 days)
        uint256 stateBob = positions.getPositionState(posIdBob);
        assertEq(stateBob, 2, "Bob should still be active (default 30 days)");

        // 4. Liquidate Alice
        vm.startPrank(deployer);
        market.liquidatePosition(posIdAlice);

        // Try to liquidate Bob (should fail)
        vm.expectRevert();
        market.liquidatePosition(posIdBob);
        vm.stopPrank();
    }
}
