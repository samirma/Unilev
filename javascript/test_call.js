const { ethers } = require("ethers");
const RPC_URL = "https://polygon-mainnet.g.alchemy.com/v2/oT1vfY4yefQFB7Czqenvb";
const provider = new ethers.JsonRpcProvider(RPC_URL);
const priceFeedAddress = "0x015c3722683b54fff1491a92bfd9c72ca3c84cc4";
const priceFeedAbi = [
    "function getAmountInUsd(address token, uint256 amount) external view returns (uint256)"
];
const contract = new ethers.Contract(priceFeedAddress, priceFeedAbi, provider);
contract.getAmountInUsd("0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", 0)
  .then(res => console.log("SUCCESS:", res.toString()))
  .catch(err => console.error("FAILED:", err));
