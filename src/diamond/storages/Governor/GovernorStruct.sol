// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct DepositVaultMetadata {
    address asset;
    bool supported;
    bool paused;
    bool stakingPaused;
    uint minDepositAmount;
    uint maxDepositAmount;
}

struct BorrowVaultMetadata {
    address asset;
    bool supported;
    bool paused;
    uint minBorrowAmount;
    uint maxBorrowAmount;
}

struct AssetMetadata {
    address rToken;
    address dToken;
    uint empiricKey;
}

struct SecondaryMarket {
    bool supported;
    bool active;
}
