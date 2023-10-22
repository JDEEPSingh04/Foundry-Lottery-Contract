// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        (
            uint256 EntranceFee,
            uint256 TimeInterval,
            address VRFCoordinator,
            bytes32 GasLane,
            uint64 SubscriptionID,
            uint32 CallBackGas,
            address link,
            uint256 DeployerKey
        ) = helper.activeNetworkConfig();

        if (SubscriptionID == 0) {
            CreateSubscription create = new CreateSubscription();
            SubscriptionID = create.createSubscription(VRFCoordinator,DeployerKey);

            FundSubscription fund = new FundSubscription();
            fund.fundSubsciption(VRFCoordinator, SubscriptionID, link,DeployerKey);
        }
        vm.startBroadcast();
        Raffle newRaffle = new Raffle(
            EntranceFee,
            TimeInterval,
            VRFCoordinator,
            GasLane,
            SubscriptionID,
            CallBackGas
        );
        vm.stopBroadcast();
 
        AddConsumer add = new AddConsumer();
        add.addConsumer(VRFCoordinator, SubscriptionID, address(newRaffle),DeployerKey);
        return (newRaffle, helper);
    }
}
