// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.22;

import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { Test } from "forge-std/src/Test.sol";

import { LockupDynamicCurvesCreator } from "./LockupDynamicCurvesCreator.sol";

contract LockupDynamicCurvesCreatorTest is Test {
    // Test contracts
    LockupDynamicCurvesCreator internal creator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Sepolia
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 7_497_776 });

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
        creator.DAI().approve({ spender: address(creator), value: 1337e18 });
    }

    function test_CreateStream_Exponential() public {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_Exponential();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        // Warp 50 days into the future, i.e. half way of the stream duration.
        vm.warp({ newTimestamp: block.timestamp + 50 days });

        uint128 actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 1.5625e18; // 0.5^{6} * 100 + 0
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_ExponentialCliff() public {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_ExponentialCliff();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 blockTimestamp = block.timestamp;

        // Warp 50 days into the future, i.e. half way of the stream duration (unlock moment).
        vm.warp({ newTimestamp: blockTimestamp + 50 days });

        uint128 actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 20e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 75 days into the future, i.e. half way of the stream's last segment.
        vm.warp({ newTimestamp: blockTimestamp + 75 days });

        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 21.25e18; // 0.5^{6} * 80 + 20
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_UnlockInSteps() public {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_UnlockInSteps();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 actualStreamedAmount;
        uint256 expectedStreamedAmount;

        for (uint256 i = 0; i < 4; ++i) {
            vm.warp({ newTimestamp: block.timestamp + 25 days - 1 seconds });
            actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
            assertEq(actualStreamedAmount, expectedStreamedAmount);
            expectedStreamedAmount += 25e18;
            vm.warp({ newTimestamp: block.timestamp + 1 seconds });
        }
    }

    function test_CreateStream_MonthlyUnlocks() public {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_MonthlyUnlocks();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 actualStreamedAmount;
        uint256 expectedStreamedAmount;

        for (uint256 i = 0; i < 12; ++i) {
            vm.warp({ newTimestamp: block.timestamp + 30 days - 1 seconds });
            actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);

            assertEq(actualStreamedAmount, expectedStreamedAmount);
            expectedStreamedAmount += 10e18;
            vm.warp({ newTimestamp: block.timestamp + 1 seconds });
        }
    }

    function test_CreateStream_Timelock() external {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_Timelock();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 blockTimestamp = block.timestamp;

        // Warp 90 days - 1 second into the future, i.e. exactly 1 second before unlock.
        vm.warp({ newTimestamp: blockTimestamp + 90 days - 1 seconds });

        uint128 actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 0;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 90 days into the future, i.e. the unlock moment.
        vm.warp({ newTimestamp: blockTimestamp + 90 days });

        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 100e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_UnlockLinear() external {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_UnlockLinear();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 blockTimestamp = block.timestamp;

        // Warp 1 second into the future, i.e. the initial unlock.
        vm.warp({ newTimestamp: blockTimestamp + 1 seconds });

        uint128 actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 25e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 50 days into the second segment (4320000 seconds).
        vm.warp({ newTimestamp: blockTimestamp + 50 days + 1 seconds });

        // total duration of segment: 8639999 seconds (100 days - 1 second)
        // amount to be stream in the current segment: 75e18

        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 62.87878787878787875e18; // (0.500000057870377068)^{1} * 75 + 25
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }

    function test_CreateStream_UnlockCliffLinear() external {
        uint256 expectedStreamId = creator.LOCKUP().nextStreamId();
        uint256 actualStreamId = creator.createStream_UnlockCliffLinear();

        // Assert that the stream has been created.
        assertEq(actualStreamId, expectedStreamId);

        uint256 blockTimestamp = block.timestamp;

        // Warp 1 second into the future, i.e. the initial unlock.
        vm.warp({ newTimestamp: blockTimestamp + 1 seconds });

        uint128 actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        uint128 expectedStreamedAmount = 25e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 50 days into the future.
        vm.warp({ newTimestamp: blockTimestamp + 50 days });

        // Assert that the streamed amount has remained the same.
        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 50 days plus a second into the future, i.e. after the cliff unlock.
        vm.warp({ newTimestamp: blockTimestamp + 50 days + 1 seconds });

        // Assert that the streamed amount has increased by the cliff amount.
        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 50e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount);

        // Warp 75 days plus a second into the future.
        vm.warp({ newTimestamp: blockTimestamp + 75 days + 1 });

        actualStreamedAmount = creator.LOCKUP().streamedAmountOf(actualStreamId);
        expectedStreamedAmount = 75e18; // (0.50)^{1} * 50 + 50
        assertEq(actualStreamedAmount, expectedStreamedAmount);
    }
}
