//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./SafeMath.sol";
import "./UniswapV2Library.sol";
import "../tools/FullMath.sol";
import "../tools/Babylonian.sol";
import "../interfaces/IUniswapV2Factory.sol";

/**
 * 在 Uniswap V2 的核心合约（如 UniswapV2Pair 或 UniswapV2Factory）中，并没有直接使用 UniswapV2LiquidityMathLibrary。这是因为核心合约的逻辑已经内置了流动性计算的实现，而不需要依赖外部库
 *
 * 自定义流动性管理合约：开发者可以在自己的合约中导入 UniswapV2LiquidityMathLibrary，用于处理流动性添加和移除的逻辑
 * DeFi 协议：一些 DeFi 协议可能需要与 Uniswap V2 流动性池交互，并使用 UniswapV2LiquidityMathLibrary 进行流动性计算。
 *
 *
 * UniswapV2LiquidityMathLibrary 是一个用于流动性计算的工具库。
 * 它主要用于添加流动性、移除流动性以及流动性代币数量的计算。
 * 在 Uniswap V2 的核心合约中并未直接使用，而是用于外部合约或应用程序中。
 * 如果你需要处理与 Uniswap V2 流动性相关的数学计算，可以导入并使用 UniswapV2LiquidityMathLibrary。
 */
library UniswapV2LiquidityMathLibrary {
    using SafeMath for uint256;

    // computes the direction and magnitude of the profit-maximizing trade
    function computeProfitMaximizingTrade(
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (bool aToB, uint256 amountIn) {
        aToB = FullMath.mulDiv(reserveA, truePriceTokenB, reserveB) < truePriceTokenA;

        uint256 invariant = reserveA.mul(reserveB);

        uint256 leftSide = Babylonian.sqrt(
            FullMath.mulDiv(
                invariant.mul(1000),
                aToB ? truePriceTokenA : truePriceTokenB,
                (aToB ? truePriceTokenB : truePriceTokenA).mul(997)
            )
        );
        uint256 rightSide = (aToB ? reserveA.mul(1000) : reserveB.mul(1000)) / 997;

        if (leftSide < rightSide) return (false, 0);

        // compute the amount that must be sent to move the price to the profit-maximizing price
        amountIn = leftSide.sub(rightSide);
    }

    // gets the reserves after an arbitrage moves the price to the profit-maximizing ratio given an externally observed true price
    function getReservesAfterArbitrage(
        address factory,
        address tokenA,
        address tokenB,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        // first get reserves before the swap
        (reserveA, reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);

        require(reserveA > 0 && reserveB > 0, "UniswapV2ArbitrageLibrary: ZERO_PAIR_RESERVES");

        // then compute how much to swap to arb to the true price
        (bool aToB, uint256 amountIn) =
            computeProfitMaximizingTrade(truePriceTokenA, truePriceTokenB, reserveA, reserveB);

        if (amountIn == 0) {
            return (reserveA, reserveB);
        }

        // now affect the trade to the reserves
        if (aToB) {
            uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveA, reserveB);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            uint256 amountOut = UniswapV2Library.getAmountOut(amountIn, reserveB, reserveA);
            reserveB += amountIn;
            reserveA -= amountOut;
        }
    }

    // computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 reservesA,
        uint256 reservesB,
        uint256 totalSupply,
        uint256 liquidityAmount,
        bool feeOn,
        uint256 kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (feeOn && kLast > 0) {
            uint256 rootK = Babylonian.sqrt(reservesA.mul(reservesB));
            uint256 rootKLast = Babylonian.sqrt(kLast);
            if (rootK > rootKLast) {
                uint256 numerator1 = totalSupply;
                uint256 numerator2 = rootK.sub(rootKLast);
                uint256 denominator = rootK.mul(5).add(rootKLast);
                uint256 feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                totalSupply = totalSupply.add(feeLiquidity);
            }
        }
        return (reservesA.mul(liquidityAmount) / totalSupply, reservesB.mul(liquidityAmount) / totalSupply);
    }

    // get all current parameters from the pair and compute value of a liquidity amount
    // **note this is subject to manipulation, e.g. sandwich attacks**. prefer passing a manipulation resistant price to
    // #getLiquidityValueAfterArbitrageToPrice
    function getLiquidityValue(address factory, address tokenA, address tokenB, uint256 liquidityAmount)
        internal
        view
        returns (uint256 tokenAAmount, uint256 tokenBAmount)
    {
        (uint256 reservesA, uint256 reservesB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        bool feeOn = IUniswapV2Factory(factory).feeTo() != address(0);
        uint256 kLast = feeOn ? pair.kLast() : 0;
        uint256 totalSupply = pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }

    // given two tokens, tokenA and tokenB, and their "true price", i.e. the observed ratio of value of token A to token B,
    // and a liquidity amount, returns the value of the liquidity in terms of tokenA and tokenB
    function getLiquidityValueAfterArbitrageToPrice(
        address factory,
        address tokenA,
        address tokenB,
        uint256 truePriceTokenA,
        uint256 truePriceTokenB,
        uint256 liquidityAmount
    ) internal view returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        bool feeOn = IUniswapV2Factory(factory).feeTo() != address(0);
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        uint256 kLast = feeOn ? pair.kLast() : 0;
        uint256 totalSupply = pair.totalSupply();

        // this also checks that totalSupply > 0
        require(totalSupply >= liquidityAmount && liquidityAmount > 0, "ComputeLiquidityValue: LIQUIDITY_AMOUNT");

        (uint256 reservesA, uint256 reservesB) =
            getReservesAfterArbitrage(factory, tokenA, tokenB, truePriceTokenA, truePriceTokenB);

        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }
}
