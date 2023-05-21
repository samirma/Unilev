// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "@uniswapCore/contracts/libraries/FullMath.sol";
import "@uniswapPeriphery/contracts/libraries/TransferHelper.sol";
import "@uniswapPeriphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswapPeriphery/contracts/interfaces/ISwapRouter.sol";

// TODO we need to add slippage control
contract UniswapV3Helper {
    ISwapRouter public immutable swapRouter;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        ISwapRouter _swapRouter
    ) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
        swapRouter = _swapRouter;
    }

    /** @dev Swap Helper */
    function swapExactInputSingle(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 _amountIn
    ) external returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(
            _token0,
            msg.sender,
            address(this),
            _amountIn
        );
        TransferHelper.safeApprove(_token0, address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _token0,
                tokenOut: _token1,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                // NOTE: In production, this value can be used to set the limit
                // for the price the swap will push the pool to,
                // which can help protect against price impact
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
    }

    /** @dev Liquidity Helper */
    function mintPosition(
        address _addToken0,
        address _addToken1,
        uint256 _amount0ToMint,
        uint256 _amount1ToMint,
        int24 _tickLower,
        int24 _tickUpper,
        uint24 _poolFee
    )
        external
        returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1)
    {
        // Approve the position manager
        TransferHelper.safeApprove(
            _addToken0,
            address(nonfungiblePositionManager),
            _amount0ToMint
        );
        TransferHelper.safeApprove(
            _addToken1,
            address(nonfungiblePositionManager),
            _amount1ToMint
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: _addToken0,
                token1: _addToken1,
                fee: _poolFee,
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _amount0ToMint,
                amount1Desired: _amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp
            });

        // Note that the pool defined by DAI/USDC and fee tier 0.01% must
        // already be created and initialized in order to mint
        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        // Remove allowance and refund in both assets.
        if (amount0 < _amount0ToMint) {
            TransferHelper.safeApprove(
                _addToken0,
                address(nonfungiblePositionManager),
                0
            );
            uint refund0 = _amount0ToMint - amount0;
            TransferHelper.safeTransfer(_addToken0, msg.sender, refund0);
        }

        if (amount1 < _amount1ToMint) {
            TransferHelper.safeApprove(
                _addToken1,
                address(nonfungiblePositionManager),
                0
            );
            uint refund1 = _amount1ToMint - amount1;
            TransferHelper.safeTransfer(_addToken1, msg.sender, refund1);
        }
    }

    function burnPosition(
        uint256 _tokenId
    ) external returns (uint256, uint256) {
        uint128 liquidity = getLiquidity(_tokenId);
        (uint256 amount0Fee, uint256 amount1Fee) = _collectAllFees(_tokenId);
        (uint256 amount0Value, uint256 amount1Value) = _decreaseLiquidity(
            _tokenId,
            liquidity
        );
        nonfungiblePositionManager.burn(_tokenId);

        return (amount0Value + amount0Fee, amount1Value + amount1Fee);
    }

    function _collectAllFees(
        uint256 _tokenId
    ) private returns (uint256 amount0, uint256 amount1) {
        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    function _decreaseLiquidity(
        uint256 _tokenId,
        uint128 _liquidity
    ) private returns (uint amount0, uint amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: _liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }

    function getLiquidity(uint _tokenId) public view returns (uint128) {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager
            .positions(_tokenId);
        return liquidity;
    }

    function sqrtPriceX96ToUint(
        uint160 sqrtPriceX96,
        uint8 decimalsToken0
    ) internal pure returns (uint256) {
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 numerator2 = 10 ** decimalsToken0;
        return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
    }
}
