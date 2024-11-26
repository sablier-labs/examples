// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Test } from "forge-std/src/Test.sol";

import { FlowStreamCreator } from "./FlowStreamCreator.sol";

import { IFlowNFTDescriptor, SablierFlow } from "@sablier/flow/src/SablierFlow.sol";

contract FlowStreamCreator_Test is Test {
    FlowStreamCreator internal streamCreator;
    SablierFlow internal flow;
    address internal user;

    function setUp() external {
        // Fork Ethereum Sepolia
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 6_240_816 });

        // Deploy a SablierFlow contract
        flow = new SablierFlow({ initialAdmin: address(this), initialNFTDescriptor: IFlowNFTDescriptor(address(this)) });

        // Deploy the FlowStreamCreator contract
        streamCreator = new FlowStreamCreator(flow);

        user = makeAddr("User");

        // Mint some DAI tokens to the test user, which will be pulled by the creator contract
        deal({ token: address(streamCreator.USDC()), to: user, give: 1_000_000e6 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the streamCreator contract to pull USDC tokens from the test user
        streamCreator.USDC().approve({ spender: address(streamCreator), value: 1_000_000e6 });
    }

    function test_CreateStream_1K_PerMonth() external {
        uint256 expectedStreamId = flow.nextStreamId();

        uint256 actualStreamId = streamCreator.createStream_1K_PerMonth();
        assertEq(actualStreamId, expectedStreamId);

        // Warp slightly over 30 days so that the debt accumulated is slightly over 1000 USDC.
        vm.warp({ newTimestamp: block.timestamp + 30 days + 1 seconds });

        assertGe(flow.totalDebtOf(actualStreamId), 1000e6);
    }

    function test_CreateStream_1M_PerYear() external {
        uint256 expectedStreamId = flow.nextStreamId();

        uint256 actualStreamId = streamCreator.createStream_1M_PerYear();
        assertEq(actualStreamId, expectedStreamId);

        // Warp slightly over 365 days so that the debt accumulated is slightly over 1M USDC.
        vm.warp({ newTimestamp: block.timestamp + 365 days + 1 seconds });

        assertGe(flow.totalDebtOf(actualStreamId), 1_000_000e6);
    }
}
