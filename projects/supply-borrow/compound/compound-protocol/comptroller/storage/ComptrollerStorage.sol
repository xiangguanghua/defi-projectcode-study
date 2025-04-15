// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../../ctoken/implementation/CToken.sol";
import "../../utils/price/PriceOracle.sol";
import "./UnitrollerAdminStorage.sol";

contract ComptrollerV1Storage is UnitrollerAdminStorage {
    PriceOracle public oracle;
    uint256 public closeFactorMantissa;
    uint256 public liquidationIncentiveMantissa;
    uint256 public maxAssets;
    mapping(address => CToken[]) public accountAssets;
}

contract ComptrollerV2Storage is ComptrollerV1Storage {
    struct Market {
        bool isListed;
        uint256 collateralFactorMantissa;
        mapping(address => bool) accountMembership;
        bool isComped;
    }

    mapping(address => Market) public markets;
    address public pauseGuardian;
    bool public _mintGuardianPaused;
    bool public _borrowGuardianPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
    struct CompMarketState {
        uint224 index;
        uint32 block;
    }

    CToken[] public allMarkets;
    uint256 public compRate;
    mapping(address => uint256) public compSpeeds;
    mapping(address => CompMarketState) public compSupplyState;
    mapping(address => CompMarketState) public compBorrowState;
    mapping(address => mapping(address => uint256)) public compSupplierIndex;
    mapping(address => mapping(address => uint256)) public compBorrowerIndex;
    mapping(address => uint256) public compAccrued;
}

contract ComptrollerV4Storage is ComptrollerV3Storage {
    address public borrowCapGuardian;
    mapping(address => uint256) public borrowCaps;
}

contract ComptrollerV5Storage is ComptrollerV4Storage {
    mapping(address => uint256) public compContributorSpeeds;
    mapping(address => uint256) public lastContributorBlock;
}

contract ComptrollerV6Storage is ComptrollerV5Storage {
    mapping(address => uint256) public compBorrowSpeeds;
    mapping(address => uint256) public compSupplySpeeds;
}

contract ComptrollerV7Storage is ComptrollerV6Storage {
    bool public proposal65FixExecuted;
    mapping(address => uint256) public compReceivable;
}
