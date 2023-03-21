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
    mapping(address => mapping(address => uint256[])) map_user_deposit_token_blockNum;

    mapping(address => mapping(address => uint256)) map_user_borrow_token_amount;
    mapping(address => mapping(address => uint256[])) map_user_borrow_token_blockNum;

    uint256 eth_price;
    uint256 usdc_price;

    uint256 loan_to_value = 50;
    uint256 current_block_number;
    uint256 block_interval;
    uint256 interest_18decimal = 1000000138819500339;
    // uint256 interest_18decimal = 1000190000000000000;

    uint256 liquidation_thershold = 75;



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
            map_user_deposit_token_blockNum[msg.sender][tokenAddress].push(block.number);


        } else {
            // check usdc allowance
            require(usdc.allowance(msg.sender, address(this)) >= amount, "USDC deposit: not enough allowance");


            // transfer sender's deposit to me
            bool result = usdc.transferFrom(msg.sender, address(this), amount);
            require(result, "USDC deposit failed");

            // update deposit account book
            map_user_deposit_token_amount[msg.sender][tokenAddress] += amount;
            map_total_reserved_token_amount[tokenAddress] += amount;
            map_user_deposit_token_blockNum[msg.sender][tokenAddress].push(block.number);

        }
    }

    // update eth and usdc price
    function updateOracle() internal {
        eth_price = oracle.getPrice(eth_address);
        usdc_price = oracle.getPrice(usdc_address);
    }

    function updateBorrowal() public {
        current_block_number = block.number;
        for (uint i = 0; i < map_user_borrow_token_blockNum[msg.sender][usdc_address].length; i++) {
            block_interval = current_block_number - map_user_borrow_token_blockNum[msg.sender][usdc_address][i];
            uint user_borrowal = map_user_borrow_token_amount[msg.sender][usdc_address];
            for (uint j = 0; j < block_interval; j++) {
                user_borrowal = user_borrowal * interest_18decimal / (10**18);
            }
            map_user_borrow_token_amount[msg.sender][usdc_address] = user_borrowal;
            map_user_borrow_token_blockNum[msg.sender][usdc_address][i] = current_block_number;
        }
    }

    function borrow(address tokenAddress, uint256 amount) public {
        require(tokenAddress == usdc_address, "no borrow option of ether");
        uint256 user_eth_deposit = map_user_deposit_token_amount[msg.sender][eth_address];
        uint256 user_usdc_deposit = map_user_deposit_token_amount[msg.sender][usdc_address];

        uint256 user_usdc_borrowed = map_user_borrow_token_amount[msg.sender][usdc_address];

        updateOracle();
        updateBorrowal();

        // step1: check how much user can borrow now;
        // collateral's borrow amount limit: (collateral price / token_to_borrow price) * LTV
        // subtract already borrowed amount
        uint256 userUSDCLoanLimit = ((user_eth_deposit * eth_price * loan_to_value) / (usdc_price * 100)) - user_usdc_borrowed;
        require(userUSDCLoanLimit >= amount, "not enough eth collateral");

        // step2: update borrow account book
        map_user_borrow_token_amount[msg.sender][usdc_address] += amount;
        map_user_borrow_token_blockNum[msg.sender][tokenAddress].push(block.number);


        // step3: send user the token
        usdc.approve(address(this), amount);
        usdc.transferFrom(address(this), msg.sender, amount);
        
    }

    // pay back one's borrowal. it can be partial
    function repay(address tokenAddress, uint256 amount) public {
        updateOracle();
        updateBorrowal();

        map_user_borrow_token_amount[msg.sender][usdc_address] -= amount;
    }

    function liquidate(address user, address tokenAddress, uint256 amount) public {

    }


    function withdraw(address tokenAddress, uint256 amount) public {
        updateOracle();
        updateBorrowal();
        uint256 user_eth_deposit = map_user_deposit_token_amount[msg.sender][eth_address];
        uint256 user_usdc_deposit = map_user_deposit_token_amount[msg.sender][usdc_address];

        uint256 user_usdc_borrowed = map_user_borrow_token_amount[msg.sender][usdc_address];

        // usdc_price끼리 묶으면 underflow를 유발할 수 있음ㅜㅜ
        require(eth_price * user_eth_deposit + usdc_price * user_usdc_deposit >= usdc_price * user_usdc_borrowed, "not enough deposit");
        uint256 user_total_price = eth_price * user_eth_deposit + usdc_price * user_usdc_deposit - usdc_price * user_usdc_borrowed;

        if (tokenAddress == eth_address){
            require(user_total_price >= amount * eth_price, "not enough balance");
            require((user_total_price - amount * eth_price) * 100 <= liquidation_thershold * user_total_price, "cannot withdraw over liquidity threshold");
        } else {
            require(user_total_price >= amount * usdc_price, "not enough balance");
            require((user_total_price - amount * usdc_price) * 100 <= liquidation_thershold * user_total_price, "cannot withdraw over liquidity threshold");
        }

        
        map_user_deposit_token_amount[msg.sender][tokenAddress] -= amount;
        if (tokenAddress == eth_address){
            (bool sent, ) = (msg.sender).call{value: amount}("");
        } else {
            usdc.transferFrom(address(this), msg.sender, amount);
        }
    }

    function getAccruedSupplyAmount(address tokenAddress) public returns (uint256 accruedSupplyAmount) {

    }
    receive() external payable {}
}