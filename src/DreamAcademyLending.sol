// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interface/IDreamAcademyLending.sol";
import "./interface/IPriceOracle.sol";

contract DreamAcademyLending is IDreamAcaemdyLending{

    IPriceOracle oracle;
    ERC20 asset;
    address asset_address;
    address owner;
    mapping(address => uint256) map_reserved_token_amount;
    constructor(IPriceOracle _oracle, address _asset) {
        oracle = _oracle;
        asset_address = _asset;
        asset = ERC20(asset_address);
        owner = msg.sender;
    }

    function initializeLendingProtocol(address tokenAddress) public payable {
        map_reserved_token_amount[tokenAddress] = msg.value;
        asset.transferFrom(msg.sender, address(this), msg.value);
    }

    //clear
    function deposit(address tokenAddress, uint256 amount) public payable {
        if (tokenAddress != asset_address){
            require(msg.value != 0, "ETH deposit: msg.value should not be 0");
            require(msg.value == amount, "ETH deposit: msg.value should match amount");
        } else {
            require(asset.allowance(msg.sender, address(this)) >= amount, "USDC deposit: not enough allowance");
            asset.transferFrom(msg.sender, address(this), amount);
        }
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