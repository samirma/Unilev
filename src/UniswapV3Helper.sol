// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

contract UniswapV3Helper {

    constructor(address _swapRouter) {
        // _swapRouter is the address of the Uniswap V3 SwapRouter
    }

    // ------ SWAP ------

    /** @dev Swap Helper */
    function swapExactInputSingle(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 _amountIn
    ) public returns (uint256 amountOut) {
        //Add the required approvals hare
        //use the _swapRouter to execute the swapExactInputSingle swap

    }

    function swapExactOutputSingle(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 amountOut,
        uint256 amountInMaximum
    ) public returns (uint256 amountIn) 
    {
        //Add the required approvals hare
        //use the _swapRouter to execute the swapExactOutputSingle swap
    }

}
