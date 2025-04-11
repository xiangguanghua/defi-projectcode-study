// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface VatLike {
    function ilks(bytes32) external returns (uint256 Art, uint256 rate);
    function fold(bytes32, address, int256) external;
}

contract JogStorage {
    // 存储每种抵押品类型的费率信息
    struct Ilk {
        uint256 duty; // 该抵押品类型的稳定费率（每秒利率，以 ray 为单位，1 ray = 10^27）
        uint256 rho; // 上次更新费率的时间戳
    }

    // 抵押物的费率信息
    mapping(bytes32 => Ilk) public ilks;

    uint256 public base; // 基础费率，所有抵押品类型的费率在此基础上增加

    VatLike public vat; // 核心会计合约地址
    address public vow; // 系统盈余/赤字合约地址，稳定费收入流向此处

    uint256 constant ONE = 10 ** 27;
}
