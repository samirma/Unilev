// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {IUniswapV3SwapRouter} from "./interfaces/IUniswapV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapV3Helper {
    IUniswapV3SwapRouter public immutable SWAP_ROUTER;

    constructor(address _swapRouter) {
        SWAP_ROUTER = IUniswapV3SwapRouter(_swapRouter);
    }

    function swapExactInputSingle(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        uint256 _amountIn
    ) public returns (uint256 amountOut) {
        // Transfer the tokens from Positions.sol to this contract
        SafeERC20.safeTransferFrom(IERC20(_tokenIn), msg.sender, address(this), _amountIn);

        // Approve the router to spend the input token.
        SafeERC20.forceApprove(IERC20(_tokenIn), address(SWAP_ROUTER), _amountIn);

        IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAP_ROUTER.exactInputSingle(params);
    }

    function swapExactOutputSingle(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        uint256 _amountOut,
        uint256 _amountInMaximum
    ) public returns (uint256 amountIn) {
        // Transfer the tokens from Positions.sol to this contract
        SafeERC20.safeTransferFrom(IERC20(_tokenIn), msg.sender, address(this), _amountInMaximum);

        // Approve the router to spend the input token.
        SafeERC20.forceApprove(IERC20(_tokenIn), address(SWAP_ROUTER), _amountInMaximum);

        IUniswapV3SwapRouter.ExactOutputSingleParams memory params = IUniswapV3SwapRouter
            .ExactOutputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: _amountOut,
                amountInMaximum: _amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        amountIn = SWAP_ROUTER.exactOutputSingle(params);

        // Refund the unused tokens
        if (amountIn < _amountInMaximum) {
            SafeERC20.safeTransfer(IERC20(_tokenIn), msg.sender, _amountInMaximum - amountIn);
        }
    }
}
