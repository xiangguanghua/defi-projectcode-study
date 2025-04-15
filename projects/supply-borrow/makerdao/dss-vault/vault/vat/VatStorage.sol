// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

contract VatStorage {
    //系统总债务 = 正常债务 + 清算债务
    //debt = vice + sum(ilks[*].Art * ilks[*].rate)
    uint256 public debt; // Total Dai Issued    [rad]
    //系统总清算债务(来自sin)
    // vice = sum(sin[all addresses])
    uint256 public vice; // Total Unbacked Dai  [rad]
    //系统所有抵押品类型的总债务上限
    // sum(ilks[*].line) <= Line
    uint256 public Line; // Total Debt Ceiling  [rad]

    /**
     * @notice ​含义: 代理授权系统，允许地址A授权地址B代表其操作
     */
    mapping(address => mapping(address => uint256)) public can;
    // 抵押品数据类型
    // mapping(抵押物名称 = > 抵押物详情)
    mapping(bytes32 => Ilk) public ilks;

    // 用于存储和管理 ​每种抵押品类型的风险参数和状态数据
    // 定义某一类抵押品​（如 ETH-A）的全局参数（利率、债务上限、清算阈值等）
    struct Ilk {
        uint256 Art; // 系统中该抵押品未偿还的 DAI 债务总量（随时间增长）（单位: Rad，1 Rad = 10^45 DAI） 100,000 Rad
        uint256 rate; // 利率累积乘数（从创建开始累计的复利）1.05 Ray（表示5%利率）
        uint256 spot; // 抵押品价格与债务的安全比率（由预言机更新）1.5 Ray（150%抵押率）
        uint256 line; // 该抵押品类型的全局债务上限，超过则禁止新增借贷   500,000,000 Rad
        uint256 dust; // 最小债务额度，低于此值的 CDP 会被强制清算（防垃圾头寸） 100 Rad（≈100 DAI）
    }

    //用户仓位数据
    // mapping(抵押物名称 => mapping(用户 => 仓位))
    mapping(bytes32 => mapping(address => Urn)) public urns;

    // 记录单个用户在某一抵押品类型下的抵押物数量（ink）和原始债务（art）
    // 抵押率 = (ink × 抵押品价格) / (art × 债务利率 × 债务单价)
    struct Urn {
        uint256 ink; // 用户锁定在该抵押品类型中的抵押品数量  [wad]
        uint256 art; // 用户在该抵押品类型下生成的债务数量(未乘以rate)    [wad]
    }

    // 未锁定抵押品
    // mapping(抵押物名称 => mapping(用户 = > 未锁定数量))
    mapping(bytes32 => mapping(address => uint256)) public gem; // [wad]
    //用户实际债务(尚未通过exit提取到ERC20 Dai)
    mapping(address => uint256) public dai; // [rad]
    //系统债务记录(主要是清算产生的坏账)
    mapping(address => uint256) public sin; // [rad]
}
