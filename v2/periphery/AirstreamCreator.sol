// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { ISablierV2MerkleLL } from "@sablier/v2-periphery/src/interfaces/ISablierV2MerkleLL.sol";
import { ISablierV2MerkleLockupFactory } from "@sablier/v2-periphery/src/interfaces/ISablierV2MerkleLockupFactory.sol";
import { MerkleLockup } from "@sablier/v2-periphery/src/types/DataTypes.sol";

/// @notice Example of how to create an Airstream campaign with Lockup Linear.
/// @dev This code is referenced in the docs: https://docs.sablier.com/contracts/v2/guides/create-airstream
contract AirstreamCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // See https://docs.sablier.com/contracts/v2/deployments for all deployments
    ISablierV2LockupLinear public constant LOCKUP_LINEAR =
        ISablierV2LockupLinear(0xAFb979d9afAd1aD27C5eFf4E27226E3AB9e5dCC9);
    ISablierV2MerkleLockupFactory public constant FACTORY =
        ISablierV2MerkleLockupFactory(0xEa07DdBBeA804E7fe66b958329F8Fa5cDA95Bd55);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createLLAirstream() public returns (ISablierV2MerkleLL merkleLL) {
        // Declare the base parameters for the MerkleLockup.
        MerkleLockup.ConstructorParams memory baseParams;

        baseParams.asset = DAI;
        baseParams.cancelable = true; // Whether the stream will be cancelable or not after it has been claimed
        baseParams.expiration = uint40(block.timestamp + 12 weeks); // The expiration of the campaign
        baseParams.initialAdmin = address(0xBeeF); // Admin of the merkle lockup contract
        baseParams.ipfsCID = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX"; // IPFS hash of the campaign metadata
        baseParams.merkleRoot = 0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123;
        baseParams.name = "My First Campaign"; // Unique name for the campaign
        baseParams.transferable = true; // Whether the stream will be transferable or not

        // Stream duration as required by the lockup linear.
        LockupLinear.Durations memory streamDurations;
        streamDurations = LockupLinear.Durations({
            cliff: 4 weeks, // Assets will be unlocked only after 4 weeks of claiming
            total: 52 weeks // Setting a total duration of ~1 year
         });

        // The total amount of assets you want to airdrop to your users.
        uint256 aggregateAmount = 100_000_000e18;

        // The total number of addresses you want to airdrop your tokens too.
        uint256 recipientCount = 10_000;

        // Deploy the Airstream contract. This contract will be completely owned by the campaign admin. Recipient will
        // interact with the MerkleLL contract to claim their airdrop.
        merkleLL = FACTORY.createMerkleLL(baseParams, LOCKUP_LINEAR, streamDurations, aggregateAmount, recipientCount);
    }
}
