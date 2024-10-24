// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPricer {
    function setPriceFeed(address asset, address feedAddress) external;
    function getPriceFeedAddress(address asset) external view returns (address);
    function getLatestPrice(address asset) external view returns (int);
    function getAssetBaseValue(address asset, uint amount) external view returns (uint);
}
