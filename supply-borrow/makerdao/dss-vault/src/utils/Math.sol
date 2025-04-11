// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

library Math {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function dmul(uint256 x, uint256 y, uint256 dec) internal pure returns (uint256 z) {
        z = mul(x, y) / dec;
    }

    function diff(uint256 x, uint256 y) internal pure returns (int256 z) {
        z = int256(x) - int256(y);
        require(int256(x) >= 0 && int256(y) >= 0);
    }

    function ddiv(uint256 x, uint256 y, uint256 dec) internal pure returns (uint256 z) {
        z = mul(x, dec) / y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function _add(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x + uint256(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }

    function _sub(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x - uint256(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }

    function _mul(uint256 x, int256 y) internal pure returns (int256 z) {
        z = int256(x) * y;
        require(int256(x) >= 0);
        require(y == 0 || z / y == int256(x));
    }

    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function toUint48(uint256 x) internal pure returns (uint48 z) {
        require((z = uint48(x)) == x, "DssVest/uint48-overflow");
    }

    function toUint128(uint256 x) internal pure returns (uint128 z) {
        require((z = uint128(x)) == x, "DssVest/uint128-overflow");
    }

    // --- tool ---
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := or(x, y)
        }
    }

    function both(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := and(x, y)
        }
    }

    // --- Math ---

    function add256(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function add48(uint48 x, uint48 y) internal pure returns (uint48 z) {
        require((z = x + y) >= x);
    }

    // x^n, 精度为 b
    function rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            // 当n为偶数时：x^n = (x^2)^(n/2)
            // 当n为奇数时：x^n = x * x^(n-1)
            switch x
            case 0 {
                switch n
                // 0^0 = 1（使用精度基数）
                case 0 { z := b }
                // 0^n = 0
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                // 开始计算时若n为偶数，z初始化为精度基数
                case 0 { z := b }
                // n为奇数时初始化为x
                default { z := x }
                let half := div(b, 2)
                // 通过平方取幂法（Exponentiation by Squaring）迭代计算
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    // 每次循环将x平方
                    let xx := mul(x, x)
                    // 检查平方是否溢出（超过uint256）
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    // 更新x为平方值（保持精度）
                    x := div(xxRound, b)
                    // 如果当前位为1，累乘到结果
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function abaci_rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch n
            case 0 { z := b }
            default {
                switch x
                case 0 { z := 0 }
                default {
                    switch mod(n, 2)
                    case 0 { z := b }
                    default { z := x }
                    let half := div(b, 2) // for rounding.
                    for { n := div(n, 2) } n { n := div(n, 2) } {
                        let xx := mul(x, x)
                        if shr(128, x) { revert(0, 0) }
                        let xxRound := add(xx, half)
                        if lt(xxRound, xx) { revert(0, 0) }
                        x := div(xxRound, b)
                        if mod(n, 2) {
                            let zx := mul(z, x)
                            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
                            let zxRound := add(zx, half)
                            if lt(zxRound, zx) { revert(0, 0) }
                            z := div(zxRound, b)
                        }
                    }
                }
            }
        }
    }
}
