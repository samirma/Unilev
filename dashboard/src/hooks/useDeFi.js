
import { useState, useCallback, useEffect } from 'react';
import { ethers } from 'ethers';
import { useAccount, useWalletClient } from 'wagmi';

// Import ABIs
import ERC20ABI from '../abis/ERC20.json';
import MarketABI from '../abis/Market.json';
import PositionsABI from '../abis/Positions.json';
import PriceFeedL1ABI from '../abis/PriceFeedL1.json';
import LiquidityPoolFactoryABI from '../abis/LiquidityPoolFactory.json';
import LiquidityPoolABI from '../abis/LiquidityPool.json';
import FeeManagerABI from '../abis/FeeManager.json';

// Constants
const ADDRESSES = {
    WETH: process.env.WETH,
    DAI: process.env.DAI,
    USDC: process.env.USDC,
    WBTC: process.env.WBTC,
    PRICEFEEDL1: process.env.PRICEFEEDL1_ADDRESS,
    POSITIONS: process.env.POSITIONS_ADDRESS,
    MARKET: process.env.MARKET_ADDRESS,
    POOL_FACTORY: process.env.LIQUIDITYPOOLFACTORY_ADDRESS,
    FEEMANAGER_ADDRESS: process.env.FEEMANAGER_ADDRESS,
    RPC_URL: process.env.RPC_URL,
};

