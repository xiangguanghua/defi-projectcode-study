// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IPool.sol";

interface IActivePool is IPool {
    // --- Events ---
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolLUSDDebtUpdated(uint256 _LUSDDebt);
    event ActivePoolETHBalanceUpdated(uint256 _ETH);

    // --- Functions ---
    function sendETH(address _account, uint256 _amount) external;
}
