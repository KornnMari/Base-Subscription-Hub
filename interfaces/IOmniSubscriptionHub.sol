// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IOmniSubscriptionHub {
    function subscribeToTier(uint256 tierId) external payable;
    function createSubscriptionTier(uint256 priceWei, uint256 durationSeconds, bytes32 tierHash) external returns (uint256);
}
