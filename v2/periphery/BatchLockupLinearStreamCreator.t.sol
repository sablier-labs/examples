// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

import { BatchLockupLinearStreamCreator } from "./BatchLockupLinearStreamCreator.sol";

contract BatchLockupLinearStreamCreatorTest is Test {
    // Test contracts
    BatchLockupLinearStreamCreator internal creator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Deploy the stream creator
        creator = new BatchLockupLinearStreamCreator();

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the test user, which will be pulled by the creator contract
        deal({ token: address(creator.DAI()), to: user, give: 2 * 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contract to pull DAI tokens from the test user
        creator.DAI().approve({ spender: address(creator), amount: 2 * 1337e18 });
    }

    // Tests that creating streams works by checking the stream ids
    function test_batchCreateLockupLinearStreams() public {
        uint256 nextStreamId = creator.LOCKUP_LINEAR().nextStreamId();
        uint256[] memory actualStreamIds = creator.batchCreateLockupLinearStreams({ perStreamAmount: 1337e18 });
        uint256[] memory expectedStreamIds = new uint256[](2);
        expectedStreamIds[0] = nextStreamId;
        expectedStreamIds[1] = nextStreamId + 1;
        assertEq(actualStreamIds, expectedStreamIds);
    }
}
