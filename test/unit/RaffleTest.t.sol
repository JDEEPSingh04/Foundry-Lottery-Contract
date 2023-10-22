// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event RaffleEntered(address indexed player);

    Raffle raffle;
    HelperConfig helper;
    uint256 EntranceFee;
    uint256 TimeInterval;
    address VRFCoordinator;
    bytes32 GasLane;
    uint64 SubscriptionID;
    uint32 CallBackGas;
    address link;
    uint256 DeployerKey;
    address public Player = makeAddr("Player");

    function setUp() external {
        DeployRaffle deploy = new DeployRaffle();
        (raffle, helper) = deploy.run();
        (
            EntranceFee,
            TimeInterval,
            VRFCoordinator,
            GasLane,
            SubscriptionID,
            CallBackGas,
            link,
            DeployerKey
        ) = helper.activeNetworkConfig();
        vm.deal(Player, 10 ether);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.Open);
    }

    function testRaffleRevertWhenNotPaidEnough() public {
        vm.prank(Player);

        vm.expectRevert();
        raffle.enterRaffle();
    }

    function testRaffleUpdatesAfterPlayerEnter()
        public
        RaffleEnteredAndTimePassed
    {
        address payable[] memory players = raffle.getPlayers();
        assert(players[0] == Player);
    }

    /*
    function testEventEmittedWhenPlayerEnters() public{
        vm.prank(Player);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(Player);
        raffle.enterRaffle{value:EntranceFee}();
    }
    */

    function testCantEnterWhenRaffleCalculating()
        public
        RaffleEnteredAndTimePassed
    {
        raffle.performUpKeep("");

        vm.prank(Player);
        vm.expectRevert();
        raffle.enterRaffle{value: EntranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + TimeInterval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfCalculating()
        public
        RaffleEnteredAndTimePassed
    {
        raffle.performUpKeep("");
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfNotEnoughTimePassed() public {
        vm.prank(Player);
        raffle.enterRaffle{value: EntranceFee}();
        vm.warp(block.timestamp + TimeInterval - 1);
        (bool upKeep, ) = raffle.checkUpKeep("");
        assert(upKeep == false);
    }

    function testestCheckUpkeepReturnsTrueWhenParametersGood()
        public
        RaffleEnteredAndTimePassed
    {
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assert(upKeepNeeded == true);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        RaffleEnteredAndTimePassed
    {
        raffle.performUpKeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 currentBalance = 0;
        address[] memory players = new address[](0);
        Raffle.RaffleState raffleState = Raffle.RaffleState.Open;

        vm.expectRevert();
        raffle.performUpKeep("");
    }

    function testEventEmittedWhenPerformUpKeepRuns()
        public
        RaffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpKeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];

        assert(requestID > 0);
    }

    function testFulFillRandomWordsCanOnlyBeCalledByPerformUpKeep(
        uint256 requestID
    ) public RaffleEnteredAndTimePassed Skip{
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(VRFCoordinator).fulfillRandomWords(
            requestID,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsTheMoney() public Skip {
        uint256 ENTRANTS = 5;
        uint256 STARTING_BALANCE = 100 ether;
        for (uint256 i = 0; i <= ENTRANTS; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: EntranceFee}();
        }

        vm.warp(block.timestamp + TimeInterval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpKeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];

        uint256 lastTimeStamp = raffle.getLastTime();

        VRFCoordinatorV2Mock(VRFCoordinator).fulfillRandomWords(
            uint256(requestID),
            address(raffle)
        );

        uint256 NewTimeStamp = raffle.getLastTime();
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayers().length == 0);
        assert(NewTimeStamp > lastTimeStamp);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_BALANCE + ENTRANTS * EntranceFee
        );
    }

    modifier RaffleEnteredAndTimePassed() {
        vm.prank(Player);
        raffle.enterRaffle{value: EntranceFee}();
        vm.warp(block.timestamp + TimeInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier Skip(){
        if(block.chainid!=31337)
            return;
        _;
    }
}
