// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

import { LockupDynamicCurvesCreator } from "./LockupDynamicCurvesCreator.sol";

contract LockupDynamicCurvesCreatorTest is Test {
    // Test contracts
    LockupDynamicCurvesCreator internal creator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Deploy the stream creator
        creator = new LockupDynamicCurvesCreator();

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the test user, which will be pulled by the creator contract
        deal({ token: address(creator.DAI()), to: user, give: 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contract to pull DAI tokens from the test user
        creator.DAI().approve({ spender: address(creator), amount: 1337e18 });
    }

    function test_CreateStream_Exponential() public {
        uint256 expectedStreamId = creator.LOCKUP_DYNAMIC().nextStreamId();
        uint256 actualStreamId = creator.createStream_Exponential();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        // Warp 50 days into the future, i.e. half way of the stream duration.
        vm.warp({ newTimestamp: block.timestamp + 50 days });

        uint128 actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 1.5625e18; // 0.5^{6} * 100 + 0
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_ExponentialCliff() public {
        uint256 expectedStreamId = creator.LOCKUP_DYNAMIC().nextStreamId();
        uint256 actualStreamId = creator.createStream_ExponentialCliff();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 currentTime = block.timestamp;

        // Warp 50 days into the future, i.e. half way of the stream duration (unlock moment).
        vm.warp({ newTimestamp: currentTime + 50 days });

        uint128 actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 20e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 75 days into the future, i.e. half way of the stream's last segment.
        vm.warp({ newTimestamp: currentTime + 75 days });

        actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 21.25e18; // 0.5^{6} * 80 + 20
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_UnlockInSteps() public {
        uint256 expectedStreamId = creator.LOCKUP_DYNAMIC().nextStreamId();
        uint256 actualStreamId = creator.createStream_UnlockInSteps();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 actualStreamedAmount;
        uint256 expectedStreamedAmount;

        for (uint256 i = 0; i < 10; ++i) {
            vm.warp({ newTimestamp: block.timestamp + 10 days - 1 seconds });
            actualStreamedAmount = creator.LOCKUP_DYNAMIC().streamedAmountOf(actualStreamId);
            assertEq(actualStreamedAmount, expectedStreamedAmount);
            expectedStreamedAmount += 10e18;
            vm.warp({ newTimestamp: block.timestamp + 1 seconds });
        }
    }
}
