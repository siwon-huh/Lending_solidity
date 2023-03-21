// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interface/IDreamAcademyLending.sol";
import "./interface/IPriceOracle.sol";

contract DreamAcademyLending is IDreamAcaemdyLending{

    IPriceOracle oracle;
    ERC20 usdc;
    address eth_address;
    address usdc_address;
    address owner;
    mapping(address => uint256) map_total_reserved_token_amount;
    mapping(address => mapping(address => uint256)) map_user_deposit_token_amount;
    mapping(address => mapping(address => uint256)) map_user_borrow_token_amount;

    uint256 eth_price;
    uint256 usdc_price;

    // uint256 LTV = 


    constructor(IPriceOracle _oracle, address _usdc) {
        oracle = _oracle;
        eth_address = address(0x00);
        usdc_address = _usdc;
        usdc = ERC20(usdc_address);
        owner = msg.sender;
    }

    function initializeLendingProtocol(address tokenAddress) public payable {
        map_total_reserved_token_amount[tokenAddress] = msg.value;
        usdc.transferFrom(msg.sender, address(this), msg.value);
    }

    //clear
    function deposit(address tokenAddress, uint256 amount) public payable {
        if (tokenAddress != usdc_address){
            require(msg.value != 0, "ETH deposit: msg.value should not be 0");
            require(msg.value == amount, "ETH deposit: msg.value should match amount");
            map_total_reserved_token_amount[tokenAddress] += msg.value;
            map_user_deposit_token_amount[msg.sender][tokenAddress] += msg.value;
        } else {
            require(usdc.allowance(msg.sender, address(this)) >= amount, "USDC deposit: not enough allowance");
            usdc.transferFrom(msg.sender, address(this), amount);
            map_total_reserved_token_amount[tokenAddress] += amount;
            map_user_deposit_token_amount[msg.sender][tokenAddress] += amount;
        }
    }

    function updateOracle() public{
        eth_price = oracle.getPrice(eth_address);
        usdc_price = oracle.getPrice(usdc_address);
    }

    function borrow(address tokenAddress, uint256 amount) public {
        uint256 user_eth_deposit = map_user_deposit_token_amount[msg.sender][eth_address];
        uint256 user_usdc_deposit = map_user_deposit_token_amount[msg.sender][usdc_address];

        updateOracle();

        if(tokenAddress == usdc_address){
            require(user_eth_deposit * eth_price >= amount * usdc_price, "not enough collateral");

            map_user_borrow_token_amount[msg.sender][tokenAddress] += amount;
            usdc.approve(address(this), amount);
            usdc.transferFrom(address(this), msg.sender, amount);
        } else {
            map_user_borrow_token_amount[msg.sender][tokenAddress] += amount;
            (bool sent, ) = msg.sender.call{value: amount}("");
        }
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