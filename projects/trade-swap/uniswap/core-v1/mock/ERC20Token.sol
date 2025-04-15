// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XGHToken is ERC20 {
    constructor() ERC20("XGH Token", "XGH") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract XXXToken is ERC20 {
    constructor() ERC20("XXX Token", "XXX") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
