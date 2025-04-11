// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "./VowStorage.sol";
import {Auth} from "../../utils/Auth.sol";
import {Math} from "../../utils/Math.sol";

contract Vow is VowStorage, Auth {
    // --- Init ---
    constructor(address vat_, address flapper_, address flopper_) {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        flapper = FlapLike(flapper_);
        flopper = FlopLike(flopper_);
        vat.hope(flapper_);
        live = 1;
    }

    // Push to debt-queue
    function fess(uint256 tab) external auth {
        sin[block.timestamp] = Math.add(sin[block.timestamp], tab);
        Sin = Math.add(Sin, tab);
    }

    // Pop from debt-queue
    function flog(uint256 era) external {
        require(Math.add(era, wait) <= block.timestamp, "Vow/wait-not-finished");
        Sin = Math.sub(Sin, sin[era]);
        sin[era] = 0;
    }

    // Debt settlement
    function heal(uint256 rad) external {
        require(rad <= vat.dai(address(this)), "Vow/insufficient-surplus");
        require(rad <= Math.sub(Math.sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        vat.heal(rad);
    }

    function kiss(uint256 rad) external {
        require(rad <= Ash, "Vow/not-enough-ash");
        require(rad <= vat.dai(address(this)), "Vow/insufficient-surplus");
        Ash = Math.sub(Ash, rad);
        vat.heal(rad);
    }

    // Debt auction
    function flop() external returns (uint256 id) {
        require(sump <= Math.sub(Math.sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        require(vat.dai(address(this)) == 0, "Vow/surplus-not-zero");
        Ash = Math.add(Ash, sump);
        id = flopper.kick(address(this), dump, sump);
    }

    // Surplus auction
    function flap() external returns (uint256 id) {
        require(
            vat.dai(address(this)) >= Math.add(Math.add(vat.sin(address(this)), bump), hump), "Vow/insufficient-surplus"
        );
        require(Math.sub(Math.sub(vat.sin(address(this)), Sin), Ash) == 0, "Vow/debt-not-zero");
        id = flapper.kick(bump, 0);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "wait") wait = data;
        else if (what == "bump") bump = data;
        else if (what == "sump") sump = data;
        else if (what == "dump") dump = data;
        else if (what == "hump") hump = data;
        else revert("Vow/file-unrecognized-param");
    }

    function file(bytes32 what, address data) external auth {
        if (what == "flapper") {
            vat.nope(address(flapper));
            flapper = FlapLike(data);
            vat.hope(data);
        } else if (what == "flopper") {
            flopper = FlopLike(data);
        } else {
            revert("Vow/file-unrecognized-param");
        }
    }

    function cage() external override auth {
        require(live == 1, "Vow/not-live");
        live = 0;
        Sin = 0;
        Ash = 0;
        flapper.cage(vat.dai(address(flapper)));
        flopper.cage();
        vat.heal(Math.min(vat.dai(address(this)), vat.sin(address(this))));
    }
}
