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

    // Log USDC balance in lbPoolUsdc BEFORE open
    uint256 usdcBalanceBefore = IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc));
    console.log("USDC balance in lbPoolUsdc BEFORE open: ", usdcBalanceBefore);

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

    uint256 usdcBalanceAfterClose = IERC20(conf.addUsdc).balanceOf(address(lbPoolUsdc));
    //assertGe(usdcBalanceBefore, usdcBalanceAfter);
    console.log("USDC balance in lbPoolUsdc AFTER close: ", usdcBalanceAfterClose);

}

}
