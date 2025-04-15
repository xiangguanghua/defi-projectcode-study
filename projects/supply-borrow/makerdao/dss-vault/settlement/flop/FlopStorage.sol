// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface VatLike {
    function move(address, address, uint256) external;
    function suck(address, address, uint256) external;
}

interface GemLike {
    function mint(address, uint256) external;
}

interface VowLike {
    function Ash() external returns (uint256);
    function kiss(uint256) external;
}

contract FlopStorage {
    // --- Data ---
    struct Bid {
        uint256 bid; // dai paid                [rad]
        uint256 lot; // gems in return for bid  [wad]
        address guy; // high bidder
        uint48 tic; // bid expiry time         [unix epoch time]
        uint48 end; // auction expiry time     [unix epoch time]
    }

    mapping(uint256 => Bid) public bids;

    VatLike public vat; // CDP Engine
    GemLike public gem;

    uint256 constant ONE = 1.0e18;
    uint256 public beg = 1.05e18; // 5% minimum bid increase
    uint256 public pad = 1.5e18; // 50% lot increase for tick
    uint48 public ttl = 3 hours; // 3 hours bid lifetime         [seconds]
    uint48 public tau = 2 days; // 2 days total auction length  [seconds]
    uint256 public kicks = 0;
    address public vow; // not used until shutdown

    // --- Events ---
    event Kick(uint256 id, uint256 lot, uint256 bid, address indexed gal);
}
