// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockSwapRouter is ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    mapping(bytes32 => uint256) public mockAmountOut;

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        bytes32 key = keccak256(abi.encodePacked(params.tokenIn, params.tokenOut, params.fee));
        amountOut = mockAmountOut[key];
        if (amountOut == 0) {
            revert("MockSwapRouter: amountOut not set");
        }
        IERC20(params.tokenIn).transferFrom(params.recipient, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);
    }

    function setMockAmountOut(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut
    ) external {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut, fee));
        mockAmountOut[key] = amountOut;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata 
    ) external payable returns (uint256 amountIn) {
        revert("not implemented");
    }

    function exactInput(
        ExactInputParams calldata 
    ) external payable returns (uint256 amountOut) {
        revert("not implemented");
    }

    function exactOutput(
        ExactOutputParams calldata 
    ) external payable returns (uint256 amountIn) {
        revert("not implemented");
    }

    function uniswapV3SwapCallback(
        int256,
        int256,
        bytes calldata
    ) external {
        revert("not implemented");
    }
}
