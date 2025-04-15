// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

contract Auth {
    // 系统运行状态标志 1: 系统正常运行  0: 系统已关闭(紧急关停)
    uint256 public live; // Active Flag

    /**
     * @notice 含义: 权限控制映射，记录哪些地址有权限调用受限函数
     * ​值类型: 1 表示有权限，0 表示无权限
     * ​关键操作:
     * rely(address usr) 添加权限
     * deny(address usr) 移除权限
     */
    mapping(address => uint256) public wards;

    modifier auth() {
        require(wards[msg.sender] == 1, "not-authorized");
        _;
    }

    // 添加权限
    function rely(address usr) external auth {
        require(live == 1, "not-live");
        wards[usr] = 1;
    }

    // 移除权限
    function deny(address usr) external auth {
        require(live == 1, "not-live");
        wards[usr] = 0;
    }

    // 关闭系统
    function cage() external virtual auth {
        live = 0;
    }
}
