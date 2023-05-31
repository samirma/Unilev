// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "../UniswapV3Helper.sol";
// import "forge-std/Test.sol";

// contract math is Test {
//     UniswapV3Helper public uniswapV3Helper;

//     function setUp() public {
//         uniswapV3Helper = new UniswapV3Helper(address(0), address(0));
//     }

//     function test__priceToSqrtPriceX96() public {
//         uint160 init = 1813994069091123322211;
//         console.log("%s:%d", "init", init);
//         uint160 pricex96 = uniswapV3Helper.priceToSqrtPriceX96(init, 6);
//         console.log("%s:%d", "priceToSqrtPriceX96", pricex96);
//         uint160 price = uniswapV3Helper.sqrtPriceX96ToPrice(pricex96, 6, 18);
//         console.log("%s:%d", "sqrtPriceX96ToPrice", price);

//         assertApproxEqRel(price, init, 0.01e18);
//     }

//     function test__sqrtPriceX96ToPriceUSDCtoWETH() public {
//         uint160 init = 3374407402584763821906017466635660;
//         console.log("%s:%d", "init", init);
//         uint160 price = uniswapV3Helper.sqrtPriceX96ToPrice(init, 6, 18);
//         console.log("%s:%d", "sqrtPriceX96ToPrice", price);
//         uint160 pricex96 = uniswapV3Helper.priceToSqrtPriceX96(price, 6);
//         console.log("%s:%d", "priceToSqrtPriceX96", pricex96);

//         assertApproxEqRel(init, pricex96, 0.01e18);
//     }

//     function test__sqrtPriceX96ToPriceFuzz(uint160 init) public {
//         vm.assume(init > 1e25);
//         vm.assume(init < 1e38);

//         console.log("%s:%d", "init", init);
//         uint160 price = uniswapV3Helper.sqrtPriceX96ToPrice(init, 6, 18);
//         console.log("%s:%d", "sqrtPriceX96ToPrice", price);
//         uint160 pricex96 = uniswapV3Helper.priceToSqrtPriceX96(price, 6);
//         console.log("%s:%d", "priceToSqrtPriceX96", pricex96);

//         assertApproxEqRel(init, pricex96, 0.01e18);
//     }

//     // function test__sqrtPriceX96ToPriceWBTCtoUSDC() public {
//     //     uint160 init = 1299647688074254085112554569130;
//     //     console.log("%s:%d", "init", init);
//     //     uint160 price = uniswapV3Helper.sqrtPriceX96ToPrice(init, 8, 6);
//     //     console.log("%s:%d", "sqrtPriceX96ToPrice", price);
//     //     uint160 pricex96 = uniswapV3Helper.priceToSqrtPriceX96(price, 8);
//     //     console.log("%s:%d", "priceToSqrtPriceX96", pricex96);

//     //     assertApproxEqRel(init, pricex96, 0.01e18);
//     // }
// }
// // 1859256084048280293649168765913399
// // 1299647688074254085112554569130
// // 1859256101248138846425272740201005
// // 1853939002833785499688928437862400
// // 3374407402584763821906017466635660558336
// // 3374407402505535659391753129042116
// // 3374407402584763821906017466635660

// // 3374407402584763821906017466635660
// // 3374407402505535659391753129042116

// // 1299647688074254085112554569130
// // 3374407402505535659391753129042116
// // 1299647685941240196877231865
