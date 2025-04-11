// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./VatStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

/**
 * 核心会计账本
 * 记录所有抵押品、债务和用户余额（ink, art, dai）
 */
contract Vat is VatStorage, Auth {
    constructor() {
        wards[msg.sender] = 1; // 给管理员添加权限
        live = 1; // 激活
    }

    /**
     * 调整用户未锁定抵押品余额
     * @param ilk 抵押品类型
     * @param src 减少对象
     * @param dst 增加对象
     * @param wad 调整数量
     */
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        gem[ilk][src] = Math._sub(gem[ilk][src], wad);
        gem[ilk][dst] = Math._add(gem[ilk][dst], wad);
    }

    /**
     * 调整内部dai的数量
     * @param src 减少dai对象
     * @param dst 增加dai对象
     * @param rad 调整数量
     */
    function move(address src, address dst, uint256 rad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        dai[src] = Math._sub(dai[src], rad);
        dai[dst] = Math._add(dai[dst], rad);
    }

    /**
     * 抵押资产借出Dai
     * @param i 抵押品类型
     * @param u 操作用户
     * @param v 债务接收者
     * @param w Dai接收者
     * @param dink 增加抵押品 (dink)
     * @param dart 增加债务 (dart)
     */
    function frob(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external {
        require(live == 1, "Vat/not-live");

        Urn memory urn = urns[i][u];
        Ilk memory ilk = ilks[i];
        require(ilk.rate != 0, "Vat/ilk-not-init");

        urn.ink = Math._add(urn.ink, dink);
        urn.art = Math._add(urn.art, dart);
        ilk.Art = Math._add(ilk.Art, dart);

        int256 dtab = Math._mul(ilk.rate, dart);
        uint256 tab = Math._mul(ilk.rate, urn.art);
        debt = Math._add(debt, dtab);

        // either debt has decreased, or debt ceilings are not exceeded
        require(
            Math.either(dart <= 0, Math.both(Math._mul(ilk.Art, ilk.rate) <= ilk.line, debt <= Line)),
            "Vat/ceiling-exceeded"
        );
        // urn is either less risky than before, or it is safe
        require(Math.either(Math.both(dart <= 0, dink >= 0), tab <= Math._mul(urn.ink, ilk.spot)), "Vat/not-safe");

        // urn is either more safe, or the owner consents
        require(Math.either(Math.both(dart <= 0, dink >= 0), wish(u, msg.sender)), "Vat/not-allowed-u");
        // collateral src consents
        require(Math.either(dink <= 0, wish(v, msg.sender)), "Vat/not-allowed-v");
        // debt dst consents
        require(Math.either(dart >= 0, wish(w, msg.sender)), "Vat/not-allowed-w");

        // urn has no debt, or a non-dusty amount
        require(Math.either(urn.art == 0, tab >= ilk.dust), "Vat/dust");

        gem[i][v] = Math._sub(gem[i][v], dink);
        dai[w] = Math._add(dai[w], dtab);

        urns[i][u] = urn;
        ilks[i] = ilk;
    }

    /**
     * 用于拆分或合并抵押仓位，如将高风险仓位部分转移给清算人
     * @param ilk 抵押品类型标识（如"ETH-A"）
     * @param src 源仓位地址
     * @param dst 目标仓位地址
     * @param dink 转移的抵押品数量（可正可负）
     * @param dart 转移的债务数量（可正可负）
     */
    function fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) external {
        Urn storage u = urns[ilk][src];
        Urn storage v = urns[ilk][dst];
        Ilk storage i = ilks[ilk];

        u.ink = Math._sub(u.ink, dink);
        u.art = Math._sub(u.art, dart);
        v.ink = Math._add(v.ink, dink);
        v.art = Math._add(v.art, dart);

        uint256 utab = Math._mul(u.art, i.rate);
        uint256 vtab = Math._mul(v.art, i.rate);

        // both sides consent
        require(Math.both(wish(src, msg.sender), wish(dst, msg.sender)), "Vat/not-allowed");

        // both sides safe
        require(utab <= Math._mul(u.ink, i.spot), "Vat/not-safe-src");
        require(vtab <= Math._mul(v.ink, i.spot), "Vat/not-safe-dst");

        // both sides non-dusty
        require(Math.either(utab >= i.dust, u.art == 0), "Vat/dust-src");
        require(Math.either(vtab >= i.dust, v.art == 0), "Vat/dust-dst");
    }

    /**
     * 用于清算处理
     * @param i 抵押品类型（如"ETH-A"）
     * @param u 被清算的仓位地址
     * @param v 抵押品接收地址
     * @param w 坏账承担地址
     * @param dink 转移的抵押品数量（通常为负）
     * @param dart 转移的债务数量（通常为负）
     */
    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external auth {
        Urn storage urn = urns[i][u];
        Ilk storage ilk = ilks[i];

        urn.ink = Math._add(urn.ink, dink);
        urn.art = Math._add(urn.art, dart);
        ilk.Art = Math._add(ilk.Art, dart);

        int256 dtab = Math._mul(ilk.rate, dart);

        gem[i][v] = Math._sub(gem[i][v], dink);
        sin[w] = Math._sub(sin[w], dtab);
        vice = Math._sub(vice, dtab);
    }

    /**
     * 债务核销机制
     * 允许用户使用自己的 Dai 信用余额来核销系统坏账，是协议自我修复的核心机制。
     * @param rad 用户Dai信用核销数量
     */
    function heal(uint256 rad) external {
        address u = msg.sender;
        sin[u] = Math._sub(sin[u], rad);
        dai[u] = Math._sub(dai[u], rad);
        vice = Math._sub(vice, rad);
        debt = Math._sub(debt, rad);
    }

    /**
     * 系统债务创造
     * 治理特权函数，用于在紧急情况下创造系统债务（如应对黑天鹅事件）
     * @param u 坏账记录地址
     * @param v 信用dai记录地址
     * @param rad 数量
     */
    function suck(address u, address v, uint256 rad) external auth {
        sin[u] = Math._add(sin[u], rad);
        dai[v] = Math._add(dai[v], rad);
        vice = Math._add(vice, rad);
        debt = Math._add(debt, rad);
    }

    /**
     * 利率调整引擎
     * @param i 抵押品类型
     * @param u 用户地址
     * @param rate 利率
     */
    function fold(bytes32 i, address u, int256 rate) external auth {
        require(live == 1, "Vat/not-live");
        Ilk storage ilk = ilks[i];
        ilk.rate = Math._add(ilk.rate, rate);
        int256 rad = Math._mul(ilk.Art, rate);
        dai[u] = Math._add(dai[u], rad);
        debt = Math._add(debt, rad);
    }

    /*///////////////////////////////////////////////////////////////////
                              管理员操作
    ////////////////////////////////////////////////////////////////// */
    /**
     * 初始化抵押物rate
     * @param ilk 抵押品类型标识符（如 "ETH-A" 的bytes32编码）
     * @notice 10**27：1 RAY（Maker系统的利率计算单位，27位小数精度）
     */
    function init(bytes32 ilk) external auth {
        require(ilks[ilk].rate == 0, "Vat/ilk-already-init");
        ilks[ilk].rate = 10 ** 27;
    }

    /**
     * 用于修改系统级参数的关键方法
     * @param what 仅支持修改Line参数
     * @param data 修改的值
     * @dev 受 live 状态限制（系统关闭时不可修改）
     */
    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "Line") Line = data;
        else revert("Vat/file-unrecognized-param");
    }

    /**
     * 用于调整单个抵押品类型(ilk)参数的关键方法，与全局参数修改的 file 函数形成互补设计
     * @param ilk spot: 价格×清算比例（风险参数）
     *            line: 该抵押品的独立债务上限
     *            dust: 最小债务额度（防粉尘攻击）
     * @param what 修改的参数
     * @param data 数据
     */
    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "spot") ilks[ilk].spot = data;
        else if (what == "line") ilks[ilk].line = data;
        else if (what == "dust") ilks[ilk].dust = data;
        else revert("Vat/file-unrecognized-param");
    }

    /**
     * 增加用户未锁定抵押品余额
     * @param ilk 抵押品类型
     * @param usr 用户
     * @param wad 增加数量
     */
    function slip(bytes32 ilk, address usr, int256 wad) external auth {
        gem[ilk][usr] = Math._add(gem[ilk][usr], wad);
    }

    /*///////////////////////////////////////////////////////////////////
                              代理操作
    ////////////////////////////////////////////////////////////////// */
    // 授权 usr 操作 msg.sender在vat中的资产
    function hope(address usr) external {
        can[msg.sender][usr] = 1;
    }

    //取消授权 usr 操作 msg.sender在vat中的资产
    function nope(address usr) external {
        can[msg.sender][usr] = 0;
    }

    // 用于检查bit是否授权了usr地址操作其资产的权限
    function wish(address bit, address usr) internal view returns (bool) {
        return Math.either(bit == usr, can[bit][usr] == 1);
    }
}
