// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./FlopStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

contract Flopper is FlopStorage, Auth {
    // --- Init ---
    constructor(address vat_, address gem_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        gem = GemLike(gem_);
        live = 1;
    }

    // --- Auction ---
    function kick(address gal, uint256 lot, uint256 bid) external auth returns (uint256 id) {
        require(live == 1, "Flopper/not-live");
        require(kicks < type(uint256).max, "Flopper/overflow");
        id = ++kicks;

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = gal;
        bids[id].end = Math.add48(uint48(block.timestamp), tau);

        emit Kick(id, lot, bid, gal);
    }

    function tick(uint256 id) external {
        require(bids[id].end < block.timestamp, "Flopper/not-finished");
        require(bids[id].tic == 0, "Flopper/bid-already-placed");
        bids[id].lot = Math.mul(pad, bids[id].lot) / ONE;
        bids[id].end = Math.add48(uint48(block.timestamp), tau);
    }

    function dent(uint256 id, uint256 lot, uint256 bid) external {
        require(live == 1, "Flopper/not-live");
        require(bids[id].guy != address(0), "Flopper/guy-not-set");
        require(bids[id].tic > block.timestamp || bids[id].tic == 0, "Flopper/already-finished-tic");
        require(bids[id].end > block.timestamp, "Flopper/already-finished-end");

        require(bid == bids[id].bid, "Flopper/not-matching-bid");
        require(lot < bids[id].lot, "Flopper/lot-not-lower");
        require(Math.mul(beg, lot) <= Math.mul(bids[id].lot, ONE), "Flopper/insufficient-decrease");

        if (msg.sender != bids[id].guy) {
            vat.move(msg.sender, bids[id].guy, bid);

            // on first dent, clear as much Ash as possible
            if (bids[id].tic == 0) {
                uint256 Ash = VowLike(bids[id].guy).Ash();
                VowLike(bids[id].guy).kiss(Math.min(bid, Ash));
            }

            bids[id].guy = msg.sender;
        }

        bids[id].lot = lot;
        bids[id].tic = Math.add48(uint48(block.timestamp), ttl);
    }

    function deal(uint256 id) external {
        require(live == 1, "Flopper/not-live");
        require(
            bids[id].tic != 0 && (bids[id].tic < block.timestamp || bids[id].end < block.timestamp),
            "Flopper/not-finished"
        );
        gem.mint(bids[id].guy, bids[id].lot);
        delete bids[id];
    }

    // --- Shutdown ---
    function cage() external override auth {
        live = 0;
        vow = msg.sender;
    }

    function yank(uint256 id) external {
        require(live == 0, "Flopper/still-live");
        require(bids[id].guy != address(0), "Flopper/guy-not-set");
        vat.suck(vow, bids[id].guy, bids[id].bid);
        delete bids[id];
    }

    // --- Admin ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "beg") beg = data;
        else if (what == "pad") pad = data;
        else if (what == "ttl") ttl = uint48(data);
        else if (what == "tau") tau = uint48(data);
        else revert("Flopper/file-unrecognized-param");
    }
}
