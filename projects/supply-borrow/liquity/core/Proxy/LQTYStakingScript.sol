// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "../dependencies/CheckContract.sol";
import "../interfaces/ILQTYStaking.sol";

contract LQTYStakingScript is CheckContract {
    ILQTYStaking immutable LQTYStaking;

    constructor(address _lqtyStakingAddress) {
        checkContract(_lqtyStakingAddress);
        LQTYStaking = ILQTYStaking(_lqtyStakingAddress);
    }

    function stake(uint256 _LQTYamount) external {
        LQTYStaking.stake(_LQTYamount);
    }
}
