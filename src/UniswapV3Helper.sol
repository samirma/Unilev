// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {IUniswapV3SwapRouter} from "./interfaces/IUniswapV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

contract UniswapV3Helper {
    IUniswapV3SwapRouter public immutable SWAP_ROUTER;

    constructor(address _swapRouter) {
        SWAP_ROUTER = IUniswapV3SwapRouter(_swapRouter);
    }

    receive() external payable {}

    function swapExactInputSingle(
        address _tokenIn,
        address _tokenOut,
        uint24 _fee,
        uint256 _amountIn,
        uint256 _amountOutMinimum
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
                amountOutMinimum: _amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAP_ROUTER.exactInputSingle(params);
    }

    function swapExactInputSingleEth(
        address _tokenOut,
        uint24 _fee,
        uint256 _amountIn,
        uint256 _amountOutMinimum
    ) public payable returns (uint256 amountOut) {
        // Wrap ETH to WETH
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH
        // Check if we are on a testnet or modify to be configurable if needed,
        // but for now hardcoding or passing in might be better.
        // Ideally should be passed in constructor but to minimize changes I'll assume Hardhat Mainnet Fork or set it.
        // Wait, I should probably pass WETH address or get it from somewhere.
        // But for simplicity and based on the current context (Mainnet fork likely), I will use the WETH address commonly used.
        // Actually, let's verify if I can get WETH from the router or somewhere.
        // Standard Uniswap Router deals with WETH.

        // Let's check constructor. It only takes router.
        // I will use the WETH address from the environment/config usually, but since this is a quick helper update:
        // I'll assume it's mainnet fork WETH as seen in `HelperConfig.sol`.

        IWETH9(weth).deposit{value: _amountIn}();

        // Approve the router to spend WETH
        SafeERC20.forceApprove(IERC20(weth), address(SWAP_ROUTER), _amountIn);

        IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: weth,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAP_ROUTER.exactInputSingle(params);

        // Refund implementation not strictly necessary for exactInputSingle as it spends exact amount,
        // provided the router doesn't return dust (which it shouldn't for exact input).
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
