// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "../dependencies/CheckContract.sol";
import "../interfaces/IStabilityPool.sol";

contract StabilityPoolScript is CheckContract {
    string public constant NAME = "StabilityPoolScript";

    IStabilityPool immutable stabilityPool;

    constructor(IStabilityPool _stabilityPool) {
        checkContract(address(_stabilityPool));
        stabilityPool = _stabilityPool;
    }

    function provideToSP(uint256 _amount, address _frontEndTag) external {
        stabilityPool.provideToSP(_amount, _frontEndTag);
    }

    function withdrawFromSP(uint256 _amount) external {
        stabilityPool.withdrawFromSP(_amount);
    }

    function withdrawETHGainToTrove(address _upperHint, address _lowerHint) external {
        stabilityPool.withdrawETHGainToTrove(_upperHint, _lowerHint);
    }
}
