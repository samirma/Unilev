// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/TestSetupMock.sol";

contract LeveragedTradeLongMock is TestSetupMock {


function test__leveragedTradeToCloseLong1() public {
        uint128 amount = 1e18;
        uint24 fee = 3000;
        writeTokenBalance(alice, conf.addWeth, amount);

        // Assert initial balances before opening position
        assertEq(amount, IERC20(conf.addWeth).balanceOf(alice));
        assertEq(0, IERC20(conf.addWeth).balanceOf(address(positions)));
        
        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(4000 * 1e8); // $4000
        mockV3AggregatorWbtcUsd.updateAnswer(100000 * 1e8); // $100000
        vm.stopPrank();

        vm.startPrank(alice);
        // Approve the Positions contract to spend the input token (USDC)
        IERC20(conf.addWeth).approve(address(positions), amount);
        market.openPosition(conf.addWeth, conf.addWbtc, uint24(fee), true, 1, amount, 0, 0);
        
        assertApproxEqRel(amount * 2, IERC20(conf.addWeth).balanceOf(address(positions)), 0.5e17);
        assertApproxEqRel(0, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.5e17);

        vm.stopPrank();

        vm.startPrank(deployer);
        mockV3AggregatorEthUsd.updateAnswer(5000 * 1e8);
        vm.stopPrank();

        assertEq(1, positions.totalNbPos());
        uint256[] memory posAlice = positions.getTraderPositions(alice);

        assertEq(1, posAlice[0]);
        assertEq(alice, positions.ownerOf(posAlice[0]));

        uint256 lbPoolWethBeforeClose = IERC20(conf.addWeth).balanceOf(address(lbPoolWeth));
        console.log("WETH balance in lbPoolUsdc BEFORE close: ", lbPoolWethBeforeClose);

        uint256 lbPoolWBTCBeforeClose = IERC20(conf.addWbtc).balanceOf(address(lbPoolWbtc));
        console.log("WBTC balance in lbPoolUsdc BEFORE close: ", lbPoolWBTCBeforeClose);

        console.log("Close position");
        vm.startPrank(alice);
        market.closePosition(posAlice[0]);
        vm.stopPrank();

        assertApproxEqRel(0, IERC20(conf.addWeth).balanceOf(address(positions)), 0.5e17);
        assertApproxEqRel(0, IERC20(conf.addWbtc).balanceOf(address(positions)), 0.5e17);

        uint256 wethBalanceAfterClose = IERC20(conf.addWeth).balanceOf(address(alice));
        assertApproxEqRel(1193e15, wethBalanceAfterClose, 0.5e17);
        uint256 wbtcBalanceAfterClose = IERC20(conf.addWbtc).balanceOf(address(alice));
        assertApproxEqRel(0, wbtcBalanceAfterClose, 0.5e17);

        uint256 lbPoolWethAfterClose = IERC20(conf.addWeth).balanceOf(address(lbPoolWeth));
        console.log("WETH balance in lbPoolUsdc After close: ", lbPoolWethAfterClose);

        uint256 lbPoolWBTCAfterClose = IERC20(conf.addWbtc).balanceOf(address(lbPoolWbtc));
        console.log("WBTC balance in lbPoolUsdc After close: ", lbPoolWBTCAfterClose);

}

}
