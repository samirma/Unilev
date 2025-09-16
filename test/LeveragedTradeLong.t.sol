// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/TestSetup.sol";

contract LeveragedTradeLong is TestSetup {


function test__leveragedTradeToCloseLong1() public {
    uint128 amount = 1e8;
    uint24 fee = 3000;
    
    // Log the initial state before any actions
    console.log("Initial State");
    console.log("Amount to use:", amount);
    console.log("Fee:", fee);
    console.log("------------------------");

    writeTokenBalance(alice, conf.addWBTC, amount);

    // Log the balances after writing the token balance
    console.log("After writing token balance to Alice");
    console.log("Alice's WBTC balance:", ERC20(conf.addWBTC).balanceOf(alice));
    console.log("Positions contract WBTC balance:", ERC20(conf.addWBTC).balanceOf(address(positions)));
    console.log("------------------------");

    assertEq(amount, ERC20(conf.addWBTC).balanceOf(alice));
    assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));

    vm.startPrank(alice);
    ERC20(conf.addWBTC).approve(address(positions), amount);
    console.log("Open position");
    market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 2, amount, 0, 0);

    // Log the balances after opening the position
    console.log("After opening position");
    console.log("Alice's WBTC balance:", ERC20(conf.addWBTC).balanceOf(alice));
    console.log("Positions contract WBTC balance:", ERC20(conf.addWBTC).balanceOf(address(positions)));
    console.log("------------------------");

    assertEq(0, ERC20(conf.addWBTC).balanceOf(alice));
    assertApproxEqRel(amount * 2, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);

    assertEq(1, positions.totalNbPos());
    uint256[] memory posAlice = positions.getTraderPositions(alice);
    
    // Log the position details
    console.log("Trader's position details");
    console.log("Total number of positions:", positions.totalNbPos());
    console.log("Alice's first position ID:", posAlice[0]);
    console.log("Owner of position ID", posAlice[0], "is", positions.ownerOf(posAlice[0]));
    console.log("------------------------");

    assertEq(1, posAlice[0]);
    assertEq(alice, positions.ownerOf(posAlice[0]));
    console.log("Close position");
    market.closePosition(posAlice[0]);

    // Log the final balances after closing the position
    console.log("After closing position");
    console.log("Alice's WBTC balance:", ERC20(conf.addWBTC).balanceOf(alice));
    console.log("Positions contract WBTC balance:", ERC20(conf.addWBTC).balanceOf(address(positions)));
    console.log("------------------------");

    assertApproxEqRel(amount, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18);
    assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
}

/*
    function test__leveragedTradeStopLossAndCloseLossLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            19000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));

        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndCloseWinLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 3, amount, 0, 20000e6);
        assertApproxEqRel(amount * 3, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            50000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        (, , , , , , , , , int128 pnl, int128 colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));
        setPrice(
            19000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        (, , , , , , , , , pnl, colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, ERC20(conf.addWBTC).balanceOf(bob));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndLiquidateHourlyFeesLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        (, , , , , , , , , int128 pnl, int128 colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));
        setPrice(
            19000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        skip(3600 * 24);

        (, , , , , , , , , pnl, colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));

        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        console.log("balance of pool addUSDC ", ERC20(conf.addUSDC).balanceOf(address(lbPoolUSDC)));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, ERC20(conf.addWBTC).balanceOf(bob));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
    }

    function test__leveragedTradeBadDebtAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        console.log("balance of pool addUSDC ", ERC20(conf.addUSDC).balanceOf(address(lbPoolUSDC)));
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(conf.addWBTC, conf.addUSDC, uint24(fee), false, 2, amount, 0, 0);
        assertApproxEqRel(amount * 2, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        // Theoretically badDebt = 45000e6 lets set the price to 60000e6 to create bad debt
        setPrice(
            10000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        console.log("balance of pool addUSDC ", ERC20(conf.addUSDC).balanceOf(address(lbPoolUSDC)));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, ERC20(conf.addWBTC).balanceOf(bob));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__leveragedLimitOrderAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(
            conf.addWBTC,
            conf.addUSDC,
            uint24(fee),
            false,
            3,
            amount,
            48000e6,
            20000e6
        );
        assertApproxEqRel(amount * 3, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            50000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", ERC20(conf.addWBTC).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, ERC20(conf.addWBTC).balanceOf(bob));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(alice));
        assertEq(0, ERC20(conf.addUSDC).balanceOf(address(positions)));
        assertEq(0, ERC20(conf.addWBTC).balanceOf(address(positions)));
    }

    function test__leveragedLimitOrderAndLiquidateRevertLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWBTC, amount);
        setPrice(
            30000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        ERC20(conf.addWBTC).approve(address(positions), amount);
        market.openPosition(
            conf.addWBTC,
            conf.addUSDC,
            uint24(fee),
            false,
            3,
            amount,
            48000e6,
            20000e6
        );
        assertApproxEqRel(amount * 3, ERC20(conf.addWBTC).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            40000e6,
            conf.addWBTC,
            conf.addUSDC,
            fee,
            mockV3AggregatorWBTCUSD,
            mockV3AggregatorUSDCUSD,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Positions__POSITION_NOT_LIQUIDABLE_YET.selector, posAlice[0])
        );
        market.liquidatePosition(posAlice[0]);
    }
    */
}
