// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.12;

import "./Abacus.sol";
import "../../utils/Auth.sol";
import "../../utils/Math.sol";

contract LinearDecrease is Abacus, Auth {
    // --- Data ---
    uint256 public tau; // Seconds after auction start when the price reaches zero [seconds]

    uint256 constant RAY = 10 ** 27;

    // --- Init ---
    constructor() {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // Price calculation when price is decreased linearly in proportion to time:
    // tau: The number of seconds after the start of the auction where the price will hit 0
    // top: Initial price
    // dur: current seconds since the start of the auction
    //
    // Returns y = top * ((tau - dur) / tau)
    //
    // Note the internal call to mul multiples by RAY, thereby ensuring that the rmul calculation
    // which utilizes top and tau (RAY values) is also a RAY value.
    function price(uint256 top, uint256 dur) external view override returns (uint256) {
        if (dur >= tau) return 0;
        return Math.dmul(top, Math.mul(tau - dur, RAY) / tau, RAY);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "tau") tau = data;
        else revert("LinearDecrease/file-unrecognized-param");
        emit File(what, data);
    }
}
