// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Test } from "forge-std/src/Test.sol";

import { FlowBatchable } from "./FlowBatchable.sol";

import { IFlowNFTDescriptor, SablierFlow } from "@sablier/flow/src/SablierFlow.sol";

contract FlowBatchable_Test is Test {
    FlowBatchable internal batchable;
    SablierFlow internal flow;
    address internal user;

    function setUp() external {
        // Fork Ethereum Sepolia
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 6_240_816 });

        // Deploy a SablierFlow contract
        flow = new SablierFlow({ initialAdmin: address(this), initialNFTDescriptor: IFlowNFTDescriptor(address(this)) });

        // Deploy the batchable contract
        batchable = new FlowBatchable(flow);

        user = makeAddr("User");

        // Mint some DAI tokens to the test user, which will be pulled by the creator contract
        deal({ token: address(batchable.USDC()), to: user, give: 1_000_000e6 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the batchable contract to pull USDC tokens from the test user
        batchable.USDC().approve({ spender: address(batchable), value: 1_000_000e6 });
    }

    function test_CreateMultiple() external {
        uint256 nextStreamIdBefore = flow.nextStreamId();

        uint256[] memory actualStreamIds = batchable.createMultiple();
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = nextStreamIdBefore;
        expectedStreamIds[1] = nextStreamIdBefore + 1;

        assertEq(actualStreamIds, expectedStreamIds);
    }

    function test_CreateAndDepositViaBroker() external {
        uint256 nextStreamIdBefore = flow.nextStreamId();

        uint256[] memory actualStreamIds = batchable.createMultipleAndDepositViaBroker();
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = nextStreamIdBefore;
        expectedStreamIds[1] = nextStreamIdBefore + 1;

        assertEq(actualStreamIds, expectedStreamIds);
    }
}