// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./BaseAdminUpgradeabilityProxy.sol";

contract AdminUpgradeabilityProxy is BaseAdminUpgradeabilityProxy, UpgradeabilityProxy {
    constructor(address _logic, address _admin, bytes memory _data) payable UpgradeabilityProxy(_logic, _data) {
        assert(ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        _setAdmin(_admin);
    }

    function _willFallback() internal override(BaseAdminUpgradeabilityProxy, Proxy) {
        BaseAdminUpgradeabilityProxy._willFallback();
    }
}
