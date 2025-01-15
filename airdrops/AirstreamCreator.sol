// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ISablierLockup } from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import { ISablierMerkleLL } from "@sablier/airdrops/src/interfaces/ISablierMerkleLL.sol";
import { ISablierMerkleFactory } from "@sablier/airdrops/src/interfaces/ISablierMerkleFactory.sol";
import { MerkleBase, MerkleLL } from "@sablier/airdrops/src/types/DataTypes.sol";

/// @notice Example of how to create an Airstream campaign with Lockup Linear.
/// @dev This code is referenced in the docs: https://docs.sablier.com/guides/lockup/examples/create-airstream
contract AirstreamCreator {
    // Sepolia addresses
    IERC20 public constant DAI = IERC20(0x68194a729C2450ad26072b3D33ADaCbcef39D574);
    // See https://docs.sablier.com/guides/lockup/deployments for all deployments
    ISablierLockup public constant LOCKUP = ISablierLockup(0xC2Da366fD67423b500cDF4712BdB41d0995b0794);
    ISablierMerkleFactory public constant FACTORY = ISablierMerkleFactory(0x4ECd5A688b0365e61c1a764E8BF96A7C5dF5d35F);

    /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
    function createLLAirstream() public returns (ISablierMerkleLL merkleLL) {
        // Declare the base parameters for the MerkleBase.
        MerkleBase.ConstructorParams memory baseParams;

        baseParams.token = DAI;
        baseParams.expiration = uint40(block.timestamp + 12 weeks); // The expiration of the campaign
        baseParams.initialAdmin = address(0xBeeF); // Admin of the merkle lockup contract
        baseParams.ipfsCID = "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX"; // IPFS hash of the campaign metadata
        baseParams.merkleRoot = 0x4e07408562bedb8b60ce05c1decfe3ad16b722309875f562c03d02d7aaacb123;
        baseParams.campaignName = "My First Campaign"; // Unique campaign name for the campaign
        baseParams.shape = "A custom stream shape"; // Unique campaign name for the campaign

        // The total amount of tokens you want to airdrop to your users.
        uint256 aggregateAmount = 100_000_000e18;

        // The total number of addresses you want to airdrop your tokens too.
        uint256 recipientCount = 10_000;

        // Deploy the Airstream contract. This contract will be completely owned by the campaign admin. Recipient will
        // interact with the MerkleLL contract to claim their airdrop.
        merkleLL = FACTORY.createMerkleLL({
            baseParams: baseParams,
            lockup: LOCKUP,
            cancelable: false,
            transferable: true,
            schedule: MerkleLL.Schedule({
                startTime: 0, // i.e. block.timestamp
                startPercentage: ud2x18(0.01e18),
                cliffDuration: 30 days,
                cliffPercentage: ud2x18(0.01e18),
                totalDuration: 90 days
            }),
            aggregateAmount: aggregateAmount,
            recipientCount: recipientCount
        });
    }
}
