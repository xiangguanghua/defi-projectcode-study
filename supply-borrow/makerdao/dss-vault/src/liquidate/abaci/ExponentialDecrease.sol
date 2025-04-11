// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.12;

import "./Abacus.sol";
import "../../utils/Auth.sol";
import "../../utils/Math.sol";

contract ExponentialDecrease is Abacus, Auth {
    // --- Data ---
    uint256 public cut; // Per-second multiplicative factor [ray]
    uint256 constant RAY = 10 ** 27;

    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // top: initial price
    // dur: seconds since the auction has started
    // cut: cut encodes the percentage to decrease per second.
    //   For efficiency, the values is set as (1 - (% value / 100)) * RAY
    //   So, for a 1% decrease per second, cut would be (1 - 0.01) * RAY
    //
    // returns: top * (cut ^ dur)
    function price(uint256 top, uint256 dur) external view override returns (uint256) {
        return Math.dmul(top, Math.abaci_rpow(cut, dur, RAY), RAY);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "cut") require((cut = data) <= RAY, "ExponentialDecrease/cut-gt-RAY");
        else revert("ExponentialDecrease/file-unrecognized-param");
        emit File(what, data);
    }
}
