// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//version 0.0.1 - 21/03/2023 13:13

import "./interface/IDreamAcademyLending.sol";
import "./interface/IPriceOracle.sol";

contract DreamAcademyLending is IDreamAcaemdyLending{

    IPriceOracle oracle;
    address asset;
    address owner;
    mapping(address => uint256) map_reserved_token_amount;
    constructor(IPriceOracle _oracle, address _asset) {
        oracle = _oracle;
        asset = _asset;
        owner = msg.sender;
    }

    function initializeLendingProtocol(address tokenAddress) public payable {
        map_reserved_token_amount[tokenAddress] = msg.value;
    }
    function deposit(address tokenAddress, uint256 amount) public payable {

    }

    function borrow(address tokenAddress, uint256 amount) public {

    }

    function repay(address tokenAddress, uint256 amount) public {

    }

    function liquidate(address user, address tokenAddress, uint256 amount) public {

    }


    function withdraw(address tokenAddress, uint256 amount) external {

    }

    function getAccruedSupplyAmount(address _asset) public returns (uint256 accruedSupplyAmount) {

    }
    receive() external payable {}
}