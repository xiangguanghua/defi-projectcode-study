// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface GemLike {
    function decimals() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface DSTokenLike {
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

interface VatLike {
    function slip(bytes32, address, int256) external;
    function move(address, address, uint256) external;
}

contract JoinStorage {
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Join(address indexed usr, uint256 wad);
    event Exit(address indexed usr, uint256 wad);
    event Cage();

    uint256 constant ONE = 10 ** 27;

    VatLike public vat;
    bytes32 public ilk;
    GemLike public gem;
    uint256 public dec;

    DSTokenLike public dai;
}
