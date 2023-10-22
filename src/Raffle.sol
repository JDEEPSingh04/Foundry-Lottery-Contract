// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Interface} from "lib/chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "lib/chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnough();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpKeepNotRequired(
        uint256 currentBalance,
        address payable[] players,
        RaffleState raffleState
    );

    enum RaffleState {
        Open,
        Calculating
    }

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_TimeInterval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 i_subscriptionID;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    address private s_RecentWinner;
    RaffleState private s_raffleState;

    event enteredRaffle(address indexed player);
    event PickedWinner(address indexed Winner);
    event RequestRaffleWinner(uint256 indexed RequestID);

    constructor(
        uint256 EntranceFee,
        uint256 TimeInterval,
        address VRFCoordinator,
        bytes32 KeyHash,
        uint64 SubscriptionID,
        uint32 CallBackGas
    ) VRFConsumerBaseV2(VRFCoordinator) {
        i_entranceFee = EntranceFee;
        i_TimeInterval = TimeInterval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(VRFCoordinator);
        i_keyHash = KeyHash;
        i_subscriptionID = SubscriptionID;
        i_callbackGasLimit = CallBackGas;
        s_raffleState = RaffleState.Open;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnough();
        if (s_raffleState != RaffleState.Open) revert Raffle__NotOpen();
        s_players.push(payable(msg.sender));
        emit enteredRaffle(msg.sender);
    }

    function checkUpKeep(
        bytes memory /*CheckData*/
    ) public view returns (bool upKeepNeeded, bytes memory /*checkData*/) {
        bool isTime = block.timestamp - s_lastTimeStamp >= i_TimeInterval;
        bool isOpen = s_raffleState == RaffleState.Open;
        bool isFunded = address(this).balance > 0;
        bool isPlayers = s_players.length > 0;
        upKeepNeeded = isFunded && isOpen && isPlayers && isTime;
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep(bytes calldata /*checkData*/) external {
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotRequired(
                address(this).balance,
                s_players,
                s_raffleState
            );
        }
        s_raffleState = RaffleState.Calculating;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionID,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable Winner = s_players[winnerIndex];
        s_RecentWinner = Winner;
        s_raffleState = RaffleState.Open;
        s_lastTimeStamp = block.timestamp;
        s_players = new address payable[](0);
        emit PickedWinner(Winner);
        (bool success, ) = Winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers()
        external
        view
        returns (address payable[] memory Players)
    {
        Players = s_players;
    }

    function getRecentWinner() external view returns (address) {
        return s_RecentWinner;
    }

    function getLastTime() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
