//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UniswapV1Exchange} from "./UniswapV1Exchange.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title UniswapFactory 交易对工厂
 * @notice 创建交易对
 */
contract UniswapV1Factory is ReentrancyGuard {
    // 存储所有已部署的交易对合约:  Token => exchange token
    mapping(address => address) public tokenToExchange;
    address[] public allExchanges;

    event ExchangeCreated(address indexed token, address indexed exchange);

    // 部署新的交易对合约（ERC20/ETH）
    function createExchange(address token) external returns (address exchange) {
        require(token != address(0), "Invalid token address");
        require(tokenToExchange[token] == address(0), "Exchange already exists");

        exchange = address(new UniswapV1Exchange(token)); // 使用token创建交易对

        // 存储交易对信息
        tokenToExchange[token] = exchange;
        allExchanges.push(exchange);

        // 记录日志
        emit ExchangeCreated(token, exchange);

        // 返回交易对
        return exchange;
    }

    // 获取交易对
    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress];
    }

    // 获取所有已部署的交易对数量
    function allExchangesLength() external view returns (uint256) {
        return allExchanges.length;
    }
}
