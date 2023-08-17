// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";

import { Test } from "forge-std/Test.sol";

import { LockupLinearStreamCreator } from "./LockupLinearStreamCreator.sol";

contract LockupLinearStreamCreatorTest is Test {
    // Get the latest deployment address from the docs: https://docs.sablier.com/contracts/v2/deployments
    address internal constant SABLIER_ADDRESS = address(0xB10daee1FCF62243aE27776D7a92D39dC8740f95);

    // Test contracts
    LockupLinearStreamCreator internal creator;
    ISablierV2LockupLinear internal lockupLinear;
    address internal user;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Load the Sablier contract from Ethereum Mainnet
        lockupLinear = ISablierV2LockupLinear(SABLIER_ADDRESS);

        // Deploy the stream creator
        creator = new LockupLinearStreamCreator(lockupLinear);

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

    // Tests that creating streams works by checking the stream ids
    function test_CreateLockupLinearStream() public {
        uint256 expectedStreamId = lockupLinear.nextStreamId();
        uint256 actualStreamId = creator.createLockupLinearStream({ totalAmount: 1337e18 });
        assertEq(actualStreamId, expectedStreamId);
    }
}
