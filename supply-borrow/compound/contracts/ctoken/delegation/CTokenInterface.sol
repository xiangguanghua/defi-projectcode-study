// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "../storage/CTokenStorage.sol";

abstract contract CTokenInterface is CTokenStorage {
    bool public constant isCToken = true;

    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event RepayBorrow(
        address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
    );
    event LiquidateBorrow(
        address liquidator, address borrower, uint256 repayAmount, address cTokenCollateral, uint256 seizeTokens
    );
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
    event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);
    event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function transfer(address dst, uint256 amount) external virtual returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external virtual returns (bool);
    function approve(address spender, uint256 amount) external virtual returns (bool);
    function allowance(address owner, address spender) external view virtual returns (uint256);
    function balanceOf(address owner) external view virtual returns (uint256);
    function balanceOfUnderlying(address owner) external virtual returns (uint256);
    function getAccountSnapshot(address account) external view virtual returns (uint256, uint256, uint256, uint256);
    function borrowRatePerBlock() external view virtual returns (uint256);
    function supplyRatePerBlock() external view virtual returns (uint256);
    function totalBorrowsCurrent() external virtual returns (uint256);
    function borrowBalanceCurrent(address account) external virtual returns (uint256);
    function borrowBalanceStored(address account) external view virtual returns (uint256);
    function exchangeRateCurrent() external virtual returns (uint256);
    function exchangeRateStored() external view virtual returns (uint256);
    function getCash() external view virtual returns (uint256);
    function accrueInterest() external virtual returns (uint256);
    function seize(address liquidator, address borrower, uint256 seizeTokens) external virtual returns (uint256);

    /**
     * Admin Functions **
     */
    function _setPendingAdmin(address payable newPendingAdmin) external virtual returns (uint256);
    function _acceptAdmin() external virtual returns (uint256);
    function _setComptroller(ComptrollerInterface newComptroller) external virtual returns (uint256);
    function _setReserveFactor(uint256 newReserveFactorMantissa) external virtual returns (uint256);
    function _reduceReserves(uint256 reduceAmount) external virtual returns (uint256);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) external virtual returns (uint256);
}
