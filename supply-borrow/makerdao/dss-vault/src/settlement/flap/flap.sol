// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./FlapStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

contract Flapper is FlapStorage, Auth {
    // --- Init ---
    constructor(address vat_, address gem_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        gem = GemLike(gem_);
        live = 1;
    }

    // --- Auction ---
    function kick(uint256 lot, uint256 bid) external auth returns (uint256 id) {
        require(live == 1, "Flapper/not-live");
        require(kicks < type(uint256).max, "Flapper/overflow");
        fill = Math.add256(fill, lot);
        require(fill <= lid, "Flapper/over-lid");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender; // configurable??
        bids[id].end = Math.add48(uint48(block.timestamp), tau);

        vat.move(msg.sender, address(this), lot);

        emit Kick(id, lot, bid);
    }

    function tick(uint256 id) external {
        require(bids[id].end < block.timestamp, "Flapper/not-finished");
        require(bids[id].tic == 0, "Flapper/bid-already-placed");
        bids[id].end = Math.add48(uint48(block.timestamp), tau);
    }

    function tend(uint256 id, uint256 lot, uint256 bid) external {
        require(live == 1, "Flapper/not-live");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flapper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flapper/already-finished-end");

        require(lot == bids[id].lot, "Flapper/lot-not-matching");
        require(bid > bids[id].bid, "Flapper/bid-not-higher");
        require(Math.mul(bid, ONE) >= Math.mul(beg, bids[id].bid), "Flapper/insufficient-increase");

        if (msg.sender != bids[id].guy) {
            gem.move(msg.sender, bids[id].guy, bids[id].bid);
            bids[id].guy = msg.sender;
        }
        gem.move(msg.sender, address(this), bid - bids[id].bid);

        bids[id].bid = bid;
        bids[id].tic = Math.add48(uint48(block.timestamp), ttl);
    }

    function deal(uint256 id) external {
        require(live == 1, "Flapper/not-live");
        require(
            bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp),
            "Flapper/not-finished"
        );
        uint256 lot = bids[id].lot;
        vat.move(address(this), bids[id].guy, lot);
        gem.burn(address(this), bids[id].bid);
        delete bids[id];
        fill = Math.sub(fill, lot);
    }

    function cage(uint256 rad) external auth {
        live = 0;
        vat.move(address(this), msg.sender, rad);
    }

    function yank(uint256 id) external {
        require(live == 0, "Flapper/still-live");
        require(bids[id].guy != address(0), "Flapper/guy-not-set");
        gem.move(address(this), bids[id].guy, bids[id].bid);
        delete bids[id];
    }

    // --- Admin ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "beg") beg = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else if (what == "lid") lid = data;
        else revert("Flapper/file-unrecognized-param");
    }
}
