// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract CheckContract {
    function checkContract(address _account) internal view {
        require(_account != address(0), "Account cannot be zero address");
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(_account)
        }
        require(size > 0, "Account code size cannot be zero");
    }
}
