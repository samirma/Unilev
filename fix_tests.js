const fs = require('fs');
let content = fs.readFileSync('test/PositionLogicPnL.t.sol', 'utf8');

content = content.replace(/totalBorrow: totalBorrow,(\s*)collateralSize: collateral,(\s*)leverage: leverage,(\s*)isShort: true/g, 'totalBorrow: totalBorrow,$1positionSize: uint128(totalBorrow),$1collateralSize: collateral,$2leverage: leverage,$3isShort: true');

content = content.replace(/totalBorrow: totalBorrow,(\s*)collateralSize: collateral,(\s*)leverage: leverage,(\s*)isShort: false/g, 'totalBorrow: totalBorrow,$1positionSize: uint128((uint256(collateral) + totalBorrow) * 1e8 / initialPrice),$1collateralSize: uint128(uint256(collateral) * 1e8 / initialPrice),$2leverage: leverage,$3isShort: false');

// Also update the PnL evaluation for Longs since calculatePnL returns Base for longs but the test expects Quote
content = content.replace(/PositionLogic\.calculatePnL\(params\);\s+assertApproxEqAbs\(/g, 
'PositionLogic.calculatePnL(params);\n        if (!params.isShort) {\n            result.currentPnL = int128((int256(result.currentPnL) * int256(priceFeedL1.getPairLatestPrice(getWbtc(), params.initialToken == getUsdc() ? getUsdc() : getWeth()))) / 1e8);\n        }\n        assertApproxEqAbs(');

// For the two remaining edge case tests
content = content.replace(/totalBorrow: 100e6,(\s*)collateralSize: usdcCollateral,(\s*)leverage: 2,(\s*)isShort: false/g, 'totalBorrow: 100e6,$1positionSize: uint128((uint256(usdcCollateral) + 100e6) * 1e8 / initialPriceUSDC),$1collateralSize: uint128(uint256(usdcCollateral) * 1e8 / initialPriceUSDC),$2leverage: 2,$3isShort: false');

content = content.replace(/totalBorrow: 1e18,(\s*)collateralSize: wethCollateral,(\s*)leverage: 2,(\s*)isShort: false/g, 'totalBorrow: 1e18,$1positionSize: uint128((uint256(wethCollateral) + 1e18) * 1e8 / initialPriceWETH),$1collateralSize: uint128(uint256(wethCollateral) * 1e8 / initialPriceWETH),$2leverage: 2,$3isShort: false');

// And their assertions
content = content.replace(/PositionLogic\.calculatePnL\(paramsUSDC\);\s+\/\//g, 'PositionLogic.calculatePnL(paramsUSDC);\n        resultUSDC.currentPnL = int128((int256(resultUSDC.currentPnL) * int256(priceFeedL1.getPairLatestPrice(getWbtc(), getUsdc()))) / 1e8);\n        //');
content = content.replace(/PositionLogic\.calculatePnL\(paramsWETH\);\s+assert/g, 'PositionLogic.calculatePnL(paramsWETH);\n        resultWETH.currentPnL = int128((int256(resultWETH.currentPnL) * int256(priceFeedL1.getPairLatestPrice(getWbtc(), getWeth()))) / 1e8);\n        assert');


fs.writeFileSync('test/PositionLogicPnL.t.sol', content);
