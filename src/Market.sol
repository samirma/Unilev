// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswapV3/contracts/interfaces/IUniswapV3Pool.sol";

import "./interfaces/IMarket.sol";
import "./Positions.sol";
import "./LiquidityPool.sol";
import "./LiquidityPoolFactory.sol";

contract Market is IMarket {
    Positions positions;
    LiquidityPoolFactory liquidityPoolFactory;

    constructor(address _positions, address _liquidityPoolFactory) {
        positions = Positions(_positions);
        liquidityPoolFactory = LiquidityPoolFactory(_liquidityPoolFactory);
    }

    // --------------- Trader Zone ---------------
    function openPosition(
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint256 _value,
        uint256 _limitPrice,
        uint256 _stopLossPrice
    ) external {
        uint256 posId = positions.openPosition(
            msg.sender,
            _v3Pool,
            _token,
            _isShort,
            _leverage,
            _value,
            _limitPrice,
            _stopLossPrice
        );
        emit PositionOpened(
            posId,
            msg.sender,
            _v3Pool,
            _token,
            _value,
            _isShort,
            _leverage,
            _limitPrice,
            _stopLossPrice
        );
    }

    function closePosition(uint256 _posId) external {
        positions.closePosition(_posId, msg.sender);
        emit PositionClosed(_posId, msg.sender);
    }

    function editPosition(
        uint256 _posId,
        uint256 _newLimitPrice,
        uint256 _newLstopLossPrice
    ) external {
        positions.editPosition(_posId, _newLimitPrice, _newLstopLossPrice);
        emit PositionEdited(
            _posId,
            msg.sender,
            _newLimitPrice,
            _newLstopLossPrice
        );
    }

    // --------------- Liquidity Provider Zone ---------------
    function addLiquidity(address _poolAdd, uint256 _value) external {
        LiquidityPool(_poolAdd).addLiquidity(msg.sender, _value);
        emit LiquidityAdded(_poolAdd, msg.sender, _value);
    }

    function removeLiquidity(address _poolAdd, uint256 _value) external {
        LiquidityPool(_poolAdd).removeLiquidity(msg.sender, _value);
        emit LiquidityRemoved(_poolAdd, msg.sender, _value);
    }

    // --------------- Liquidator/Keeper Zone ---------------

    function liquidatePositions(uint256[] memory _posIds) external {
        uint256 len = _posIds.length;

        for (uint256 i; i < len; ++i) {
            // Is that safe ?
            try positions.liquidatePosition(_posIds[i]) {} catch {
                continue;
            }
            emit PositionLiquidated(_posIds[i], msg.sender);
        }
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        return positions.getLiquidablePositions();
    }

    // --------------- Admin Zone ---------------
    function createLiquidityPool(IUniswapV3Pool _v3Pool) external {
        liquidityPoolFactory.createLiquidityPool(_v3Pool);
        emit LiquidityPoolCreated(address(_v3Pool), msg.sender);
    }
}
