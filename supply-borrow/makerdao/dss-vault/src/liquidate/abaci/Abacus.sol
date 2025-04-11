// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.12;

interface Abacus {
    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);

    event File(bytes32 indexed what, uint256 data);

    function price(uint256, uint256) external view returns (uint256);
}
