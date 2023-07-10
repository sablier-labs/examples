// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { ArrayBuilder } from "@sablier/v2-periphery-test/utils/ArrayBuilder.sol";

import { Test } from "forge-std/Test.sol";

import { BatchLockupLinearStreamCreator } from "./BatchLockupLinearStreamCreator.sol";

contract BatchLockupLinearStreamCreatorTest is Test {
    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    address internal constant SABLIER_ADDRESS = address(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);
    address internal constant SABLIER_TARGET_ADDRESS = address(0x297b43aE44660cA7826ef92D8353324C018573Ef);

    // Test contracts
    BatchLockupLinearStreamCreator internal creator;
    ISablierV2LockupLinear internal lockupLinear;
    ISablierV2ProxyTarget internal proxyTarget;
    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Load the Sablier contract from Ethereum Mainnet
        lockupLinear = ISablierV2LockupLinear(SABLIER_ADDRESS);
        proxyTarget = ISablierV2ProxyTarget(SABLIER_TARGET_ADDRESS);

        // Deploy the stream creator
        creator = new BatchLockupLinearStreamCreator(lockupLinear, proxyTarget);

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Mint some DAI tokens to the creator contract using the `deal` cheatcode
        deal({ token: address(creator.DAI()), to: user, give: 2 * 1337e18 });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });

        // Approve the creator contract to pull DAI tokens from the test user
        creator.DAI().approve({ spender: address(creator), amount: 2 * 1337e18 });
    }

    // Tests that creating streams works by checking the stream ids
    function test_batchCreateLockupLinearStream() public {
        uint256 nextStreamId = lockupLinear.nextStreamId();
        uint256[] memory expectedStreamIds = ArrayBuilder.fillStreamIds(nextStreamId, 2);
        uint256[] memory actualStreamIds = creator.batchCreateLockupLinearStream({ perStreamAmount: 1337e18 });
        assertEq(actualStreamIds, expectedStreamIds);
    }
}
