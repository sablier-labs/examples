// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierMerkleInstant } from "@sablier/airdrops/src/interfaces/ISablierMerkleInstant.sol";
import { ISablierMerkleLL } from "@sablier/airdrops/src/interfaces/ISablierMerkleLL.sol";
import { ISablierMerkleLT } from "@sablier/airdrops/src/interfaces/ISablierMerkleLT.sol";
import { ISablierMerkleFactory } from "@sablier/airdrops/src/interfaces/ISablierMerkleFactory.sol";
import { MerkleBase, MerkleLL, MerkleLT } from "@sablier/airdrops/src/types/DataTypes.sol";

/// @notice Example of how to create Merkle airdrop campaigns.
/// @dev This code is referenced in the docs: https://docs.sablier.com/guides/lockup/examples/create-airstream
contract MerkleCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);

    // See https://docs.sablier.com/guides/lockup/deployments for all deployments
    ISablierMerkleFactory public constant FACTORY = ISablierMerkleFactory(0x4ECd5A688b0365e61c1a764E8BF96A7C5dF5d35F);
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);

    function createMerkleInstant() public virtual returns (ISablierMerkleInstant merkleInstant) {
        // Declare the constructor parameter of MerkleBase.
        MerkleBase.ConstructorParams memory baseParams;

        // Set the base parameters.
        baseParams.token = DAI;
        baseParams.expiration = uint40(block.timestamp + 12 weeks); // The expiration of the campaign
        baseParams.initialAdmin = address(0xBeeF); // Admin of the merkle lockup contract
        baseParams.ipfsCID = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX"; // IPFS hash of the campaign metadata
        baseParams.merkleRoot = 0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123;
        baseParams.campaignName = "My First Campaign"; // Unique campaign name
        baseParams.shape = "A custom stream shape"; // Stream shape name for visualization in the UI

        // The total amount of tokens you want to airdrop to your users.
        uint256 aggregateAmount = 100_000_000e18;

        // The total number of addresses you want to airdrop your tokens to.
        uint256 recipientCount = 10_000;

        // Deploy the MerkleInstant campaign contract. The deployed contract will be completely owned by the campaign
        // admin. Recipients will interact with the deployed contract to claim their airdrop.
        merkleInstant = FACTORY.createMerkleInstant(baseParams, aggregateAmount, recipientCount);
    }

    function createMerkleLL() public returns (ISablierMerkleLL merkleLL) {
        // Declare the constructor parameter of MerkleBase.
        MerkleBase.ConstructorParams memory baseParams;

        // Set the base parameters.
        baseParams.token = DAI;
        baseParams.expiration = uint40(block.timestamp + 12 weeks); // The expiration of the campaign
        baseParams.initialAdmin = address(0xBeeF); // Admin of the merkle lockup contract
        baseParams.ipfsCID = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX"; // IPFS hash of the campaign metadata
        baseParams.merkleRoot = 0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123;
        baseParams.campaignName = "My First Campaign"; // Unique campaign name
        baseParams.shape = "A custom stream shape"; // Stream shape name for visualization in the UI

        // The total amount of tokens you want to airdrop to your users.
        uint256 aggregateAmount = 100_000_000e18;

        // The total number of addresses you want to airdrop your tokens to.
        uint256 recipientCount = 10_000;

        // Set the schedule of the stream that will be created from this campaign.
        MerkleLL.Schedule memory schedule = MerkleLL.Schedule({
            startTime: 0, // i.e. block.timestamp
            startPercentage: ud2x18(0.01e18),
            cliffDuration: 30 days,
            cliffPercentage: ud2x18(0.01e18),
            totalDuration: 90 days
        });

        // Deploy the MerkleLL campaign contract. The deployed contract will be completely owned by the campaign admin.
        // Recipients will interact with the deployed contract to claim their airdrop.
        merkleLL = FACTORY.createMerkleLL({
            baseParams: baseParams,
            lockup: LOCKUP,
            cancelable: false,
            transferable: true,
            schedule: schedule,
            aggregateAmount: aggregateAmount,
            recipientCount: recipientCount
        });
    }

    function createMerkleLT() public returns (ISablierMerkleLT merkleLT) {
        // Prepare the constructor parameters.
        MerkleBase.ConstructorParams memory baseParams;

        // Set the base parameters.
        baseParams.token = DAI;
        baseParams.expiration = uint40(block.timestamp + 12 weeks); // The expiration of the campaign
        baseParams.initialAdmin = address(0xBeeF); // Admin of the merkle lockup contract
        baseParams.ipfsCID = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX"; // IPFS hash of the campaign metadata
        baseParams.merkleRoot = 0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123;
        baseParams.campaignName = "My First Campaign"; // Unique campaign name
        baseParams.shape = "A custom stream shape"; // Stream shape name for visualization in the UI

        // The tranches with their unlock percentages and durations.
        MerkleLT.TrancheWithPercentage[] memory tranchesWithPercentages = new MerkleLT.TrancheWithPercentage[](2);
        tranchesWithPercentages[0] =
            MerkleLT.TrancheWithPercentage({ unlockPercentage: ud2x18(0.5e18), duration: 30 days });
        tranchesWithPercentages[1] =
            MerkleLT.TrancheWithPercentage({ unlockPercentage: ud2x18(0.5e18), duration: 60 days });

        // The total amount of tokens you want to airdrop to your users.
        uint256 aggregateAmount = 100_000_000e18;

        // The total number of addresses you want to airdrop your tokens to.
        uint256 recipientCount = 10_000;

        // Deploy the MerkleLT campaign contract. The deployed contract will be completely owned by the campaign admin.
        // Recipients will interact with the deployed contract to claim their airdrop.
        merkleLT = FACTORY.createMerkleLT({
            baseParams: baseParams,
            lockup: LOCKUP,
            cancelable: true,
            transferable: true,
            streamStartTime: 0, // i.e. block.timestamp
            tranchesWithPercentages: tranchesWithPercentages,
            aggregateAmount: aggregateAmount,
            recipientCount: recipientCount
        });
    }
}
