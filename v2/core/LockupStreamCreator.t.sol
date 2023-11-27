// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { Test } from "forge-std/Test.sol";

import { LockupDynamicStreamCreator } from "./LockupDynamicStreamCreator.sol";
import { LockupLinearStreamCreator } from "./LockupLinearStreamCreator.sol";

contract LockupLinearStreamCreatorTest is Test {
    // Test contracts
    LockupDynamicStreamCreator internal dynamicCreator;
    LockupLinearStreamCreator internal linearCreator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Deploy the stream creators
        dynamicCreator = new LockupDynamicStreamCreator();
        linearCreator = new LockupLinearStreamCreator();

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the test user, which will be pulled by the creator contracts
        deal({ token: address(linearCreator.DAI()), to: user, give: 2 * 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contracts to pull DAI tokens from the test user
        linearCreator.DAI().approve({ spender: address(dynamicCreator), amount: 1337e18 });
        linearCreator.DAI().approve({ spender: address(linearCreator), amount: 1337e18 });
    }

    // Tests that creating streams works by checking the stream ids
    function test_LockupDynamicStreamCreator() public {
        uint128 amount0 = 1337e18 / 2;
        uint128 amount1 = 1337e18 - amount0;

        uint256 expectedStreamId = dynamicCreator.lockupDynamic().nextStreamId();
        uint256 actualStreamId = dynamicCreator.createStream(amount0, amount1);
        assertEq(actualStreamId, expectedStreamId);
    }

    // Tests that creating streams works by checking the stream ids
    function test_LockupLinearStreamCreator() public {
        uint256 expectedStreamId = linearCreator.lockupLinear().nextStreamId();
        uint256 actualStreamId = linearCreator.createStream({ totalAmount: 1337e18 });
        assertEq(actualStreamId, expectedStreamId);
    }
}
