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
    mapping(address => mapping(address => uint256)) map_user_borrow_token_index;
    mapping(address => mapping(address => uint256[])) map_user_borrow_token_blockNum;
    mapping(address => mapping(address => mapping(uint256 => uint256))) map_user_borrow_token_blockNum_amount;

    uint256 eth_price;
    uint256 usdc_price;

    uint256 loan_to_value = 50;
    uint256 current_block_number;
    uint256 block_interval;
    uint256 interest_18decimal = 1000000138819500339;



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

    function deposit(address tokenAddress, uint256 amount) public payable {

        // requirements different from eth and usdc
        if (tokenAddress != usdc_address){
            // when ETH deposit
            // deposit amount = msg.value
            // deposit amount should not be 0, and should match `amount`
            require(msg.value != 0, "ETH deposit: msg.value should not be 0");
            require(msg.value == amount, "ETH deposit: msg.value should match amount");

            // eth deposit to this contract


            // update deposit account book
            map_user_deposit_token_amount[msg.sender][tokenAddress] += msg.value;
            map_total_reserved_token_amount[tokenAddress] += msg.value;


        } else {
            // check usdc allowance
            require(usdc.allowance(msg.sender, address(this)) >= amount, "USDC deposit: not enough allowance");


            // transfer sender's deposit to me
            bool result = usdc.transferFrom(msg.sender, address(this), amount);
            require(result, "USDC deposit failed");

            // update deposit account book
            map_user_deposit_token_amount[msg.sender][tokenAddress] += amount;
            map_total_reserved_token_amount[tokenAddress] += amount;

        }
    }

    // update eth and usdc price
    function updateOracle() internal {
        eth_price = oracle.getPrice(eth_address);
        usdc_price = oracle.getPrice(usdc_address);
    }

    function updateBorrowal(address tokenAddress) public {
        current_block_number = block.number;
        for (uint i = 0; i < map_user_borrow_token_blockNum[msg.sender][tokenAddress].length; i++) {
            block_interval = current_block_number - map_user_borrow_token_blockNum[msg.sender][tokenAddress][i];
            uint user_borrowal = map_user_borrow_token_amount[msg.sender][tokenAddress];
            for (uint i = 0; i < block_interval; i++) {
                user_borrowal = user_borrowal * interest_18decimal / (10**18);
            }
            map_user_borrow_token_amount[msg.sender][tokenAddress] = user_borrowal;
            map_user_borrow_token_blockNum[msg.sender][tokenAddress][i] = current_block_number;
        }
    }

    function borrow(address tokenAddress, uint256 amount) public {
        uint256 user_eth_deposit = map_user_deposit_token_amount[msg.sender][eth_address];
        uint256 user_usdc_deposit = map_user_deposit_token_amount[msg.sender][usdc_address];
        uint256 user_eth_borrowed = map_user_borrow_token_amount[msg.sender][eth_address];
        uint256 user_usdc_borrowed = map_user_borrow_token_amount[msg.sender][usdc_address];

        updateOracle();
        updateBorrowal(eth_address);
        updateBorrowal(usdc_address);

        if(tokenAddress == usdc_address){
            // step1: check how much user can borrow now;
            // collateral's borrow amount limit: (collateral price / token_to_borrow price) * LTV
            // subtract already borrowed amount
            uint256 userUSDCLoanLimit = ((user_eth_deposit * eth_price * loan_to_value) / (usdc_price * 100)) - user_usdc_borrowed;
            require(userUSDCLoanLimit >= amount, "not enough eth collateral");

            // step2: update borrow account book
            map_user_borrow_token_amount[msg.sender][usdc_address] += amount;


            map_user_borrow_token_blockNum[msg.sender][tokenAddress].push(block.number);
            map_user_borrow_token_blockNum_amount[msg.sender][tokenAddress][block.number] = amount;


            // step3: send user the token
            usdc.approve(address(this), amount);
            usdc.transferFrom(address(this), msg.sender, amount);
        } else {
            // step1
            uint256 userETHLoanLimit = ((user_usdc_deposit * usdc_price * loan_to_value) / (eth_price * 100)) - user_eth_borrowed;
            require(userETHLoanLimit >= amount, "not enough usdc collateral");

            // step2
            map_user_borrow_token_amount[msg.sender][eth_address] += amount;

            map_user_borrow_token_blockNum[msg.sender][tokenAddress].push(block.number);
            map_user_borrow_token_blockNum_amount[msg.sender][tokenAddress][block.number] = amount;

            // step3
            (bool sent, ) = (msg.sender).call{value: amount}("");
        }
    }

    // pay back one's borrowal. it can be partial
    function repay(address tokenAddress, uint256 amount) public {
        updateOracle();
        updateBorrowal(eth_address);
        updateBorrowal(usdc_address);

        if (tokenAddress == eth_address){
            map_user_borrow_token_amount[msg.sender][eth_address] -= amount;
        } else {
            map_user_borrow_token_amount[msg.sender][usdc_address] -= amount;
        }
    }

    function liquidate(address user, address tokenAddress, uint256 amount) public {

    }


    function withdraw(address tokenAddress, uint256 amount) external {

    }

    function getAccruedSupplyAmount(address tokenAddress) public returns (uint256 accruedSupplyAmount) {

    }
    receive() external payable {}
}