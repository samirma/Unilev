// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswapV3/contracts/interfaces/IUniswapV3Pool.sol";

contract Positions is ERC721, Ownable {
    // Structs and Enums

    enum PositionStatus {
        OPEN,
        CLOSED,
        LIQUIDATED
    }

    struct PositionParams {
        IUniswapV3Pool v3Pool; // pool to trade
        IERC20 token; // token to trade => should be token0 or token1 of v3Pool
        uint256 value; // amount of token to trade
        bool isShort; // true if short, false if long
        uint8 leverage; // leverage of position => 0 if no leverage
        uint256 limitPrice; // limit order price => 0 if no limit order
        uint256 stopLossPrice; // stop loss price => 0 if no stop loss
        PositionStatus status; // status of position
    }

    // Variables

    uint256 public posId;
    mapping(uint256 => PositionParams) public positions;

    // Events

    event PositionOpened(
        uint256 indexed posId,
        address indexed trader,
        address indexed v3Pool,
        address token,
        uint256 value,
        bool isShort,
        uint8 leverage,
        uint256 limitPrice,
        uint256 stopLossPrice
    );
    event PositionClosed(uint256 indexed posId, address indexed trader);
    event PositionEdited(
        uint256 indexed posId,
        address indexed trader,
        uint256 newLimitPrice,
        uint256 newStopLossPrice
    );
    event PositionLiquidated(
        uint256 indexed posId,
        address indexed trader,
        uint256 liquidationPrice
    );

    // Errors

    error PositionNotOpen();

    constructor(address _market) ERC721("Uniswap-MAX", "UNIMAX") {
        transferOwnership(_market);
    }

    // --------------- ERC721 Zone ---------------

    function safeMint(address to) private returns (uint256) {
        uint256 _posId = posId;
        ++posId;
        _safeMint(to, _posId);
        return _posId;
    }

    function safeBurn(uint256 _posId) private {
        _burn(_posId);
    }

    // --------------- Trader Zone ---------------
    
    function openPosition(
        address _trader,
        address _v3Pool,
        address _token,
        bool _isShort,
        uint8 _leverage,
        uint256 _value,
        uint256 _limitPrice,
        uint256 _stopLossPrice
    ) external returns (uint256) {
        // TODO : check parameters

        uint256 _posId = safeMint(_trader);
        positions[_posId] = PositionParams(
            IUniswapV3Pool(_v3Pool),
            IERC20(_token),
            _value,
            _isShort,
            _leverage,
            _limitPrice,
            _stopLossPrice,
            PositionStatus.OPEN
        );
        return _posId;
    }

    function closePosition(uint256 _posId, address _trader) external {
        // TODO : check access control
        // TODO : apply rewards

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen();
        }

        safeBurn(_posId);
        positions[_posId].status = PositionStatus.CLOSED;
    }

    function getTraderPositions(
        address _traderAdd
    ) external view returns (uint256[] memory) {
        uint256[] memory _traderPositions = new uint256[](balanceOf(_traderAdd));
        uint256 _posId = 0;

        for (uint256 i = 0; i < posId; ) {
            if (ownerOf(i) == _traderAdd) {
                _traderPositions[_posId] = i;

                unchecked {
                    ++_posId;
                }
            }

            unchecked {
                ++i;
            }
        }

        return _traderPositions;
    }

    function editPosition(
        uint256 _posId,
        uint256 _newLimitPrice,
        uint256 _newLstopLossPrice
    ) external {
        // TODO : check access control

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen();
        }

        positions[_posId].limitPrice = _newLimitPrice;
        positions[_posId].stopLossPrice = _newLstopLossPrice;
    }

    // --------------- Liquidator Zone ---------------

    function liquidatePosition(uint256 _posId) external {
        // TODO : check if liquidable
        // TODO : send liquidation reward

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen();
        }

        safeBurn(_posId);
        positions[_posId].status = PositionStatus.LIQUIDATED;
    }

    function isLiquidable(uint256 _posId) public view returns (bool) {
        // TODO
        return positions[_posId].status == PositionStatus.OPEN && false;
    }

    function getLiquidablePositions() external view returns (uint256[] memory) {
        uint256[] memory _liquidablePositions = new uint256[](posId);
        uint256 _posId = 0;
        for(uint256 i = 0; i < posId; ) {
            if(isLiquidable(i)) {
                _liquidablePositions[_posId] = i;

                unchecked {
                    ++_posId;
                }
            }

            unchecked {
                ++i;
            }
        }
        
        assembly { 
            mstore(_liquidablePositions, sub(mload(_liquidablePositions), sub(sload(posId.slot), _posId))) 
        }

        return _liquidablePositions;
    }
}
