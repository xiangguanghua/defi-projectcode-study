// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

contract UnitrollerAdminStorage {
    address public admin;
    address public pendingAdmin;
    address public comptrollerImplementation;
    address public pendingComptrollerImplementation;
}
