//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UniswapV1Factory} from "./UniswapV1Factory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IExchange} from "./interface/IExchange.sol";
import {IFactory} from "./interface/IFactory.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * 交易对
 * @title  交易对 token -> ether
 * @notice 创建交易对
 */
contract UniswapV1Exchange is ReentrancyGuard, ERC20 {
    //----------------------代币变量-----------------------------
    address public tokenAddress; // 关联的 ERC20 代币地址
    address public factoryAddress; //工厂地址

    //uint256 public ethReserve; // ETH 储备量
    //uint256 public tokenReserve; // ERC20 代币储备量

    // 初始化交易对
    constructor(address _token) ERC20("Uniswap V1 Liquidity Provider", "ULP") {
        require(_token != address(0), "invalid token address");
        /**
         * 由于每个Exchange合约只允许使用一种代币进行交换，
         * 因此需要将代币合约地址和Exchange合约地址绑定。
         */
        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    //=====================流动性提供者的方法===============//
    function addLiquidity(uint256 _tokenAmount) public payable nonReentrant returns (uint256 liquidity) {
        if (getTokenReserve() == 0) {
            // 若没有储备量，首次添加流动性
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);
            liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
            return liquidity;
        } else {
            /**
             * 当流动性提供者调用 addLiquidity 函数时，他们会通过 msg.value 发送一定数量的 ETH 到合约中。
             * 因此，address(this).balance 的值已经包含了 ​新发送的 ETH​（即 msg.value）。
             * 为了获取 ​当前池中的 ETH 储备量​（即添加流动性之前的 ETH 余额），需要从 address(this).balance 中减去 msg.value：
             */
            uint256 ethReserve = address(this).balance - msg.value; // 获取当前池中的 ETH 储备量
            uint256 tokenReserve = getTokenReserve(); // 获取Token的储备粮
            // 保持公式一致性 （ethReserve / tokenReserve） = (msg.value / tokenAmount)  => tokenAmount = (msg.value * tokenReserve) / ethReserve
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve; // 计算至少应该传入的 token数量
            require(_tokenAmount >= tokenAmount, "insufficient token amount");

            IERC20 token = IERC20(tokenAddress);
            /**
             * 使用的是 ​计算好的 tokenAmount，而不是直接使用 _tokenAmount，
             * 原因是为了​确保流动性提供者按照当前池中的资产比例添加流动性，从而保持添加流动性前后的价格不变。
             * tokenAmount 是流动性提供者 ​希望添加的代币数量，但它的值可能 ​不符合当前池中的资产比例。
             * 如果直接使用 _tokenAmount，可能会导致添加流动性后的价格发生变化，破坏流动性池的平衡。
             */
            token.transferFrom(msg.sender, address(this), tokenAmount);
            /**
             * msg.value：流动性提供者发送的 ETH 数量。
             * totalSupply()：当前 LP Token 的总供应量。
             * ethReserve：当前池中的 ETH 储备量。
             */
            liquidity = (msg.value * totalSupply()) / ethReserve; //计算流动性提供者应获得的 LP Token 数量
            _mint(msg.sender, liquidity);
            return liquidity;
        }
    }

    /**
     * 提供LP token 提取代币减掉流动性
     * @param _lpAmount LP token 数量
     */
    function removeLiquidity(uint256 _lpAmount) public nonReentrant returns (uint256 ethAmount, uint256 tokenAmount) {
        require(_lpAmount > 0, "invalid amount");
        /**
         * address(this).balance：当前合约地址的 ETH 余额，即流动性池中的 ETH 储备量。
         * _amount：流动性提供者销毁的 LP Token 数量。
         * totalSupply()：当前 LP Token 的总供应量。
         */
        ethAmount = (address(this).balance * _lpAmount) / totalSupply(); // ​计算流动性提供者应赎回的 ETH 数量

        /**
         * getTokenReserve()：当前流动性池中的代币储备量。
         * _amount：流动性提供者销毁的 LP Token 数量。
         * totalSupply()：当前 LP Token 的总供应量。
         */
        tokenAmount = (getTokenReserve() * _lpAmount) / totalSupply(); // ​计算流动性提供者应赎回的 token 数量

        // 注销掉流动性
        _burn(msg.sender, _lpAmount);
        // 返还ethamout给用户
        payable(msg.sender).transfer(ethAmount);
        // 返还tokenAmount给用户
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
    }

    //==================给用户调用的方法=====================//
    /**
     * 用户输入eth获取token
     * @param _ethSold 输入的token量
     */
    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ethSold is too small");

        uint256 tokenReserve = getTokenReserve();

        return getAmount(_ethSold, address(this).balance, tokenReserve);
    }
    /**
     * 用户输入token获取eth
     * @param _tokenSold 输入的eth量
     */

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "tokenSold is too small");

        uint256 tokenReserve = getTokenReserve();

        return getAmount(_tokenSold, tokenReserve, address(this).balance);
    }

    // token卖出
    function ethToToken(uint256 _minTokens, address recipient) private {
        uint256 tokenReserve = getTokenReserve(); // 获取token储备量
        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);
        require(tokensBought >= _minTokens, "insufficient output amount");
        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }

    // eth 转换成 token
    function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable {
        ethToToken(_minTokens, _recipient);
    }

    // eth 转换成 token
    function ethToTokenSwap(uint256 _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    // token 换成 eth
    function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
        uint256 tokenReserve = getTokenReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        require(ethBought >= _minEth, "insufficient output amount");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        payable(msg.sender).transfer(ethBought);
    }

    function tokenToTokenSwap(uint256 _tokensSold, uint256 _minTokensBought, address _tokenAddress) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0), "invalid exchange address");

        uint256 tokenReserve = getTokenReserve();
        uint256 ethBought = getAmount(_tokensSold, tokenReserve, address(this).balance);

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(_minTokensBought, msg.sender);
    }

    // 计算金额
    /**
     * x * y = k
     * (x + delta X) * (y - delta Y) = k
     * (x + delta X) * (y - delta Y) = x * y
     * delta Y = (y * delta x) / (x + delta x)
     */
    /**
     * 计算提取金额通用公式
     * @param inputAmount   换取的数量
     * @param inputReserve  要增加的量
     * @param outputReserve 要减少的量
     */
    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        private
        pure
        returns (uint256 targetAmount)
    {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = inputAmountWithFee * outputReserve; // (y * delta x)
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee; //  (x + delta x)
        targetAmount = numerator / denominator;
        return targetAmount;
    }

    /**
     * 获取当前合约在Token合约上的储备量
     */
    function getTokenReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getEthReserve() public view returns (uint256) {
        return address(this).balance;
    }
}
