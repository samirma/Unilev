// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetup.sol";

contract LeveragedTradeShort is TestSetup {
    function test__leveragedTradeToCloseShort1() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);

        assertEq(amount, IERC20(conf.addUsdc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));

        vm.startPrank(alice);
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 0);

        assertEq(0, IERC20(conf.addUsdc).balanceOf(alice));
        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);
        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        market.closePosition(posAlice[0]);

        assertApproxEqRel(amount, IERC20(conf.addUsdc).balanceOf(alice), 0.05e18);
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
    }

    /*
    function test__leveragedTradeStopLossAndCloseLossShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);
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
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 40000e6);

        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        setPrice(
            41000e6,
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

        console.log("balance of alice addWBTC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, IERC20(conf.addWbtc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndCloseWinShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);
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
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 3, amount, 0, 40000e6);

        assertApproxEqRel(amount * 4, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        setPrice(
            20000e6,
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

        console.log("balance of alice USDC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(0, IERC20(conf.addWbtc).balanceOf(alice));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeStopLossAndLiquidateShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);
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
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 40000e6);

        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        setPrice(
            41000e6,
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

        console.log("balance of alice addUSDC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, IERC20(conf.addUsdc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeWithoutStopLossAndLiquidateShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addUsdc, amount);
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
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 0);
        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        // Theoretically badDebt = 45000e6 lets set the price to 44000e6
        setPrice(
            44000e6,
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

        console.log("balance of alice addUSDC ", IERC20(conf.addUsdc).balanceOf(alice));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, IERC20(conf.addUsdc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    function test__leveragedTradeBadDebtAndLiquidateShort() public {
        uint128 amount = 1000e6;
        uint24 fee = 3000;
        console.log("balance of pool addWBTC ", IERC20(conf.addWbtc).balanceOf(address(lbPoolWbtc)));
        writeTokenBalance(alice, conf.addUsdc, amount);
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
        IERC20(conf.addUsdc).approve(address(positions), amount);
        market.openPosition(conf.addUsdc, conf.addWbtc, uint24(fee), true, 2, amount, 0, 0);
        assertApproxEqRel(amount * 3, IERC20(conf.addUsdc).balanceOf(address(positions)), 0.05e18);

        vm.stopPrank();
        // Theoretically badDebt = 45000e6 lets set the price to 60000e6 to create bad debt
        setPrice(
            60000e6,
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
        console.log("balance of pool addWBTC ", IERC20(conf.addWbtc).balanceOf(address(lbPoolWbtc)));
        // assertApproxEqRel(aaa, ERC20(conf.addWBTC).balanceOf(alice), 0.05e18); // TODO
        assertEq(30003000, IERC20(conf.addUsdc).balanceOf(bob));
        assertEq(0, IERC20(conf.addUsdc).balanceOf(address(positions)));
        assertEq(0, IERC20(conf.addWbtc).balanceOf(address(positions)));
    }

    // function test__leveragedLimitOrderAndCloseShort() public {} // TODO
    */
}
