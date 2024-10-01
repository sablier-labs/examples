// SPDX-License-Identifier: GPL-3-0-or-later
pragma solidity >=0.8.22;

import { ISablierV2MerkleLL } from "@sablier/v2-periphery/src/interfaces/ISablierV2MerkleLL.sol";
import { Test } from "forge-std/src/Test.sol";

import { AirstreamCreator } from "./AirstreamCreator.sol";

contract AirstreamCreatorTest is Test {
    // Test contracts
    AirstreamCreator internal airstreamCreator;

    address internal user;

    function setUp() public {
        // Fork Ethereum Sepolia
        vm.createSelectFork({ urlOrAlias: "sepolia", blockNumber: 6_246_059 });

        // Deploy the airstream creator
        airstreamCreator = new AirstreamCreator();

        // Create a test user
        user = payable(makeAddr("User"));
        vm.deal({ account: user, newBalance: 1 ether });

        // Make the test user the `msg.sender` in all following calls
        vm.startPrank({ msgSender: user });
    }

    // Tests creating the airstream campaign.
    function test_CreateLLAirstream() public {
        ISablierV2MerkleLL merkleLL = airstreamCreator.createLLAirstream();

        // Assert the merkleLL contract was created with correct params
        assertEq(address(0xBeeF), merkleLL.admin(), "admin");
        assertEq(
            0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123, merkleLL.MERKLE_ROOT(), "merkle-root"
        );
    }
}
