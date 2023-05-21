// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../UniswapV3Helper.sol";
import "forge-std/Test.sol";

contract math is Test {
    UniswapV3Helper public uniswapV3Helper;

    function setUp() public {
        uniswapV3Helper = new UniswapV3Helper(address(0), address(0));
    }

    function test__math() public {
        uint256 price = uniswapV3Helper.sqrtPriceX96ToPrice(
            1860351726628391336312977316371029,
            0
        );
        console.log("%s:%d", "price", price);
        assertEq(price, 1);
    }
}
