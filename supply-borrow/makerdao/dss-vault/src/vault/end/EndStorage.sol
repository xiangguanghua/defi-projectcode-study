// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

contract EndStorage {
    VatLike public vat; // CDP Engine
    CatLike public cat; // 传统清算系统（抵押不足清算）
    DogLike public dog; // 新版清算系统2.0
    VowLike public vow; // 债务引擎（坏账处理）
    PotLike public pot; // DSR存款系统
    SpotLike public spot; // 价格预言机系统
    CureLike public cure; // 债务修复模块

    uint256 public when; // 系统关闭时间戳
    uint256 public wait; // 处理冷却期（秒）
    uint256 public debt; // 关闭时总未偿Dai债务 [rad]

    mapping(bytes32 => uint256) public tag; // 关闭时抵押品定价 [ray]
    mapping(bytes32 => uint256) public gap; // 抵押品缺口 [wad]
    mapping(bytes32 => uint256) public Art; // 各抵押品总债务 [wad]
    mapping(bytes32 => uint256) public fix; // 最终现金价格 [ray]

    mapping(address => uint256) public bag; // 用户打包的Dai数量 [wad]
    mapping(bytes32 => mapping(address => uint256)) public out; // 用户可提取的抵押品 [wad]

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);

    event Cage();
    event Cage(bytes32 indexed ilk);
    event Snip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skip(bytes32 indexed ilk, uint256 indexed id, address indexed usr, uint256 tab, uint256 lot, uint256 art);
    event Skim(bytes32 indexed ilk, address indexed urn, uint256 wad, uint256 art);
    event Free(bytes32 indexed ilk, address indexed usr, uint256 ink);
    event Thaw();
    event Flow(bytes32 indexed ilk);
    event Pack(address indexed usr, uint256 wad);
    event Cash(bytes32 indexed ilk, address indexed usr, uint256 wad);
}

interface VatLike {
    function dai(address) external view returns (uint256);
    function ilks(bytes32 ilk)
        external
        returns (
            uint256 Art, // [wad]
            uint256 rate, // [ray]
            uint256 spot, // [ray]
            uint256 line, // [rad]
            uint256 dust
        ); // [rad]

    function urns(bytes32 ilk, address urn)
        external
        returns (
            uint256 ink, // [wad]
            uint256 art
        ); // [wad]

    function debt() external returns (uint256);
    function move(address src, address dst, uint256 rad) external;
    function hope(address) external;
    function flux(bytes32 ilk, address src, address dst, uint256 rad) external;
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external;
    function suck(address u, address v, uint256 rad) external;
    function cage() external;
}

interface CatLike {
    function ilks(bytes32)
        external
        returns (
            address flip,
            uint256 chop, // [ray]
            uint256 lump
        ); // [rad]

    function cage() external;
}

interface DogLike {
    function ilks(bytes32) external returns (address clip, uint256 chop, uint256 hole, uint256 dirt);
    function cage() external;
}

interface PotLike {
    function cage() external;
}

interface VowLike {
    function cage() external;
}

interface FlipLike {
    function bids(uint256 id)
        external
        view
        returns (
            uint256 bid, // [rad]
            uint256 lot, // [wad]
            address guy,
            uint48 tic, // [unix epoch time]
            uint48 end, // [unix epoch time]
            address usr,
            address gal,
            uint256 tab
        ); // [rad]

    function yank(uint256 id) external;
}

interface ClipLike {
    function sales(uint256 id)
        external
        view
        returns (uint256 pos, uint256 tab, uint256 lot, address usr, uint96 tic, uint256 top);
    function yank(uint256 id) external;
}

interface PipLike {
    function read() external view returns (bytes32);
}

interface SpotLike {
    function par() external view returns (uint256);
    function ilks(bytes32) external view returns (PipLike pip, uint256 mat); // [ray]

    function cage() external;
}

interface CureLike {
    function tell() external view returns (uint256);
    function cage() external;
}
