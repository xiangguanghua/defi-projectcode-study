// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

interface GovernorAlpha {
    /// @notice The total number of proposals
    function proposalCount() external returns (uint256);
}
