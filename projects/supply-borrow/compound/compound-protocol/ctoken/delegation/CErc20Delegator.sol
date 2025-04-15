// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CTokenInterface.sol";
import "./CErc20Interface.sol";
import "./CDelegatorInterface.sol";

/// @notice 该合约主要实现3个功能：
///         1）存储用户数据
///         2）提供前端用户调用接口
///         3）逻辑代理转发
contract CErc20Delegator is CTokenInterface, CErc20Interface, CDelegatorInterface {
    constructor(
        address underlying_,
        ComptrollerInterface comptroller_,
        InterestRateModel interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address payable admin_,
        address implementation_,
        bytes memory becomeImplementationData
    ) {
        admin = payable(msg.sender);

        ///@notice 初始化调用
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,string,string,uint8)",
                underlying_,
                comptroller_,
                interestRateModel_,
                initialExchangeRateMantissa_,
                name_,
                symbol_,
                decimals_
            )
        );

        _setImplementation(implementation_, false, becomeImplementationData);
        admin = admin_;
    }

    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData)
        public
        override
    {
        require(msg.sender == admin, "CErc20Delegator::_setImplementation: Caller must be admin");

        if (allowResign) {
            delegateToImplementation(abi.encodeWithSignature("_resignImplementation()"));
        }

        address oldImplementation = implementation;
        implementation = implementation_;

        // q 设置实现方案后，为什么还要调用代理转发方法
        delegateToImplementation(abi.encodeWithSignature("_becomeImplementation(bytes)", becomeImplementationData));
        emit NewImplementation(oldImplementation, implementation);
    }

    function mint(uint256 mintAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("mint(uint256)", mintAmount));
        return abi.decode(data, (uint256));
    }

    function redeem(uint256 redeemTokens) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("redeem(uint256)", redeemTokens));
        return abi.decode(data, (uint256));
    }

    function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("redeemUnderlying(uint256)", redeemAmount));
        return abi.decode(data, (uint256));
    }

    function borrow(uint256 borrowAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("borrow(uint256)", borrowAmount));
        return abi.decode(data, (uint256));
    }

    function repayBorrow(uint256 repayAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("repayBorrow(uint256)", repayAmount));
        return abi.decode(data, (uint256));
    }

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(
            abi.encodeWithSignature("repayBorrowBehalf(address,uint256)", borrower, repayAmount)
        );
        return abi.decode(data, (uint256));
    }

    function liquidateBorrow(address borrower, uint256 repayAmount, CTokenInterface cTokenCollateral)
        external
        override
        returns (uint256)
    {
        bytes memory data = delegateToImplementation(
            abi.encodeWithSignature("liquidateBorrow(address,uint256,address)", borrower, repayAmount, cTokenCollateral)
        );
        return abi.decode(data, (uint256));
    }

    function transfer(address dst, uint256 amount) external override returns (bool) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("transfer(address,uint256)", dst, amount));
        return abi.decode(data, (bool));
    }

    function transferFrom(address src, address dst, uint256 amount) external override returns (bool) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("transferFrom(address,address,uint256)", src, dst, amount));
        return abi.decode(data, (bool));
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        return abi.decode(data, (bool));
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        bytes memory data =
            delegateToViewImplementation(abi.encodeWithSignature("allowance(address,address)", owner, spender));
        return abi.decode(data, (uint256));
    }

    function balanceOf(address owner) external view override returns (uint256) {
        bytes memory data = delegateToViewImplementation(abi.encodeWithSignature("balanceOf(address)", owner));
        return abi.decode(data, (uint256));
    }

    function balanceOfUnderlying(address owner) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("balanceOfUnderlying(address)", owner));
        return abi.decode(data, (uint256));
    }

    function getAccountSnapshot(address account) external view override returns (uint256, uint256, uint256, uint256) {
        bytes memory data =
            delegateToViewImplementation(abi.encodeWithSignature("getAccountSnapshot(address)", account));
        return abi.decode(data, (uint256, uint256, uint256, uint256));
    }

    function borrowRatePerBlock() external view override returns (uint256) {
        bytes memory data = delegateToViewImplementation(abi.encodeWithSignature("borrowRatePerBlock()"));
        return abi.decode(data, (uint256));
    }

    function supplyRatePerBlock() external view override returns (uint256) {
        bytes memory data = delegateToViewImplementation(abi.encodeWithSignature("supplyRatePerBlock()"));
        return abi.decode(data, (uint256));
    }

    function totalBorrowsCurrent() external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("totalBorrowsCurrent()"));
        return abi.decode(data, (uint256));
    }

    function borrowBalanceCurrent(address account) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("borrowBalanceCurrent(address)", account));
        return abi.decode(data, (uint256));
    }

    function borrowBalanceStored(address account) external view override returns (uint256) {
        bytes memory data =
            delegateToViewImplementation(abi.encodeWithSignature("borrowBalanceStored(address)", account));
        return abi.decode(data, (uint256));
    }

    function exchangeRateCurrent() external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("exchangeRateCurrent()"));
        return abi.decode(data, (uint256));
    }

    function exchangeRateStored() external view override returns (uint256) {
        bytes memory data = delegateToViewImplementation(abi.encodeWithSignature("exchangeRateStored()"));
        return abi.decode(data, (uint256));
    }

    function getCash() external view override returns (uint256) {
        bytes memory data = delegateToViewImplementation(abi.encodeWithSignature("getCash()"));
        return abi.decode(data, (uint256));
    }

    function accrueInterest() external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("accrueInterest()"));
        return abi.decode(data, (uint256));
    }

    function seize(address liquidator, address borrower, uint256 seizeTokens) external override returns (uint256) {
        bytes memory data = delegateToImplementation(
            abi.encodeWithSignature("seize(address,address,uint256)", liquidator, borrower, seizeTokens)
        );
        return abi.decode(data, (uint256));
    }

    function sweepToken(EIP20NonStandardInterface token) external virtual override {
        delegateToImplementation(abi.encodeWithSignature("sweepToken(address)", token));
    }

    /*////////////////////////////////////////////////////// 
                        Admin Functions
    //////////////////////////////////////////////////////*/
    function _setPendingAdmin(address payable newPendingAdmin) external override returns (uint256) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("_setPendingAdmin(address)", newPendingAdmin));
        return abi.decode(data, (uint256));
    }

    function _setComptroller(ComptrollerInterface newComptroller) public override returns (uint256) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("_setComptroller(address)", newComptroller));
        return abi.decode(data, (uint256));
    }

    function _setReserveFactor(uint256 newReserveFactorMantissa) external override returns (uint256) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("_setReserveFactor(uint256)", newReserveFactorMantissa));
        return abi.decode(data, (uint256));
    }

    function _acceptAdmin() external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("_acceptAdmin()"));
        return abi.decode(data, (uint256));
    }

    function _addReserves(uint256 addAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("_addReserves(uint256)", addAmount));
        return abi.decode(data, (uint256));
    }

    function _reduceReserves(uint256 reduceAmount) external override returns (uint256) {
        bytes memory data = delegateToImplementation(abi.encodeWithSignature("_reduceReserves(uint256)", reduceAmount));
        return abi.decode(data, (uint256));
    }

    function _setInterestRateModel(InterestRateModel newInterestRateModel) public override returns (uint256) {
        bytes memory data =
            delegateToImplementation(abi.encodeWithSignature("_setInterestRateModel(address)", newInterestRateModel));
        return abi.decode(data, (uint256));
    }

    /*////////////////////////////////////////////////////// 
                        tools function
    //////////////////////////////////////////////////////*/
    function delegateToImplementation(bytes memory data) public returns (bytes memory) {
        return delegateTo(implementation, data);
    }

    function delegateToViewImplementation(bytes memory data) public view returns (bytes memory) {
        (bool success, bytes memory returnData) =
            address(this).staticcall(abi.encodeWithSignature("delegateToImplementation(bytes)", data));
        assembly {
            if eq(success, 0) { revert(add(returnData, 0x20), returndatasize()) }
        }
        return abi.decode(returnData, (bytes));
    }

    /*////////////////////////////////////////////////////// 
                        internal function
    //////////////////////////////////////////////////////*/
    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) { revert(add(returnData, 0x20), returndatasize()) }
        }
        return returnData;
    }
}
