// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./SpotStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

contract Spot is SpotStorage, Auth {
    constructor(address vat_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        par = ONE;
        live = 1;
    }

    /**
     * 将预言机提供的原始价格转换为系统可用的"spot"价格（即经过风险参数调整后的有效价格）
     * @param ilk 抵押资产
     */
    function poke(bytes32 ilk) external {
        /**
         * ​**ilks[ilk].pip**​：该抵押品类型对应的预言机合约（Price Feed）
         * ​**peek()**​：调用预言机获取最新价格
         * 返回：
         * val：原始价格数据（通常为整数形式的报价）
         * has：布尔值，表示价格是否有效
         */
        (bytes32 val, bool has) = ilks[ilk].pip.peek();
        /**
         * (1) 基础单位调整
         *    mul(uint(val), 10 ​**​ 9)
         *    将原始价格 val 乘以 10^9
         *    ​目的​：统一单位精度（例如将 ETH/USD 价格从 2000 变为 2000000000000）
         * (2) 第一次除法 - 除以 par
         *     rdiv(..., par)
         *     par：Dai 的目标价格（通常为 1 USD，存储为 RAY 精度 10^27）
         *     ​作用​：将报价从 "抵押品/报价币" 转换为 "抵押品/Dai"
         *     例如 ETH/USD → ETH/DAI（当 Dai 锚定 1 USD 时数值不变）
         * (3) 第二次除法 - 除以 mat
         *     rdiv(..., ilks[ilk].mat)
         *     mat：该抵押品的清算比率（如 150% 存储为 1.5 * 10^27）
         * ​    作用​：应用风险参数折扣
         *     例如 ETH 市价 2000，mat=1.5→有效价=2000/1.5 ≈ $1333.33
         *     这是系统实际用于计算抵押价值的"保守价格"
         * (4) 错误处理
         *     如果预言机价格无效（has == false），设置 spot 为 0
         *     这将导致 Vat 合约拒绝相关抵押操作
         */
        uint256 spot = has ? Math.ddiv(Math.ddiv(Math.mul(uint256(val), 10 ** 9), par, ONE), ilks[ilk].mat, ONE) : 0;
        /**
         * 调用核心合约 Vat 的 file 方法
         * 更新该抵押品类型的 spot 价格字段
         */
        vat.file(ilk, "spot", spot);
        emit Poke(ilk, val, spot);
    }

    // --- Administration ---
    function file(bytes32 ilk, bytes32 what, address pip_) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "pip") ilks[ilk].pip = PipLike(pip_);
        else revert("Spotter/file-unrecognized-param");
    }

    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "par") par = data;
        else revert("Spotter/file-unrecognized-param");
    }

    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(live == 1, "Spotter/not-live");
        if (what == "mat") ilks[ilk].mat = data;
        else revert("Spotter/file-unrecognized-param");
    }
}
