//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {SafeMath} from "../libraries/SafeMath.sol";
import {Math} from "../libraries/Math.sol";
import {UQ112x112} from "../libraries/UQ112x112.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {UniswapV2ERC20} from "./UniswapV2ERC20.sol";
import {IUniswapV2Callee} from "../interfaces/IUniswapV2Callee.sol";
import {IERC20} from "../interfaces/IERC20.sol";

// 交易对合约 address(token0) => address(token1)
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3; // 最小保留流动性
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    //====================errors==============//
    error UniswapV2Pair__Locked();
    // 工厂三剑客

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0; //代币 token0 的储备量
    uint112 private reserve1; //代币 token1 的储备量
    uint32 private blockTimestampLast; //最后一次更新储备量的时间戳

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1

    uint256 private unlocked = 1;

    modifier lock() {
        if (unlocked == 0) revert UniswapV2Pair__Locked();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    // msg.sender为工厂地址

    constructor() {
        // 部署者是工厂地址，部署者就是调用createPair方法的用户
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * 获取储备量
     * @return _reserve0 代币 token0 的储备量
     * @return _reserve1 代币 token1 的储备量
     * @return _blockTimestampLast 最后一次更新储备量的时间戳
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2: TRANSFER_FAILED");
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "UniswapV2: OVERFLOW");
        // 将事件控制在32位整数范围内，效果与uint32(block.timestamp)相同
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        // 计算时间间隔,会发生溢出
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 计算累计价格：计算 _reserve1 / _reserve0， token0的价格 = token1/token0，乘以timeElapsed，得到时间间隔的累计价格，并累加price1CumulativeLast中
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            /**
             * 等价于下面这段代码
             * price0CumulativeLast += uint256(_reserve1) * timeElapsed / _reserve0;
             * price1CumulativeLast += uint256(_reserve0) * timeElapsed / _reserve1;
             */
        }
        // 更新值
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /**
     * 铸造手续费
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // 获取上一次的流动性
        if (feeOn) {
            if (_kLast != 0) {
                // 计算当前最新流动性 取平方根
                uint256 rootK = Math.sqrt(uint256(_reserve0).mul(_reserve1));
                // 获取上一次的流动性，取平方根
                uint256 rootKLast = Math.sqrt(_kLast);
                // 如果最新流动性大于上次流动性，则说明流动性增加了
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    // 计算分给feeTo的LP token
                    uint256 liquidity = numerator / denominator;
                    //铸造LPtoken
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    //添加流动性
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings

        // 获取交易对合约在token0和token01中的储备量
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        //获取本次添加流动性时token0和token1的数量
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        // 计算手续费
        bool feeOn = _mintFee(_reserve0, _reserve1);
        //获取当前LP token的总量,赋值给_totalSupply,gas savings，便于下方调用
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            //首次添加流动性,取平方根
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            /**
             * 取最小值的原因：
             * 1、确保公平分配
             * 1）流动性代币的分配应基于用户添加的代币数量与当前储备量的比例
             * 2）如果用户添加的代币数量与当前储备量的比例不一致，取较小值可以确保流动性代币的分配公平。
             * 2、防止不平衡添加
             * 1）如果用户添加的代币数量与当前储备量的比例不一致，可能会导致交易对的价格偏离市场价格
             * 2）取较小值可以防止用户通过不平衡的添加获取额外收益。
             */
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        // 铸造流动性币，分配给to
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    //销毁流动性，换回tokenA和tokenB
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        // 获取流动性
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        // 按照比例计算出token的数量
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution

        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        //移除流动性
        _burn(address(this), liquidity);

        // 转账
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * 允许用户将一种代币兑换为另一种代币
     * @param amount0Out 用户希望从流动性池中获取的 token0 的数量
     * @param amount1Out 用户希望从流动性池中获取的 token1 的数量
     * @param to 接收输出代币的目标地址
     * @param data 可选参数，通常用于闪电贷（flash swap）场景，传递额外的调用数据
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            // 闪电贷逻辑，写一个合约继承IUniswapV2Callee并实现uniswapV2Call方法，在uniswapV2Call方法中编写自己想要的逻辑
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        {
            //代币交换后验证恒定乘积公式是否仍然成立
            //通过调整余额并考虑 0.3% 的手续费，确保流动性池的健康性
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            /**
             * balance0Adjusted = balance0 * 1000 - amount0In * 3
             * balance1Adjusted = balance1 * 1000 - amount1In * 3
             */
            uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));

            //mul(1000 ** 2),因为_reserve0和_reserve1都要乘以1000
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(1000 ** 2),
                "UniswapV2: K"
            );
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    /**
     * 强制更新流动性池
     * @param to 接收多余代币的目标地址
     */
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balanceToken0 = IERC20(_token0).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(_token1).balanceOf(address(this));
        //多余的token数量转给to
        _safeTransfer(_token0, to, balanceToken0.sub(reserve0));
        _safeTransfer(_token1, to, balanceToken1.sub(reserve1));
    }

    // force reserves to match balances
    /**
     * 函数用于强制更新流动性池的储备量，使其与合约的实际代币余额一致
     *  它可以用于恢复储备量或处理异常情况
     *  代码通过优化 gas 使用和提供安全的更新机制，提高了合约的效率和可靠性
     */
    function sync() external lock {
        uint256 balanceToken0 = IERC20(token0).balanceOf(address(this));
        uint256 balanceToken1 = IERC20(token1).balanceOf(address(this));
        _update(balanceToken0, balanceToken1, reserve0, reserve1);
    }
}
