//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IExchange {
    function ethToTokenSwap(uint256 _minTokens) external payable;

    function ethToTokenTransfer(uint256 _minTokens, address _recipient) external payable;
}
