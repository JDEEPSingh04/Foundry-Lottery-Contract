// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helper = new HelperConfig();
        (
            ,
            ,
            address VRFCoordinator,
            ,
            uint64 SubscriptionID,
            ,
            address link,
            uint256 DeployerKey
        ) = helper.activeNetworkConfig();
        return createSubscription(VRFCoordinator,DeployerKey);
    }

    function createSubscription(
        address VRFCoordinator,uint256 DeployerKey
    ) public returns (uint64 SubscriptionID) {
        vm.startBroadcast(DeployerKey);
        SubscriptionID = VRFCoordinatorV2Mock(VRFCoordinator)
            .createSubscription();
        vm.stopBroadcast();
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helper = new HelperConfig();
        (
            ,
            ,
            address VRFCoordinator,
            ,
            uint64 SubscriptionID,
            ,
            address link,
            uint256 DeployerKey
        ) = helper.activeNetworkConfig();
        fundSubsciption(VRFCoordinator, SubscriptionID, link, DeployerKey);
    }

    function fundSubsciption(
        address VRFCoordinator,
        uint64 SubscriptionID,
        address link,
        uint256 DeployerKey
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(DeployerKey);
            VRFCoordinatorV2Mock(VRFCoordinator).fundSubscription(
                SubscriptionID,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(DeployerKey);
            LinkToken(link).transferAndCall(
                VRFCoordinator,
                FUND_AMOUNT,
                abi.encode(SubscriptionID)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address VRFCoordinator,
        uint64 SubscriptionID,
        address Raffle,
        uint256 DeployerKey
    ) public {
        vm.startBroadcast(DeployerKey);
        VRFCoordinatorV2Mock(VRFCoordinator).addConsumer(
            SubscriptionID,
            Raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helper = new HelperConfig();
        (
            ,
            ,
            address VRFCoordinator,
            ,
            uint64 SubscriptionID,
            ,
            ,
            uint256 DeployerKey
        ) = helper.activeNetworkConfig();
        addConsumer(VRFCoordinator, SubscriptionID, raffle, DeployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
