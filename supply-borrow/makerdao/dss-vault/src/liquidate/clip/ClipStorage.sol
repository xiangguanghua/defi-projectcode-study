// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface VatLike {
    function move(address, address, uint256) external;
    function flux(bytes32, address, address, uint256) external;
    function ilks(bytes32) external returns (uint256, uint256, uint256, uint256, uint256);
    function suck(address, address, uint256) external;
}

interface PipLike {
    function peek() external returns (bytes32, bool);
}

interface SpotterLike {
    function par() external returns (uint256);
    function ilks(bytes32) external returns (PipLike, uint256);
}

interface DogLike {
    function chop(bytes32) external returns (uint256);
    function digs(bytes32, uint256) external;
}

interface ClipperCallee {
    function clipperCall(address, uint256, uint256, bytes calldata) external;
}

interface AbacusLike {
    function price(uint256, uint256) external view returns (uint256);
}

contract ClipStorage {
    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    event Kick(
        uint256 indexed id,
        uint256 top,
        uint256 tab,
        uint256 lot,
        address indexed usr,
        address indexed kpr,
        uint256 coin
    );
    event Take(
        uint256 indexed id, uint256 max, uint256 price, uint256 owe, uint256 tab, uint256 lot, address indexed usr
    );
    event Redo(
        uint256 indexed id,
        uint256 top,
        uint256 tab,
        uint256 lot,
        address indexed usr,
        address indexed kpr,
        uint256 coin
    );

    event Yank(uint256 id);

    bytes32 public immutable ilk; // 本Clipper处理的抵押品类型(如"ETH-A")
    VatLike public immutable vat; // 核心CDP引擎合约

    DogLike public dog; // 清算管理模块
    address public vow; // 拍卖收益接收地址
    SpotterLike public spotter; // 抵押品价格模块,提供抵押品的实时价格信息,与OSM(预言机安全模块)交互
    AbacusLike public calc; // 价格计算模块,专用于计算荷兰式拍卖的价格曲线,实现价格随时间下降的算法

    uint256 public buf; // 初始价格乘数 [ray]
    uint256 public tail; // 拍卖持续时间 [秒]                  [seconds]
    uint256 public cusp; // 价格曲线拐点 [ray]
    uint64 public chip; // 竞拍者激励比例 [wad]
    uint192 public tip; // 固定清算费用 [rad]
    uint256 public chost; // 最小抵押品单位 [rad]

    uint256 public kicks; // 发起的拍卖总数

    struct Sale {
        uint256 pos; // 在销售队列中的位置
        uint256 tab; // 待回收的 Dai 债务数量 (rad)
        uint256 lot; // 待拍卖的抵押品数量 (wad)
        address usr; // 被清算的 Vault 所有者
        uint96 tic; // 拍卖开始时间戳
        uint256 top; // 当前单位价格 (ray)
    }

    // 拍卖ID => 拍卖数据
    mapping(uint256 => Sale) public sales; // 所有拍卖的存储映射.
    uint256[] public active; // 活跃拍卖ID数组

    uint256 internal locked; // 重入锁标记

    // Levels for circuit breaker
    // 0: no breaker
    // 1: no new kick()
    // 2: no new kick() or redo()
    // 3: no new kick(), redo(), or take()
    uint256 public stopped = 0; // 断路器级别

    uint256 constant BLN = 10 ** 9;
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
}
