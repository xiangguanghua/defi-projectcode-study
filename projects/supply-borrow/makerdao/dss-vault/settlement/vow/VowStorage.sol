// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface FlopLike {
    function kick(address gal, uint256 lot, uint256 bid) external returns (uint256);
    function cage() external;
    function live() external returns (uint256);
}

interface FlapLike {
    function kick(uint256 lot, uint256 bid) external returns (uint256);
    function cage(uint256) external;
    function live() external returns (uint256);
}

interface VatLike {
    function dai(address) external view returns (uint256);
    function sin(address) external view returns (uint256);
    function heal(uint256) external;
    function hope(address) external;
    function nope(address) external;
}

contract VowStorage {
    // --- Data ---
    VatLike public vat; // CDP Engine
    FlapLike public flapper; // Surplus Auction House
    FlopLike public flopper; // Debt Auction House

    mapping(uint256 => uint256) public sin; // debt queue
    uint256 public Sin; // Queued debt            [rad]
    uint256 public Ash; // On-auction debt        [rad]

    uint256 public wait; // Flop delay             [seconds]
    uint256 public dump; // Flop initial lot size  [wad]
    uint256 public sump; // Flop fixed bid size    [rad]

    uint256 public bump; // Flap fixed lot size    [rad]
    uint256 public hump; // Surplus buffer         [rad]
}
