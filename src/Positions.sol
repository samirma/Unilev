// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@solmate/tokens/ERC20.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
        ERC20 token; // token to trade => should be token0 or token1 of v3Pool
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

    string private constant BASE_SVG = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 24px; }</style><rect width='100%' height='100%' fill='black' /><text x='50%' y='50%' class='base' dominant-baseline='middle' text-anchor='middle'>";

    // Errors

    error PositionNotOpen(uint256 position);
    error NotOwnerOfPosition(uint256 position);
    error PositionDoesNotExist(uint256 position);

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

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if(_tokenId >= posId) {
            revert PositionDoesNotExist(_tokenId);
        }

        string memory json = Base64.encode(
            bytes(
            string.concat(tokenURIIntro(_tokenId),
                tokenURIAttributes(positions[_tokenId])
            ))
        );

        return string.concat('data:application/json;base64,', json);
    }

    function tokenURIIntro(uint256 _tokenId) private pure returns (string memory) {
        return
            string.concat(
                '{"name": "Uniswap-Max Position #',
                Strings.toString(_tokenId),
                '", "description": "This NFT represent a position on Uniswap-Max. The owner can close or edit the position.", "image": "',
                imageURI(_tokenId)
        );
    }

    function tokenURIAttributes(PositionParams memory _position) private view returns (string memory) {
        string[2] memory parts = [   // To avoid stack too deep error
            string.concat(
                '", "attributes": [ { "trait_type": "Token", "value": "', _position.token.name(),
                    '"}, { "trait_type": "Amount", "value": "', Strings.toString(_position.value),
                    '"} , { "trait_type": "Direction", "value": "', _position.isShort ? "Short" : "Long",
                    '"}, { "trait_type": "Leverage", "value": "', Strings.toString(_position.leverage)
            ),
            string.concat(
                '"}, { "trait_type": "Limit Price", "value": "', Strings.toString(_position.limitPrice),
                '"}, { "trait_type": "Stop Loss Price", "value": "', Strings.toString(_position.stopLossPrice),
                '"}, { "trait_type": "Status", "value": "', _position.status == PositionStatus.OPEN ? "Open" : 
                    _position.status == PositionStatus.CLOSED ? "Closed" : "Liquidated",
                '"}]}'
            )
        ];

        return string.concat(parts[0], parts[1]);
    }

    function imageURI(uint256 _tokenId) private pure returns (string memory) {
        string memory svg = string.concat(BASE_SVG, "UNISWAP-MAX #", Strings.toString(_tokenId), '</text></svg>');
        
        return string.concat('data:image/svg+xml;base64,', Base64.encode(bytes(svg)));
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
    ) external onlyOwner returns (uint256) {
        // TODO : check parameters

        uint256 _posId = safeMint(_trader);
        positions[_posId] = PositionParams(
            IUniswapV3Pool(_v3Pool),
            ERC20(_token),
            _value,
            _isShort,
            _leverage,
            _limitPrice,
            _stopLossPrice,
            PositionStatus.OPEN
        );
        return _posId;
    }

    function closePosition(uint256 _posId, address _trader) external onlyOwner {
        // TODO : apply rewards

        if(_posId >= posId) {
            revert PositionDoesNotExist(_posId);
        }

        if(ownerOf(_posId) != _trader) {
            revert NotOwnerOfPosition(_posId);
        }

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen(_posId);
        }

        positions[_posId].status = PositionStatus.CLOSED;

        safeBurn(_posId);
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
        uint256 _newLstopLossPrice,
        address _trader
    ) external onlyOwner {
        if(_posId >= posId) {
            revert PositionDoesNotExist(_posId);
        }

        if(ownerOf(_posId) != _trader) {
            revert NotOwnerOfPosition(_posId);
        }

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen(_posId);
        }

        positions[_posId].limitPrice = _newLimitPrice;
        positions[_posId].stopLossPrice = _newLstopLossPrice;
    }

    // --------------- Liquidator Zone ---------------

    function liquidatePosition(uint256 _posId) external onlyOwner {
        // TODO : check if liquidable
        // TODO : send liquidation reward

        if(_posId >= posId) {
            revert PositionDoesNotExist(_posId);
        }

        if(positions[_posId].status != PositionStatus.OPEN) {
            revert PositionNotOpen(_posId);
        }

        positions[_posId].status = PositionStatus.LIQUIDATED;

        safeBurn(_posId);
    }

    function isLiquidable(uint256 _posId) public view returns (bool) {
        if(_posId >= posId) {
            return false;
        }

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
