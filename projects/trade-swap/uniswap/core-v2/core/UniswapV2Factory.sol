//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {UniswapV2Pair, IUniswapV2Pair} from "./UniswapV2Pair.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

// 创建交易对工厂
// 实现创建 address(pair) => (address (token0) => address (token1))
contract UniswapV2Factory is IUniswapV2Factory {
    //======================errors=====================//
    error UniswapV2Factory__IdenticalAddress();
    error UniswapV2Factory__ZeroAddress();
    error UniswapV2Factory__PairExists();

    address public feeTo; //手续费给谁？
    address public feeToSetter; //手续费给谁的设置者

    // 存储交易对关系 address(token) => ( address(token) => address(pair) )
    mapping(address => mapping(address => address)) public getPair;
    // 存储所有交易对
    address[] public allPairs;

    //===========================event===================
    event UniswapV2Factory__PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairs);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 如果是相同的地址，抛出异常
        if (tokenA == tokenB) revert UniswapV2Factory__IdenticalAddress();
        // 对2个地址排序，确保小的地址在前面，使用三目运算符
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // 0 地址判断
        if (token0 == address(0)) revert UniswapV2Factory__ZeroAddress();
        // 判断交易对是否存在
        if (getPair[token0][token1] != address(0)) revert UniswapV2Factory__PairExists();

        // 获取UniswapV2Pair合约字节码，使用字节码创建合约。
        /**
         * 使用交易对合约字节码创建合约 与 new关键字创建合约的优劣势对比
         * 一、确定性合约地址
         * 1、使用 new 关键字创建合约时，合约地址是基于部署者的地址和 nonce 计算得出的，因此地址是不可预测的。
         * 2、create2 允许根据字节码和盐值（salt）生成确定性的合约地址。这使得交易对地址可以被提前计算和验证，从而在 Uniswap 中实现高效的交易对管理和查询。
         * 二、高效的重部署
         * 1、如果使用 new 关键字，每次部署合约时都会生成一个新的地址，即使合约的字节码和初始化参数完全相同。
         * 2、通过 create2，如果相同的字节码和盐值被重复使用，可以确保部署到相同的地址。这在 Uniswap 中非常重要，因为交易对合约的地址需要唯一且可预测。
         * 三、防止重复部署
         * 1、使用 new 关键字无法防止重复部署相同的合约，因为每次部署都会生成一个新的地址。
         * 2、通过 create2，可以确保相同的交易对不会被重复部署，因为相同的字节码和盐值会生成相同的地址。Uniswap 可以通过检查地址是否已经存在来防止重复部署。
         * 四、优化 Gas 成本
         * 1、使用 new 关键字部署合约时，每次都需要重新发送字节码，这会增加 Gas 成本。
         * 2、create2 允许复用字节码，从而减少 Gas 成本。在 Uniswap 中，由于交易对合约的字节码是固定的，使用 create2 可以显著降低部署成本。
         * 五、灵活性和可扩展性
         * 1、使用 new 关键字部署合约时，合约的地址与部署者的地址和 nonce 绑定，这限制了合约地址的灵活性。
         * 2、create2 提供了更大的灵活性，可以根据业务需求生成特定的合约地址。在 Uniswap 中，这允许根据代币对的地址生成唯一的交易对地址。
         *
         */
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // 将2个交易对地址紧打包然后生成哈希值
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        //使用内联汇编语言通过create2创建UniswapV2Pair合约地址
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //传入建议对的地址给接口，则会调用pair实现的方法
        IUniswapV2Pair(pair).initialize(token0, token1);

        //存入交易对(双映射)
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        //存入pair
        allPairs.push(pair);
        emit UniswapV2Factory__PairCreated(token0, token1, pair, allPairs.length);
        return pair;
    }

    //======================set方法====================//
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    //======================get方法====================//
    //获取交易对大小
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    //===============testfuction=============//
    //     function insertPairs(address tokenA, address tokenB, address pair) external {
    //         getPair[tokenA][tokenB] = pair;
    //     }
}
