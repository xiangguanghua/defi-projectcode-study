// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./JugStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

/**
 * 管理稳定费率（Stability Fee），计算债务利息
 */
contract Jug is JogStorage, Auth {
    constructor(address vat_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
    }

    /**
     * 计算新的rate
     * @param ilk 抵押资产
     */
    function drip(bytes32 ilk) external returns (uint256 rate) {
        require(block.timestamp >= ilks[ilk].rho, "Jug/invalid-now");
        // 获取账本当前的费率
        (, uint256 prev) = vat.ilks(ilk);
        // 计算当前费率（复利增长） 数学表达：rate = prev × (base + duty)^Δt
        // add(base, ilks[ilk].duty) :组合基础费率与抵押品特定费率
        // block.timestamp - ilks[ilk].rho : 计算自上次更新以来的秒数 Δt
        // rpow(..., ..., ONE): 计算复合增长因子：(base + duty)^Δt , ONE 是精度基数 10^27 (RAY)，其中（1 + r）^ Δt
        // rmul(..., prev): 将增长因子与之前累积率相乘
        rate = Math.dmul(Math.rpow(Math.add(base, ilks[ilk].duty), block.timestamp - ilks[ilk].rho, ONE), prev, ONE);
        // 更新债务记录
        // ilk：抵押资产
        // vow：系统盈余/赤字缓冲池
        // diff：费用差值
        vat.fold(ilk, vow, Math.diff(rate, prev));
        ilks[ilk].rho = block.timestamp;
    }

    /**
     * 当新增一种抵押品类型（如 USDC-C）时，治理提案通过后调用此方法初始化
     * 初始化费率参数
     * @param ilk 抵押品
     */
    function init(bytes32 ilk) external auth {
        Ilk storage i = ilks[ilk];
        require(i.duty == 0, "Jug/ilk-already-init"); // 确保未初始化
        i.duty = ONE; // 设置默认费率 (1 RAY = 0%初始费率)
        i.rho = block.timestamp; // 记录初始化时间戳
    }

    /**
     * 抵押品特定参数调整，修改的是jug合约的参数
     * @param ilk 抵押资产
     * @param what 调整的参数名称
     * @param data 调整数值
     */
    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(block.timestamp == ilks[ilk].rho, "Jug/rho-not-updated");
        if (what == "duty") ilks[ilk].duty = data;
        else revert("Jug/file-unrecognized-param");
    }

    /**
     * 修改jug合约中base费率的值
     * @param what 修改参数名称
     * @param data 修改值
     */
    function file(bytes32 what, uint256 data) external auth {
        if (what == "base") base = data;
        else revert("Jug/file-unrecognized-param");
    }

    /**
     * 修改jug合约中vow的地址
     * @param what 修改的参数
     * @param data 修改的值
     */
    function file(bytes32 what, address data) external auth {
        if (what == "vow") vow = data;
        else revert("Jug/file-unrecognized-param");
    }
}
