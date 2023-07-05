// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.13;

import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/interfaces/ISablierV2ProxyTarget.sol";
import { ArrayBuilder } from "@sablier/v2-periphery-test/utils/ArrayBuilder.sol";
import { Test } from "forge-std/Test.sol";

import { LockupLinearBatchStreamCreator } from "./LockupLinearBatchStreamCreator.sol";

contract LockupLinearBatchCreateTest is Test {
    // Get the latest deployment address from the docs
    // https://docs.sablier.com/contracts/v2/addresses
    address internal constant SABLIER_ADDRESS = address(0xcafe);
    address internal constant SABLIER_TARGET_ADDRESS = address(0xbeef);

    // Test contracts
    LockupLinearBatchCreate internal creator;
    ISablierV2LockupLinear internal sablier;
    ISablierV2ProxyTarget internal sablierTarget;

    function setUp() public {
        // Fork Ethereum Mainnet
        vm.createSelectFork({ urlOrAlias: "mainnet" });

        // Load the Sablier contract from Ethereum Mainnet
        sablier = ISablierV2LockupLinear(SABLIER_ADDRESS);
        sablierTarget = ISablierV2ProxyTarget(SABLIER_TARGET_ADDRESS);

        // Deploy the stream creator
        creator = new LockupLinearBatchStreamCreator(sablier, sablierTarget);

        // Mint some DAI tokens to the creator contract using the `deal` cheatcode
        deal({ token: address(creator.DAI()), to: address(creator), give: 1337e18 });
    }

    // Tests that creating streams works by checking the stream ids
    function test_batchCreateLockupLinearStream() public {
        uint256 nextStreamId = sablier.nextStreamId();
        uint256[] memory expectedStreamIds = ArrayBuilder.fillStreamIds(nextStreamId, 10);
        uint256[] memory actualStreamIds =
            creator.batchCreateLockupLinearStream({ perStreamAmount: 1337e18, batchSize: 10, signature: "" });
        assertEq(actualStreamIds, expectedStreamIds);
    }
}
