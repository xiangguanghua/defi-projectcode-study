// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./ClipStorage.sol";
import "../../utils/Auth.sol";
import "../../utils/Math.sol";

/**
 * 负责处理抵押品拍卖的自动化流程
 * 1、​抵押品拍卖自动化​：通过荷兰式拍卖逐步降低价格
 * ​2、风险隔离​：每个抵押品类型有独立的拍卖合约
 * ​3、动态定价​：基于市场供需实时调整价格下降曲线
 * ​4、多阶段清算​：支持局部清算和全额清算
 */
contract Clipper is ClipStorage, Auth {
    // --- Synchronization ---
    modifier lock() {
        require(locked == 0, "Clipper/system-locked");
        locked = 1;
        _;
        locked = 0;
    }

    modifier isStopped(uint256 level) {
        require(stopped < level, "Clipper/stopped-incorrect");
        _;
    }

    constructor(address vat_, address spotter_, address dog_, bytes32 ilk_) {
        vat = VatLike(vat_); // 1. 初始化核心会计合约引用
        spotter = SpotterLike(spotter_); // 2. 设置价格预言机合约
        dog = DogLike(dog_); // 3. 绑定清算管理合约
        ilk = ilk_; // 4. 设置抵押品类型标识
        buf = RAY; // 5. 初始化价格缓冲系数
        wards[msg.sender] = 1; // 6. 设置合约部署者为管理员
        emit Rely(msg.sender); // 7. 触发管理员添加事件
    }

    // --- Auction ---
    function getFeedPrice() internal returns (uint256 feedPrice) {
        // 抵押品类型对应的预言机合约
        (PipLike pip,) = spotter.ilks(ilk);
        // 获取预言机最新价格
        (bytes32 val, bool has) = pip.peek();
        require(has, "Clipper/invalid-price");
        // 价格标准化处理
        /**
         * **uint256(val)**​
         * 将 bytes32 价格转为整数（如 2000 表示 $2000）
         *
         * ​**mul(uint256(val), BLN)**​
         * BLN 是 Maker 的精度常数（通常 10^9）
         * 作用：统一单位精度（如 2000 → 2000_000_000_000）
         *
         * ​**spotter.par()**​
         * 获取 Dai 的目标价格（通常 1 USD，存储为 RAY 精度 10^27）
         * 当 Dai 脱锚时用于调整（如 Dai=$1.01 时 par=1.01 * 10^27）
         *
         * ​**rdiv(x, y)**​
         * 安全的定点数除法（x * RAY / y）
         * 最终价格单位转换为 RAY（27位小数）
         */
        feedPrice = Math.ddiv(Math.mul(uint256(val), BLN), spotter.par(), RAY);
    }

    /**
     * 用于发起抵押品拍卖的核心函数
     * @param tab 待清算的债务数量 [rad]
     * @param lot 待拍卖的抵押品数量 [wad]
     * @param usr 抵押品所有者地址（接收剩余抵押品）
     * @param kpr 清算人地址（接收激励）
     */
    function kick(uint256 tab, uint256 lot, address usr, address kpr)
        external
        auth
        lock
        isStopped(1)
        returns (uint256 id)
    {
        // Input validation
        require(tab > 0, "Clipper/zero-tab");
        require(lot > 0, "Clipper/zero-lot");
        require(usr != address(0), "Clipper/zero-usr");
        // 自增计数器生成唯一拍卖ID
        id = ++kicks;
        require(id > 0, "Clipper/overflow"); //检查ID是否溢出

        // 将新拍卖ID加入活跃拍卖列表
        active.push(id);
        //记录该ID在活跃数组中的位置（用于后续高效删除）
        sales[id].pos = active.length - 1;

        // 拍卖数据初始化
        sales[id].tab = tab;
        sales[id].lot = lot;
        sales[id].usr = usr;
        sales[id].tic = uint96(block.timestamp);

        //初始价格计算
        uint256 top;
        top = Math.dmul(getFeedPrice(), buf, RAY);
        require(top > 0, "Clipper/zero-top-price");
        sales[id].top = top;

        // 清算人激励
        uint256 _tip = tip;
        uint256 _chip = chip;
        uint256 coin;
        if (_tip > 0 || _chip > 0) {
            coin = Math.add(_tip, Math.dmul(tab, _chip, WAD));
            vat.suck(vow, kpr, coin);
        }

        emit Kick(id, top, tab, lot, usr, kpr, coin);
    }

    /**
     * 用于重置拍卖的函数，当现有拍卖条件过时（如市场价格大幅下跌）时，允许清算人重启拍卖
     * @param id 需要重置的拍卖ID
     * @param kpr 执行重置的清算人地址（接收激励）
     */
    function redo(uint256 id, address kpr) external lock isStopped(2) {
        // 读取拍卖数据
        address usr = sales[id].usr;
        uint96 tic = sales[id].tic;
        uint256 top = sales[id].top;

        //验证拍卖有效性
        require(usr != address(0), "Clipper/not-running-auction");

        // 检查重置条件
        // and compute current price [ray]
        /**
         * status() 内部函数检查拍卖是否需要重置：
         * -价格已降至最低阈值
         * -或拍卖持续时间过长
         * 只有需要重置的拍卖才能执行 redo
         */
        (bool done,) = status(tic, top);
        require(done, "Clipper/cannot-reset");

        // 更新拍卖参数
        uint256 tab = sales[id].tab;
        uint256 lot = sales[id].lot;
        sales[id].tic = uint96(block.timestamp);

        // 重新计算初始价格
        uint256 feedPrice = getFeedPrice();
        top = Math.dmul(feedPrice, buf, RAY);
        require(top > 0, "Clipper/zero-top-price");
        sales[id].top = top;

        // 清算人激励
        uint256 _tip = tip;
        uint256 _chip = chip;
        uint256 coin;
        if (_tip > 0 || _chip > 0) {
            uint256 _chost = chost;
            if (tab >= _chost && Math.mul(lot, feedPrice) >= _chost) {
                coin = Math.add(_tip, Math.dmul(tab, _chip, WAD));
                vat.suck(vow, kpr, coin);
            }
        }

        emit Redo(id, top, tab, lot, usr, kpr, coin);
    }

    /**
     * 负责处理拍卖的实际购买行为
     * @param id 拍卖ID
     * @param amt 最大购买抵押品数量 [wad]
     * @param max 买家可接受的最高单价 [ray]
     * @param who 抵押品接收地址
     * @param data 回调数据
     */
    function take(uint256 id, uint256 amt, uint256 max, address who, bytes calldata data) external lock isStopped(3) {
        //拍卖状态验证
        address usr = sales[id].usr;
        uint96 tic = sales[id].tic;

        require(usr != address(0), "Clipper/not-running-auction");

        //价格计算与验证
        uint256 price;
        {
            bool done;
            (done, price) = status(tic, sales[id].top);
            require(!done, "Clipper/needs-reset");
        }

        // Ensure price is acceptable to buyer
        require(max >= price, "Clipper/too-expensive");

        //购买数量计算
        uint256 lot = sales[id].lot;
        uint256 tab = sales[id].tab;
        uint256 owe;

        {
            uint256 slice = Math.min(lot, amt); // 实际购买数量
            owe = Math.mul(slice, price); // 需要支付的DAI
            // 调整逻辑确保不超过剩余债务
            if (owe > tab) {
                owe = tab; // owe' <= owe
                slice = owe / price; // slice' = owe' / price <= owe / price == slice <= lot
            } else if (owe < tab && slice < lot) {
                // 处理债务尾数
                uint256 _chost = chost;
                if (tab - owe < _chost) {
                    require(tab > _chost, "Clipper/no-partial-purchase");
                    owe = tab - _chost; // owe' <= owe
                    slice = owe / price; // slice' = owe' / price < owe / price == slice < lot
                }
            }
            tab = tab - owe; // safe since owe <= tab
            lot = lot - slice;
            //资产转移
            vat.flux(ilk, address(this), who, slice);
            // Do external call (if data is defined) but to be
            // extremely careful we don't allow to do it to the two
            // contracts which the Clipper needs to be authorized
            DogLike dog_ = dog;
            // 回调机制
            if (data.length > 0 && who != address(vat) && who != address(dog_)) {
                ClipperCallee(who).clipperCall(msg.sender, owe, slice, data);
            }
            vat.move(msg.sender, vow, owe);
            dog_.digs(ilk, lot == 0 ? tab + owe : owe);
        }

        // 拍卖状态更新
        if (lot == 0) {
            _remove(id);
        } else if (tab == 0) {
            vat.flux(ilk, address(this), usr, lot);
            _remove(id);
        } else {
            sales[id].tab = tab;
            sales[id].lot = lot;
        }

        emit Take(id, max, price, owe, tab, lot, usr);
    }

    /*/////////////////////////////////////////////////////////
                            辅助方法
    ////////////////////////////////////////////////////////*/

    // Internally returns boolean for if an auction needs a redo
    function status(uint96 tic, uint256 top) internal view returns (bool done, uint256 price) {
        price = calc.price(top, Math.sub(block.timestamp, tic));
        done = (Math.sub(block.timestamp, tic) > tail || Math.ddiv(price, top, RAY) < cusp);
    }

    function _remove(uint256 id) internal {
        uint256 _move = active[active.length - 1];
        if (id != _move) {
            uint256 _index = sales[id].pos;
            active[_index] = _move;
            sales[_move].pos = _index;
        }
        active.pop();
        delete sales[id];
    }

    // The number of active auctions
    function count() external view returns (uint256) {
        return active.length;
    }

    // Return the entire array of active auctions
    function list() external view returns (uint256[] memory) {
        return active;
    }

    // Externally returns boolean for if an auction needs a redo and also the current price
    function getStatus(uint256 id) external view returns (bool needsRedo, uint256 price, uint256 lot, uint256 tab) {
        // Read auction data
        address usr = sales[id].usr;
        uint96 tic = sales[id].tic;

        bool done;
        (done, price) = status(tic, sales[id].top);

        needsRedo = usr != address(0) && done;
        lot = sales[id].lot;
        tab = sales[id].tab;
    }

    // Public function to update the cached dust*chop value.
    function upchost() external {
        (,,,, uint256 _dust) = VatLike(vat).ilks(ilk);
        chost = Math.dmul(_dust, dog.chop(ilk), WAD);
    }

    // Cancel an auction during ES or via governance action.
    function yank(uint256 id) external auth lock {
        require(sales[id].usr != address(0), "Clipper/not-running-auction");
        dog.digs(ilk, sales[id].tab);
        vat.flux(ilk, address(this), msg.sender, sales[id].lot);
        _remove(id);
        emit Yank(id);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth lock {
        if (what == "buf") buf = data;
        else if (what == "tail") tail = data; // Time elapsed before auction reset

        else if (what == "cusp") cusp = data; // Percentage drop before auction reset

        else if (what == "chip") chip = uint64(data); // Percentage of tab to incentivize (max: 2^64 - 1 => 18.xxx WAD = 18xx%)

        else if (what == "tip") tip = uint192(data); // Flat fee to incentivize keepers (max: 2^192 - 1 => 6.277T RAD)

        else if (what == "stopped") stopped = data; // Set breaker (0, 1, 2, or 3)

        else revert("Clipper/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, address data) external auth lock {
        if (what == "spotter") spotter = SpotterLike(data);
        else if (what == "dog") dog = DogLike(data);
        else if (what == "vow") vow = data;
        else if (what == "calc") calc = AbacusLike(data);
        else revert("Clipper/file-unrecognized-param");
        emit File(what, data);
    }
}
