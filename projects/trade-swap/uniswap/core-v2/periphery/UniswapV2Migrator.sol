//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TransferHelper} from "../tools/TransferHelper.sol";
import {IUniswapV2Migrator} from "../interfaces/IUniswapV2Migrator.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

import {IUniswapV1Factory} from "../interfaces/V1/IUniswapV1Factory.sol";
import {IUniswapV1Exchange} from "../interfaces/V1/IUniswapV1Exchange.sol";

import "./UniswapV2Router01.sol";

contract UniswapV2Migrator is IUniswapV2Migrator {
    IUniswapV1Factory immutable factoryV1;
    IUniswapV2Router01 immutable router;

    constructor(address _factoryV1, address _router) {
        factoryV1 = IUniswapV1Factory(_factoryV1);
        router = IUniswapV2Router01(_router);
    }

    // needs to accept ETH from any v1 exchange and the router. ideally this could be enforced, as in the router,
    // but it's not possible because it requires a call to the v1 factory, which takes too much gas
    receive() external payable {}

    function migrate(address token, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)
        external
        override
    {
        IUniswapV1Exchange exchangeV1 = IUniswapV1Exchange(factoryV1.getExchange(token));
        uint256 liquidityV1 = exchangeV1.balanceOf(msg.sender);
        require(exchangeV1.transferFrom(msg.sender, address(this), liquidityV1), "TRANSFER_FROM_FAILED");
        (uint256 amountETHV1, uint256 amountTokenV1) = exchangeV1.removeLiquidity(liquidityV1, 1, 1, type(uint256).max);
        TransferHelper.safeApprove(token, address(router), amountTokenV1);
        (uint256 amountTokenV2, uint256 amountETHV2,) =
            router.addLiquidityETH{value: amountETHV1}(token, amountTokenV1, amountTokenMin, amountETHMin, to, deadline);
        if (amountTokenV1 > amountTokenV2) {
            TransferHelper.safeApprove(token, address(router), 0); // be a good blockchain citizen, reset allowance to 0
            TransferHelper.safeTransfer(token, msg.sender, amountTokenV1 - amountTokenV2);
        } else if (amountETHV1 > amountETHV2) {
            // addLiquidityETH guarantees that all of amountETHV1 or amountTokenV1 will be used, hence this else is safe
            TransferHelper.safeTransferETH(msg.sender, amountETHV1 - amountETHV2);
        }
    }
}
