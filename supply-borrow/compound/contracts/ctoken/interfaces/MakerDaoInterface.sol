// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

/**
 * Maker Interfaces **
 */
interface PotLike {
    function chi() external view returns (uint256);
    function pie(address) external view returns (uint256);
    function drip() external returns (uint256);
    function join(uint256) external;
    function exit(uint256) external;
}

interface GemLike {
    function approve(address, uint256) external;
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface VatLike {
    function dai(address) external view returns (uint256);
    function hope(address) external;
}

interface DaiJoinLike {
    function vat() external returns (VatLike);
    function dai() external returns (GemLike);
    function join(address, uint256) external payable;
    function exit(address, uint256) external;
}
