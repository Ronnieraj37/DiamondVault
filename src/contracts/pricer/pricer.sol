// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import { AggregatorV3Interface } from '../common/interfaces/IAggregatorV3Interface.sol';

contract Pricer {
    // Custom Errors
    error Pricer__NotOwner();

    address public owner;

    mapping(address => AggregatorV3Interface) private priceFeeds;

    event PriceFeedUpdated(address indexed asset, address indexed feedAddress);

    /// @notice Modifier to restrict access to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert Pricer__NotOwner();
        _;
    }

    /// @notice Initializes the contract and sets the deployer as the owner.
    constructor() {
        owner = msg.sender;
    }

    /// @notice Gets the address of the price feed for a specific asset.
    /// @param asset The address of the asset.
    /// @return The address of the price feed for the asset.
    function getPriceFeedAddress(address asset) external view returns (address) {
        return address(priceFeeds[asset]);
    }

    /// @notice Sets the price feed address for a specific asset.
    /// @param asset The address of the asset.
    /// @param feedAddress The address of the price feed contract.
    function setPriceFeed(address asset, address feedAddress) external onlyOwner {
        priceFeeds[asset] = AggregatorV3Interface(feedAddress);
        emit PriceFeedUpdated(asset, feedAddress);
    }

    /// @notice Retrieves the latest price for a specific asset.
    /// @param asset The address of the asset.
    /// @return The latest price of the asset.
    /// @dev Reverts if the price feed is not set for the asset.
    function getLatestPrice(address asset) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[asset];
        require(address(priceFeed) != address(0), 'Price feed not set for this asset');

        (
            /* uint80 roundID */
            ,
            int price,
            /* uint startedAt */
            ,
            /* uint timeStamp */
            ,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return price;
    }

    /// @notice Calculates the base value of an asset based on its latest price.
    /// @param asset The address of the asset.
    /// @param amount The amount of the asset.
    /// @return The base value of the asset.
    /// @dev Reverts if the latest price is invalid (non-positive).
    function getAssetBaseValue(address asset, uint amount) external view returns (uint) {
        int latestPrice = getLatestPrice(asset);
        require(latestPrice > 0, 'Invalid price');

        uint baseValue = uint(latestPrice) * amount;

        return baseValue;
    }
}