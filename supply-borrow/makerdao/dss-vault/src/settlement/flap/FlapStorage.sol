// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface VatLike {
    function move(address, address, uint256) external;
}

interface GemLike {
    function move(address, address, uint256) external;
    function burn(address, uint256) external;
}

contract FlapStorage {
    // --- Data ---
    struct Bid {
        uint256 bid; // gems paid               [wad]
        uint256 lot; // dai in return for bid   [rad]
        address guy; // high bidder
        uint48 tic; // bid expiry time         [unix epoch time]
        uint48 end; // auction expiry time     [unix epoch time]
    }

    mapping(uint256 => Bid) public bids;

    VatLike public vat; // CDP Engine
    GemLike public gem;

    uint256 constant ONE = 1.0e18;
    uint256 public beg = 1.05e18; // 5% minimum bid increase
    uint48 public ttl = 3 hours; // 3 hours bid duration         [seconds]
    uint48 public tau = 2 days; // 2 days total auction length  [seconds]
    uint256 public kicks = 0;
    uint256 public lid; // max dai to be in auction at one time  [rad]
    uint256 public fill; // current dai in auction                [rad]

    // --- Events ---
    event Kick(uint256 id, uint256 lot, uint256 bid);
}
