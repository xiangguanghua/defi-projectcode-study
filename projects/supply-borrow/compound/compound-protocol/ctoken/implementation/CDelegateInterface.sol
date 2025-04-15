// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../storage/CDelegationStorage.sol";

abstract contract CDelegateInterface is CDelegationStorage {
    /// @param data 参与方法标准接口定义
    function _becomeImplementation(bytes memory data) external virtual;
    /// @notice 退出方法标准接口定义
    function _resignImplementation() external virtual;
}
