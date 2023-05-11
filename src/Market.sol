// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IMarket.sol";
import "./Positions.sol";
import "./LiquidityPool.sol";
import "./LiquidityPoolFactory.sol";

// TODO deal with pause
contract Market is IMarket, Ownable, Pausable {
    Positions private positions;
    LiquidityPoolFactory private liquidityPoolFactory;

    constructor(
        address _positions,
        address _liquidityPoolFactory,
        address _owner
    ) {
        positions = Positions(_positions);
        liquidityPoolFactory = LiquidityPoolFactory(_liquidityPoolFactory);
        transferOwnership(_owner);
    }

    // --------------- Trader Zone ---------------
    function openPosition(
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint128 _amount,
        uint160 _limitPrice,
        uint256 _stopLossPrice
    ) external {
        uint256 posId = positions.openPosition(
            msg.sender,
            _v3Pool,
            _token,
            _isShort,
            _leverage,
            _amount,
            _limitPrice,
            _stopLossPrice
        );
        emit PositionOpened(
            posId,
            msg.sender,
            _v3Pool,
            _token,
            _amount,
            _isShort,
            _leverage,
            _limitPrice,
            _stopLossPrice
        );
    }

    function closePosition(uint256 _posId) external {
        positions.closePosition(msg.sender, _posId);
        emit PositionClosed(_posId, msg.sender);
    }

    function editPosition(
        uint256 _posId,
        uint160 _newLimitPrice,
        uint256 _newLstopLossPrice
    ) external {
        positions.editPosition(
            msg.sender,
            _posId,
            _newLimitPrice,
            _newLstopLossPrice
        );
        emit PositionEdited(
            _posId,
            msg.sender,
            _newLimitPrice,
            _newLstopLossPrice
        );
    }

    function getTraderPositions(
        address _traderAdd
    ) external view returns (uint256[] memory) {
        return positions.getTraderPositions(_traderAdd);
    }

    // --------------- Liquidity Provider Zone ---------------
    /** @notice provide a simple interface to deal with pools.
     *          Of course a user can interact directly with the
     *          pool contract if he wants through deposit/withdraw
     *          and mint/redeem functions
     */
    function addLiquidity(address _poolAdd, uint256 _assets) external {
        LiquidityPool(_poolAdd).deposit(_assets, msg.sender);
        emit LiquidityAdded(_poolAdd, msg.sender, _assets);
    }

    function removeLiquidity(address _poolAdd, uint256 _shares) external {
        LiquidityPool(_poolAdd).redeem(_shares, msg.sender, msg.sender);
        emit LiquidityRemoved(_poolAdd, msg.sender, _shares);
    }

    // --------------- Liquidator/Keeper Zone ----------------
    function liquidatePositions(uint256[] memory _posIds) external {
        uint256 len = _posIds.length;

        for (uint256 i; i < len; ++i) {
            // Is that safe ?
            try positions.liquidatePosition(msg.sender, _posIds[i]) {
                emit PositionLiquidated(_posIds[i], msg.sender);
            } catch {}
        }
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        return positions.getLiquidablePositions();
    }

    // --------------- Admin Zone ---------------
    function createLiquidityPool(address _token) external {
        liquidityPoolFactory.createLiquidityPool(_token);
        emit LiquidityPoolCreated(_token, msg.sender);
    }
}
