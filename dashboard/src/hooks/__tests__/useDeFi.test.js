import { renderHook } from "@testing-library/react";
import { ethers } from "ethers";
import { useAccount, useWalletClient } from "wagmi";

// Mock environment variables MUST be set before requiring useDeFi
process.env.PRICEFEEDL1_ADDRESS = "0xPriceFeed";
process.env.POSITIONS_ADDRESS = "0xPositions";
process.env.MARKET_ADDRESS = "0xMarket";
process.env.LIQUIDITYPOOLFACTORY_ADDRESS = "0xPoolFactory";
process.env.FEEMANAGER_ADDRESS = "0xFeeManager";
process.env.RPC_URL = "http://localhost:8545";

// Mock wagmi
jest.mock("wagmi", () => ({
  useAccount: jest.fn(),
  useWalletClient: jest.fn(),
}));

// Mock ethers
jest.mock("ethers", () => {
  const actualEthers = jest.requireActual("ethers");
  const mockContract = jest.fn();
  return {
    ...actualEthers,
    ethers: {
      ...actualEthers.ethers,
      JsonRpcProvider: jest.fn(),
      BrowserProvider: jest.fn(),
      Contract: mockContract,
      parseUnits: jest.fn((val, dec) => BigInt(val) * BigInt(10 ** dec)),
      formatUnits: jest.fn((val, dec) => (Number(val) / 10 ** Number(dec)).toString()),
      formatEther: jest.fn((val) => (Number(val) / 10 ** 18).toString()),
      MaxUint256: BigInt("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"),
      ZeroAddress: "0x0000000000000000000000000000000000000000",
    },
    JsonRpcProvider: jest.fn(),
    BrowserProvider: jest.fn(),
    Contract: mockContract,
  };
});

// Mock window.ethereum
global.window = Object.create(window);
Object.defineProperty(window, 'ethereum', {
  value: {
    request: jest.fn(),
  },
  writable: true
});

// Import useDeFi AFTER environment variables are set
const { useDeFi } = require("../useDeFi");

describe("useDeFi Hook", () => {
  let mockSigner;
  let mockProvider;
  let mockMarketContract;
  let mockPoolContract;
  let mockTokenContract;

  beforeEach(() => {
    jest.clearAllMocks();

    mockSigner = {
      getAddress: jest.fn().mockResolvedValue("0xUser"),
      sendTransaction: jest.fn().mockResolvedValue({ wait: jest.fn().mockResolvedValue({}) }),
    };

    mockProvider = {
      getSigner: jest.fn().mockResolvedValue(mockSigner),
      getCode: jest.fn().mockResolvedValue("0x123"),
      getBalance: jest.fn().mockResolvedValue(BigInt(10 ** 18)),
    };

    ethers.BrowserProvider.mockImplementation(() => mockProvider);
    ethers.JsonRpcProvider.mockImplementation(() => mockProvider);

    useAccount.mockReturnValue({ address: "0xUser", isConnected: true });
    useWalletClient.mockReturnValue({ data: {} });

    mockMarketContract = {
      openShortPosition: jest.fn().mockResolvedValue({ hash: "0xHash" }),
      openLongPosition: jest.fn().mockResolvedValue({ hash: "0xHash" }),
      getTokenToLiquidityPools: jest.fn().mockResolvedValue("0xPool"),
    };
    mockMarketContract.openShortPosition.staticCall = jest.fn().mockResolvedValue(true);
    mockMarketContract.openLongPosition.staticCall = jest.fn().mockResolvedValue(true);

    mockPoolContract = {
      deposit: jest.fn().mockResolvedValue({ hash: "0xHash" }),
      redeem: jest.fn().mockResolvedValue({ hash: "0xHash" }),
      balanceOf: jest.fn().mockResolvedValue(BigInt(100)),
      convertToAssets: jest.fn().mockResolvedValue(BigInt(100)),
      totalAssets: jest.fn().mockResolvedValue(BigInt(1000)),
    };

    mockTokenContract = {
      allowance: jest.fn().mockResolvedValue(BigInt(1000000)),
      approve: jest.fn().mockResolvedValue({ hash: "0xHash", wait: jest.fn().mockResolvedValue({}) }),
      decimals: jest.fn().mockResolvedValue(18),
      symbol: jest.fn().mockResolvedValue("USDC"),
      balanceOf: jest.fn().mockResolvedValue(BigInt(1000)),
    };

    ethers.Contract.mockImplementation((address) => {
      if (address === "0xMarket") return mockMarketContract;
      if (address === "0xPool") return mockPoolContract;
      return mockTokenContract;
    });
  });

  test("openPosition should call openLongPosition when isShort is false", async () => {
    const { result } = renderHook(() => useDeFi());
    
    // Allow useEffect and initializations to run
    await new Promise(r => setTimeout(r, 0));

    const token0 = "0xToken0";
    const token1 = "0xToken1";
    const amount = BigInt(100);
    const leverage = 2;

    await result.current.openPosition(token0, token1, false, amount, leverage);

    expect(mockMarketContract.openLongPosition).toHaveBeenCalledWith(
      token0,
      token1,
      3000,
      leverage,
      amount,
      0,
      0,
      { gasLimit: 5000000 }
    );
  });

  test("openPosition should call openShortPosition when isShort is true", async () => {
    const { result } = renderHook(() => useDeFi());
    await new Promise(r => setTimeout(r, 0));

    const token0 = "0xToken0";
    const token1 = "0xToken1";
    const amount = BigInt(100);
    const leverage = 2;

    await result.current.openPosition(token0, token1, true, amount, leverage);

    expect(mockMarketContract.openShortPosition).toHaveBeenCalledWith(
      token0,
      token1,
      3000,
      leverage,
      amount,
      0,
      0,
      { gasLimit: 5000000 }
    );
  });

  test("depositToPool should call deposit on the pool contract", async () => {
    const { result } = renderHook(() => useDeFi());
    await new Promise(r => setTimeout(r, 0));

    const tokenKey = "USDC";
    const amount = BigInt(1000);

    await result.current.depositToPool(tokenKey, amount);

    expect(mockPoolContract.deposit).toHaveBeenCalledWith(amount, "0xUser");
  });

  test("redeemFromPool should call redeem on the pool contract", async () => {
    const { result } = renderHook(() => useDeFi());
    await new Promise(r => setTimeout(r, 0));

    const tokenKey = "USDC";
    const shares = BigInt(500);

    await result.current.redeemFromPool(tokenKey, shares);

    expect(mockPoolContract.redeem).toHaveBeenCalledWith(shares, "0xUser", "0xUser");
  });

  test("simulateOpenPosition should return success when simulation passes", async () => {
    const { result } = renderHook(() => useDeFi());
    await new Promise(r => setTimeout(r, 0));

    const token0 = "0xToken0";
    const token1 = "0xToken1";
    const amount = BigInt(100);
    const leverage = 2;

    const response = await result.current.simulateOpenPosition(token0, token1, false, amount, leverage);

    expect(response.success).toBe(true);
    expect(mockMarketContract.openLongPosition.staticCall).toHaveBeenCalled();
  });
});
