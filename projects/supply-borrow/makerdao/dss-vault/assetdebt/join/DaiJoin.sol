// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";
import "./JoinStorage.sol";

/**
 * 负债合约
 */
contract DaiJoin is JoinStorage, Auth {
    /**
     * 初始化函数
     * @param vat_ 金库合约地址
     * @param dai_ 抵押品代币合约地址
     */
    constructor(address vat_, address dai_) {
        wards[msg.sender] = 1;
        live = 1;
        vat = VatLike(vat_);
        dai = DSTokenLike(dai_);
    }

    /**
     * 将erc20 dai转化为 内部dai
     * @param usr 用户地址
     * @param wad 数量
     */
    function join(address usr, uint256 wad) external {
        // 将抵押品从合约转移到用户地址 (Vat 内部记账)
        vat.move(address(this), usr, Math.mul(ONE, wad));
        // 销毁用户的 DAI (ERC-20 销毁)
        dai.burn(msg.sender, wad);
        emit Join(usr, wad);
    }

    /**
     * 将内部dai 转化为erc20 dai
     * @param usr 用户地址
     * @param wad 数量
     */
    function exit(address usr, uint256 wad) external {
        require(live == 1, "DaiJoin/not-live");
        vat.move(msg.sender, address(this), Math.mul(ONE, wad));
        dai.mint(usr, wad);

        emit Exit(usr, wad);
    }
}
