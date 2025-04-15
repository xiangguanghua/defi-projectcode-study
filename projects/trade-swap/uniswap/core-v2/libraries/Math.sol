//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Math {
    //获取最小值
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    /**
     *
     * 用于计算一个无符号整数 y 的 ​平方根​（向下取整）。
     * 它实现了 ​牛顿迭代法​（Newton's Method），也称为 ​牛顿-拉弗森法​（Newton-Raphson Method），
     * 来近似计算平方根。
     *
     * 如果 y=9，则 z=3。
     * 如果 y=10，则 z=3, 因为3.162，向下取整为 3
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y; // 初始化 z 为 y
            uint256 x = y / 2 + 1; // 初始猜测值
            while (x < z) {
                // 迭代直到收敛
                z = x; // 更新 z
                x = (y / x + x) / 2; // 牛顿迭代公式
            }
        } else if (y != 0) {
            z = 1; // 如果 y 是 1、2 或 3，平方根为 1
        }
    }
}
