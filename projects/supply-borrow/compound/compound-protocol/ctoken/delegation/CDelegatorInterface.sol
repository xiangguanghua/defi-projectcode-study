// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../storage/CDelegationStorage.sol";

abstract contract CDelegatorInterface is CDelegationStorage {
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * 定义逻辑合约的地址和初始化参数标准方法
     * @param implementation_ 新实现合约的地址
     * @param allowResign 是否允许旧实现合约"辞职"（执行清理操作）
     * @param becomeImplementationData 传递给新实现合约的初始化数据
     */
    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData)
        external
        virtual;
}
