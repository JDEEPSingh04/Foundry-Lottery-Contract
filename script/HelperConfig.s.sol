// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 EntranceFee;
        uint256 TimeInterval;
        address VRFCoordinator;
        bytes32 GasLane;
        uint64 SubscriptionID;
        uint32 CallBackGas;
        address link;
        uint256 DeployerKey;
    }
    NetworkConfig public activeNetworkConfig;
    uint256 public constant DEFAULT_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        }  
        else {
            activeNetworkConfig = getAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                EntranceFee: 0.08 ether,
                TimeInterval: 60,
                VRFCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                GasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                SubscriptionID: 6059,
                CallBackGas: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                DeployerKey: 0x17117ecb4ca4c1324546c047a43f4a6ae8951cf012cc5a4275a3a4c62ef0a719
            });
    }

    function getAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.VRFCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint96 baseFee = 0.25 ether;
        uint96 gasPriceLink = 1e9;
        vm.startBroadcast();
        VRFCoordinatorV2Mock mock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                EntranceFee: 0.08 ether,
                TimeInterval: 60,
                VRFCoordinator: address(mock),
                GasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                SubscriptionID: 0,
                CallBackGas: 500000,
                link: address(link),
                DeployerKey: DEFAULT_PRIVATE_KEY
            });
    }
}
