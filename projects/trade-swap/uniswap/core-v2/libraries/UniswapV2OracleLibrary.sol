//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FixedPoint} from "../tools/FixedPoint.sol";
import "../interfaces/IUniswapV2Pair.sol";

/**
 * @title UniswapV2OracleLibrary 是一个用于计算时间加权平均价格（TWAP）的工具库。
 *
 * 它主要用于外部合约或应用程序中，而不是在 Uniswap V2 的核心合约中直接使用。
 * 典型的使用场景包括 DeFi 协议、价格预言机和自定义合约。
 * 如果你需要从 Uniswap V2 获取价格数据，可以导入并使用 UniswapV2OracleLibrary。
 *
 * 以下是一些可能使用 UniswapV2OracleLibrary 的项目或协议：
 * ​Chainlink：
 * Chainlink 的去中心化预言机网络可以使用 UniswapV2OracleLibrary 从 Uniswap V2 获取价格数据。
 * ​Compound：
 * Compound 等借贷协议可以使用 UniswapV2OracleLibrary 获取资产价格，用于清算和借贷逻辑。
 * ​SushiSwap：
 * SushiSwap 等分叉项目可能使用类似的库来获取价格数据。
 */
library UniswapV2OracleLibrary {
    using FixedPoint for *;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(address pair)
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}