export function useDeFi() {
    const { address, isConnected } = useAccount();
    const { data: walletClient } = useWalletClient();

    // Providers
    const [readProvider, setReadProvider] = useState(null);

    useEffect(() => {
        if (ADDRESSES.RPC_URL) {
            const provider = new ethers.JsonRpcProvider(ADDRESSES.RPC_URL);
            setReadProvider(provider);
        }
    }, []);

    const getSigner = useCallback(async () => {
        if (!walletClient) return null;
        const provider = new ethers.BrowserProvider(window.ethereum);
        return await provider.getSigner();
    }, [walletClient]);

    // --- Logic from utils.js adapted for React ---

    const getTokenBalance = useCallback(async (tokenAddress, userAddress) => {
        if (!readProvider || !tokenAddress || !userAddress) return null;
        try {
            const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider);
            const priceFeed = new ethers.Contract(ADDRESSES.PRICEFEEDL1, PriceFeedL1ABI.abi, readProvider);

            const [symbol, decimals, balance] = await Promise.all([
                contract.symbol(),
                contract.decimals(),
                contract.balanceOf(userAddress)
            ]);

            const formattedBalance = ethers.formatUnits(balance, decimals);

            // Calculate USD Value
            const usdValueBigInt = await priceFeed.getAmountInUsd(tokenAddress, balance);
            const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2);

            return {
                symbol,
                decimals,
                balance: formattedBalance,
                usdValue,
                rawBalance: balance
            };
        } catch (error) {
            console.error("Error fetching token balance:", error);
            return null;
        }
    }, [readProvider]);

    const getNativeBalance = useCallback(async (userAddress) => {
        if (!readProvider || !userAddress) return null;
        try {
            const balance = await readProvider.getBalance(userAddress);
            const priceFeed = new ethers.Contract(ADDRESSES.PRICEFEEDL1, PriceFeedL1ABI.abi, readProvider);

            // Use WETH address for ETH price
            const usdValueBigInt = await priceFeed.getAmountInUsd(ADDRESSES.WETH, balance);
            const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2);

            return {
                symbol: 'ETH',
                decimals: 18,
                balance: ethers.formatEther(balance),
                usdValue,
                rawBalance: balance
            };
        } catch (error) {
            console.error("Error fetching native balance:", error);
            return null;
        }
    }, [readProvider]);

    const calculateTokenAmountFromUsd = useCallback(async (tokenAddress, usdAmount) => {
        if (!readProvider) return 0n;
        try {
            const contract = new ethers.Contract(tokenAddress, ERC20ABI.abi, readProvider);
            const priceFeed = new ethers.Contract(ADDRESSES.PRICEFEEDL1, PriceFeedL1ABI.abi, readProvider);

            const decimals = await contract.decimals();
            const priceInUsd = await priceFeed.getTokenLatestPriceInUsd(tokenAddress);

            const targetUsdValue = ethers.parseUnits(usdAmount.toString(), 18);
            // Formula: (TargetUSD * 10^Decimals) / PriceUSD
            return (targetUsdValue * (10n ** BigInt(decimals))) / priceInUsd;
        } catch (error) {
            console.error("Error calculating token amount:", error);
            return 0n;
        }
    }, [readProvider]);

    const openPosition = useCallback(async (token0, token1, isShort, amount, leverage) => {
        const signer = await getSigner();
        if (!signer) throw new Error("Wallet not connected");

        const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, signer);
        const tokenContract = new ethers.Contract(token0, ERC20ABI.abi, signer);

        // Approve
        const allowance = await tokenContract.allowance(address, ADDRESSES.POSITIONS);
        if (allowance < amount) {
            const txApprove = await tokenContract.approve(ADDRESSES.POSITIONS, amount);
            await txApprove.wait();
        }

        // Open Position
        // Params: token0, token1, fee(3000), isShort, leverage, amount, limit(0), stop(0)
        const tx = await market.openPosition(
            token0,
            token1,
            3000,
            isShort,
            leverage,
            amount,
            0,
            0,
            { gasLimit: 5000000 }
        );
        return tx;
    }, [address, getSigner]);

    const closePosition = useCallback(async (posId) => {
        const signer = await getSigner();
        if (!signer) throw new Error("Wallet not connected");

        const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, signer);
        const tx = await market.closePosition(posId, { gasLimit: 2000000 });
        return tx;
    }, [getSigner]);

    const getPositionDetails = useCallback(async (posId) => {
        if (!readProvider) return null;
        try {
            const market = new ethers.Contract(ADDRESSES.MARKET, MarketABI.abi, readProvider);
            const priceFeed = new ethers.Contract(ADDRESSES.PRICEFEEDL1, PriceFeedL1ABI.abi, readProvider);
            const positions = new ethers.Contract(ADDRESSES.POSITIONS, PositionsABI.abi, readProvider);

            // Check ownership/existence
            // positions.ownerOf might revert if burned
            let owner;
            try {
                owner = await positions.ownerOf(posId);
            } catch {
                return null; // Position closed/burned
            }

            const params = await market.getPositionParams(posId);
            // params: baseToken, quoteToken, positionSize, timestamp, isShort, leverage...

            const [baseToken, quoteToken, positionSize, , isShort, leverage] = params;

            const baseContract = new ethers.Contract(baseToken, ERC20ABI.abi, readProvider);
            const quoteContract = new ethers.Contract(quoteToken, ERC20ABI.abi, readProvider);

            const [baseSymbol, baseDecimals, quoteSymbol] = await Promise.all([
                baseContract.symbol(),
                baseContract.decimals(),
                quoteContract.symbol()
            ]);

            const usdValueBigInt = await priceFeed.getAmountInUsd(baseToken, positionSize);
            const usdValue = parseFloat(ethers.formatUnits(usdValueBigInt, 18)).toFixed(2);

            const stateInt = await positions.getPositionState(posId);
            const states = ["NONE", "TAKE_PROFIT", "ACTIVE", "STOP_LOSS", "LIQUIDATABLE", "BAD_DEBT", "EXPIRED"];
            const state = states[Number(stateInt)] || "UNKNOWN";

            return {
                id: posId.toString(),
                owner,
                state,
                isShort,
                leverage: leverage.toString(),
                baseToken,
                quoteToken,
                baseSymbol,
                quoteSymbol,
                size: ethers.formatUnits(positionSize, baseDecimals),
                sizeUsd: usdValue,
            };

        } catch (error) {
            console.error(`Error fetching pos ${posId}:`, error);
            return null;
        }
    }, [readProvider]);

    const getPositionsCount = useCallback(async () => {
        if (!readProvider) return 0n;
        try {
            const positions = new ethers.Contract(ADDRESSES.POSITIONS, PositionsABI.abi, readProvider);
            return await positions.posId();
        } catch (error) {
            console.error("Error fetching positions count:", error);
            return 0n;
        }
    }, [readProvider]);


    // --- Pool & Protocol Logic ---

    const getProtocolBalances = useCallback(async () => {
        if (!readProvider) return null;
        try {
            const priceFeed = new ethers.Contract(ADDRESSES.PRICEFEEDL1, PriceFeedL1ABI.abi, readProvider);
            const factory = new ethers.Contract(ADDRESSES.POOL_FACTORY, LiquidityPoolFactoryABI.abi, readProvider);

            const tokens = [
                { key: 'WETH', address: ADDRESSES.WETH },
                { key: 'DAI', address: ADDRESSES.DAI },
                { key: 'USDC', address: ADDRESSES.USDC },
                { key: 'WBTC', address: ADDRESSES.WBTC }
            ];

            const positionsBalances = {};
            const poolBalances = {};

            for (const token of tokens) {
                if (!token.address) continue;
                const tokenContract = new ethers.Contract(token.address, ERC20ABI.abi, readProvider);

                // 1. POSITIONS Contract Balance
                const posBal = await tokenContract.balanceOf(ADDRESSES.POSITIONS);
                const posDecimals = await tokenContract.decimals();
                const posUsdBig = await priceFeed.getAmountInUsd(token.address, posBal);

                positionsBalances[token.key] = {
                    balance: ethers.formatUnits(posBal, posDecimals),
                    usdValue: parseFloat(ethers.formatUnits(posUsdBig, 18)).toFixed(2)
                };

                // 2. Liquidity Pool Info
                const poolAddress = await factory.getTokenToLiquidityPools(token.address);
                if (poolAddress && poolAddress !== ethers.ZeroAddress) {
                    const poolContract = new ethers.Contract(poolAddress, LiquidityPoolABI.abi, readProvider);
                    const totalAssets = await poolContract.totalAssets();
                    const totalAssetsUsdBig = await priceFeed.getAmountInUsd(token.address, totalAssets);

                    // User Shares (if connected)
                    let userShares = 0n;
                    let userAssets = 0n;
                    if (address) {
                        userShares = await poolContract.balanceOf(address);
                        if (userShares > 0n) {
                            userAssets = await poolContract.convertToAssets(userShares);
                        }
                    }

                    poolBalances[token.key] = {
                        address: poolAddress,
                        totalAssets: ethers.formatUnits(totalAssets, posDecimals),
                        totalAssetsUsd: parseFloat(ethers.formatUnits(totalAssetsUsdBig, 18)).toFixed(2),
                        userShares: ethers.formatUnits(userShares, posDecimals),
                        userAssets: ethers.formatUnits(userAssets, posDecimals)
                    };
                }
            }

            return { positionsBalances, poolBalances };

        } catch (error) {
            console.error("Error fetching protocol balances:", error);
            return null;
        }
    }, [readProvider, address]);

    const depositToPool = useCallback(async (tokenKey, amount) => {
        const signer = await getSigner();
        if (!signer) throw new Error("Wallet not connected");

        const tokenAddress = ADDRESSES[tokenKey];
        if (!tokenAddress) throw new Error("Invalid Token");

        // Get Pool Address
        const factory = new ethers.Contract(ADDRESSES.POOL_FACTORY, LiquidityPoolFactoryABI.abi, readProvider);
        const poolAddress = await factory.getTokenToLiquidityPools(tokenAddress);

        if (!poolAddress || poolAddress === ethers.ZeroAddress) throw new Error("Pool not found");

        const tokenContract = new ethers.Contract(tokenAddress, ERC20ABI.abi, signer);
        const poolContract = new ethers.Contract(poolAddress, LiquidityPoolABI.abi, signer);

        // Approve
        const allowance = await tokenContract.allowance(address, poolAddress);
        if (allowance < amount) {
            const txApprove = await tokenContract.approve(poolAddress, amount);
            await txApprove.wait();
        }

        // Deposit
        const tx = await poolContract.deposit(amount, address);
        return tx;
    }, [address, getSigner, readProvider]);

    const redeemFromPool = useCallback(async (tokenKey, shares) => {
        const signer = await getSigner();
        if (!signer) throw new Error("Wallet not connected");

        const tokenAddress = ADDRESSES[tokenKey];
        const factory = new ethers.Contract(ADDRESSES.POOL_FACTORY, LiquidityPoolFactoryABI.abi, readProvider);
        const poolAddress = await factory.getTokenToLiquidityPools(tokenAddress);

        const poolContract = new ethers.Contract(poolAddress, LiquidityPoolABI.abi, signer);

        // redeem(shares, receiver, owner)
        const tx = await poolContract.redeem(shares, address, address);
        return tx;
    }, [address, getSigner, readProvider]);

    // --- Fee Manager Logic ---

    const getFeeDefaults = useCallback(async () => {
        if (!readProvider) return null;
        try {
            const feeManager = new ethers.Contract(ADDRESSES.FEEMANAGER_ADDRESS, FeeManagerABI.abi, readProvider);
            const [treasureFee, liquidationReward] = await Promise.all([
                feeManager.defaultTreasureFee(),
                feeManager.defaultLiquidationReward()
            ]);
            return {
                treasureFee: treasureFee.toString(),
                liquidationReward: liquidationReward.toString()
            };
        } catch (error) {
            console.error("Error fetching fee defaults:", error);
            return null;
        }
    }, [readProvider]);

    const updateFeeDefaults = useCallback(async (treasureFee, liquidationReward) => {
        const signer = await getSigner();
        if (!signer) throw new Error("Wallet not connected");

        const feeManager = new ethers.Contract(ADDRESSES.FEEMANAGER_ADDRESS, FeeManagerABI.abi, signer);
        const tx = await feeManager.setDefaultFees(treasureFee, liquidationReward);
        return tx;
    }, [getSigner]);

    return {
        ADDRESSES,
        readProvider,
        getTokenBalance,
        calculateTokenAmountFromUsd,
        openPosition,
        closePosition,
        getPositionDetails,
        getPositionsCount,
        getProtocolBalances,
        depositToPool,
        redeemFromPool,
        getFeeDefaults,
        updateFeeDefaults,
        getNativeBalance
    };
}
