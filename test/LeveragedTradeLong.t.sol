// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";

contract LeveragedTradeLong is TestSetup {


function test__leveragedTradeToCloseLong1() public {
    uint128 amount = 1e8;
    uint24 fee = 3000;
    
    writeTokenBalance(alice, conf.addWbtc, amount);

    assertEq(amount, IERC20(conf.addWbtc).balanceOf(alice));
    assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));

    uint256 usdcBalanceBefore = IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc));

    vm.startPrank(alice);
    IERC20(conf.addWbtc).approve(address(positions), amount);
    console.log("Open position");
    market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 2, amount, 0, 0);

    assertEq(0, IERC20(conf.addWbtc).balanceOf(alice));
    assertApproxEqRel(amount * 2, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);

    uint256 usdcBalanceAfter = IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc));
    uint256 price = priceFeedL1.getPairLatestPrice(conf.addWbtc, conf.addUsdc);
    uint256 totalBorrow = (amount * 1 * price) / (10**18);
    uint256 openingFees = (totalBorrow * positions.BORROW_FEE()) / 10000;
    assertApproxEqRel(usdcBalanceBefore + openingFees, usdcBalanceAfter, 0.05e18);

    assertEq(1, positions.totalNbPos());
    uint256[] memory posAlice = positions.getTraderPositions(alice);
    
    assertEq(1, posAlice[0]);
    assertEq(alice, positions.ownerOf(posAlice[0]));
    console.log("Close position");
    market.closePosition(posAlice[0]);

    assertApproxEqRel(amount, IERC20(conf.addWbtc).balanceOf(alice), 0.05e18);
    assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
}

/*
    function test__leveragedTradeStopLossAndCloseLossLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            19000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));

        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndCloseWinLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 3, amount, 0, 20000e6);
        assertApproxEqRel(amount * 3, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            50000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        (, , , , , , , , , int128 pnl, int128 colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));
        setPrice(
            19000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
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

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, IERC20(conf.addWbtc).balanceOf(bob));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndLiquidateHourlyFeesLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 2, amount, 0, 20000e6);
        assertApproxEqRel(amount * 2, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        (, , , , , , , , , int128 pnl, int128 colLeft) = market.getPositionParams(1);
        console.logInt(pnl);
        console.log("colLeft ", uint128(colLeft));
        setPrice(
            19000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
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

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));
        console.log("balance of pool addUSDC ", IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc)));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, IERC20(conf.addWbtc).balanceOf(bob));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
    }

    function test__leveragedTradeBadDebtAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        console.log("balance of pool addUSDC ", IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc)));
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(conf.addWbtc, conf.addUsdc, uint24(fee), false, 2, amount, 0, 0);
        assertApproxEqRel(amount * 2, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        // Theoretically badDebt = 45000e6 lets set the price to 60000e6 to create bad debt
        setPrice(
            10000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));
        console.log("balance of pool addUSDC ", IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc)));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, IERC20(conf.addWbtc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedLimitOrderAndLiquidateLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(
            conf.addWbtc,
            conf.addUsdc,
            uint24(fee),
            false,
            3,
            amount,
            48000e6,
            20000e6
        );
        assertApproxEqRel(amount * 3, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            50000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));
        vm.startPrank(bob);
        market.liquidatePosition(posAlice[0]);

        console.log("balance of alice addWBTC ", IERC20(conf.addWbtc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(100000, IERC20(conf.addWbtc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedLimitOrderAndLiquidateRevertLong() public {
        uint128 amount = 1e8;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWbtc, amount);
        setPrice(
            30000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
            uniswapV3Helper
        );
        vm.startPrank(alice);
        IERC20(conf.addWbtc).approve(address(positions), amount);
        market.openPosition(
            conf.addWbtc,
            conf.addUsdc,
            uint24(fee),
            false,
            3,
            amount,
            48000e6,
            20000e6
        );
        assertApproxEqRel(amount * 3, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.05e18);
        vm.stopPrank();
        setPrice(
            40000e6,
            conf.addWbtc,
            conf.addUsdc,
            fee,
            mockV3AggregatorWbtcUsd,
            mockV3AggregatorUsdcUsd,
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
