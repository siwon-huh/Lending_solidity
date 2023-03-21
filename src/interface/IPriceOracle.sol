// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//version 0.0.1 - 21/03/2023 13:13


interface IPriceOracle {
    function getPrice(address) external view returns (uint256);
    function setPrice(address, uint256) external;
}