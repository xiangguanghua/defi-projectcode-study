// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.12;

import "./Abacus.sol";
import "../../utils/Auth.sol";
import "../../utils/Math.sol";

contract StairstepExponentialDecrease is Abacus, Auth {
    // --- Data ---
    uint256 public step; // Length of time between price drops [seconds]
    uint256 public cut; // Per-step multiplicative factor     [ray]
    uint256 constant RAY = 10 ** 27;

    // --- Init ---
    // @notice: `cut` and `step` values must be correctly set for
    //     this contract to return a valid price
    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // top: initial price
    // dur: seconds since the auction has started
    // step: seconds between a price drop
    // cut: cut encodes the percentage to decrease per step.
    //   For efficiency, the values is set as (1 - (% value / 100)) * RAY
    //   So, for a 1% decrease per step, cut would be (1 - 0.01) * RAY
    //
    // returns: top * (cut ^ dur)
    function price(uint256 top, uint256 dur) external view override returns (uint256) {
        return Math.dmul(top, Math.abaci_rpow(cut, dur / step, RAY), RAY);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "cut") require((cut = data) <= RAY, "StairstepExponentialDecrease/cut-gt-RAY");
        else if (what == "step") step = data;
        else revert("StairstepExponentialDecrease/file-unrecognized-param");
        emit File(what, data);
    }
}
