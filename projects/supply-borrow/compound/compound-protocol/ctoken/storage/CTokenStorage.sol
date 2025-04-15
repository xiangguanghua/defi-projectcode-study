// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../../comptroller/interfaces/ComptrollerInterface.sol";
import "../../interestRateModel/interfaces/InterestRateModel.sol";

contract CTokenStorage {
    bool internal _notEntered;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 internal constant borrowRateMaxMantissa = 0.0005e16;
    uint256 internal constant reserveFactorMaxMantissa = 1e18;
    address payable public admin;
    address payable public pendingAdmin;
    ComptrollerInterface public comptroller;
    InterestRateModel public interestRateModel;
    uint256 internal initialExchangeRateMantissa;
    uint256 public reserveFactorMantissa;
    uint256 public accrualBlockNumber;
    uint256 public borrowIndex;
    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public totalSupply;
    mapping(address => uint256) internal accountTokens;
    mapping(address => mapping(address => uint256)) internal transferAllowances;

    struct BorrowSnapshot {
        uint256 principal;
        uint256 interestIndex;
    }

    mapping(address => BorrowSnapshot) internal accountBorrows;
    uint256 public constant protocolSeizeShareMantissa = 2.8e16; //2.8%
}
