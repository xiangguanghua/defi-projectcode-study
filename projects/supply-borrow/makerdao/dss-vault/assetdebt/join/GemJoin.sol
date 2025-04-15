// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./JoinStorage.sol";
import {Auth} from "../../utils/Auth.sol";

/**
 * 资产合约
 */
contract GemJoin is JoinStorage, Auth {
    /**
     * 初始化函数
     * @param vat_ 金库合约地址
     * @param ilk_ 抵押品类型
     * @param gem_ 抵押品代币合约地址
     */
    constructor(address vat_, bytes32 ilk_, address gem_) {
        wards[msg.sender] = 1;
        live = 1;

        vat = VatLike(vat_);
        ilk = ilk_;

        gem = GemLike(gem_);
        dec = gem.decimals();
    }

    /**
     * 存入抵押品
     * @param usr 记账用户地址
     * @param wad 存入数量
     */
    function join(address usr, uint256 wad) external {
        require(live == 1, "GemJoin/not-live");
        require(int256(wad) >= 0, "GemJoin/overflow");
        // 增加usr抵押品余额
        vat.slip(ilk, usr, int256(wad));
        // 将msg.sender的抵押品转给address(this)
        bool success = gem.transferFrom(msg.sender, address(this), wad);
        require(success, "GemJoin/failed-transfer");
        emit Join(usr, wad);
    }

    /**
     * 取出抵押品
     * @param usr 记账用户地址
     * @param wad 抵押品数量
     */
    function exit(address usr, uint256 wad) external {
        require(wad <= 2 ** 255, "GemJoin/overflow");
        // 减少抵押品余额
        vat.slip(ilk, usr, -int256(wad));
        // 将address(this)合约中的抵押品还给用户erc20合约
        bool success = gem.transfer(usr, wad);
        require(success, "GemJoin/failed-transfer");
    }
}
