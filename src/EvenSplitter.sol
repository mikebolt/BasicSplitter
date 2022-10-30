// SPDX-License-Identifier: GPL-3.0

// Author: https://github.com/mikebolt
// This software is provided with NO WARRANTY.

pragma solidity >=0.7.0 <0.9.0;

import "./openzeppelin/IERC20.sol";

// ERROR_FOR_ZERO_VALUE:
// Keep this line to revert and return an error when there is no balance in ether or tokens.
// Remove it to leave these errors out of the contract and reduce gas costs slightly,
//   but waste some gas when the contract is used incorrectly.
// If this is disabled then trying to split zero value is inconsequential but it wastes gas.
// The splitAndWithdrawTokens function does not use errors, so instead it will skip calling
// the transfer function for the current token which will save some gas, but not all.
// The client should be responsible for checking token balances before putting them in
// the list of addresses sent to the withdraw function. It's a good idea to also
// check that the balance is worth significantly more than the gas fee.
#define ERROR_FOR_ZERO_VALUE

// SPLIT_ETHER:
// Split ether using the receive() function. Remove to save some deployment gas cost.
#define SPLIT_ETHER

// SPLIT_TOKENS:
// Split tokens when the splitAndWithdrawTokens function is called. Remove to save some deployment gas cost.
#define SPLIT_TOKENS

// (one of the two SPLIT_* defines must be included, otherwise this contract will do nothing)

// ENABLE_SPLIT_UNSENT_ETHER:
// Keep this definition to include the splitAndWithdrawUnsentEther function.
// This function will cost more gas than the default receive() because it needs to check
// errors after sending ether to each address then repeat the process.
// This will increase the deployment cost.
#define ENABLE_SPLIT_UNSENT_ETHER

// ENABLE_WITHDRAW_SINGLE_TOKEN:
// If the users of this contract want to withdraw only one token instead of a list of tokens,
// then it is *slightly* more gas efficient to use a function which only accepts a single
// token address instead of a list of them. This increases deployment cost.
#define ENABLE_WITHDRAW_SINGLE_TOKEN

/**
 * @title EvenSplitter
 * @dev Send this contract ETH or ERC20 tokens to guarantee that it will be split evenly
 *   between the recipient addresses. Anyone is able to pay the gas fee to call
 *   splitAndWithdrawToken or splitAndWithdrawTokens without negative consequence.
 */
contract EvenSplitter {

    address[] public recipients = [
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x0fC5025C764cE34df352757e82f7B5c4Df39A836,//0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
        0x617F2E2fD72FD9D5503197092aC168c91465E7f2,
        0x17F6AD8Ef982297579C203069C1DbfFE4348c372
    ];

    #ifdef SPLIT_ETHER
    receive() external payable {
        #ifdef ERROR_FOR_ZERO_VALUE
        require(msg.value > 0, "no ether sent");
        #endif

        uint256 portion = msg.value / recipients.length;

        // The call function can return an error here but we assume that it will not.
        // As the developer, I have to make a decision here about whether to protect you
        // against your mistakes by checking errors at runtime, or skipping those error
        // checks to save you gas costs.
        // Double-check your recipient addresses and be aware of possible problems with
        // contract recipients.
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i].call{value: portion}("");
        }
    }
    #endif

    #ifdef SPLIT_TOKENS
    #ifdef ENABLE_WITHDRAW_SINGLE_TOKEN
    function splitAndWithdrawToken(address tokenAddress) public {
        IERC20 token = IERC20(tokenAddress);

        uint256 balance = token.balanceOf(address(this));

        #ifdef ERROR_FOR_ZERO_VALUE
        require(balance > 0, "no tokens to withdraw");
        #endif

        uint256 portion = balance / recipients.length;

        for (uint256 i = 0; i < recipients.length; i++) {
            token.transfer(recipients[i], portion);
        }
    }
    #endif

    function splitAndWithdrawTokens(address[] tokenAddresses) public {
        for (uint256 tokenIndex = 0; tokenIndex < tokenAddresses.length; tokenIndex++) {
            IERC20 token = IERC20(tokenAddresses[tokenIndex]);

            uint256 balance = token.balanceOf(address(this));

            #ifdef ERROR_FOR_ZERO_VALUE
            if (balance == 0) {
                continue;
            }
            #endif

            uint256 portion = balance / recipients.length;

            for (uint256 i = 0; i < recipients.length; i++) {
                token.transfer(recipients[i], portion);
            }
        }
    }
    #endif

    #ifdef ENABLE_SPLIT_UNSENT_ETHER
    // We want to try to send all ether evenly, even if one of the addresses is a contract
    // that throws an error when ether is sent to it this way.
    // If there is an error sending to one or more addresses, then reverting would prevent ether
    // from being sent to anyone and the contract would no longer be usable.
    // This function is here to split unsent ether among addresses that can still receive it without error.
    // If all addresses are wallets, then the ether splitter will always work without error and the
    // splitAndWithdrawUnsentEther function is unnecessary - ASSUMING THAT THE ADDRESSES ARE VALID WALLETS.
    // If none of the addresses are contracts that could have the receive or fallback functions
    // upgraded in any way, then this contract will work always or not at all. (although possibly
    // the contract could throw an error depending on the amount received or some other
    // changing value)
    // If you don't think that the recipients will be adversarial then this probably doesn't matter.
    // The outcome that we REALLY don't want is to encounter an error without reverting and hold
    // on to the ether in this contract with no way to get it out. So this function provides
    // a way to get it out.
    // Note that these problems only apply when sending ether. ERC20 tokens are handled separately and
    // as long as the token contract can be trusted then recipients can't act as adversaries.
    // In any case you should CAREFULLY CHECK THE RECIPIENTS!
    function splitAndWithdrawUnsentEther() public {
        uint256 remainingBalance = address(this).balance;
        #ifdef ERROR_FOR_ZERO_VALUE
        require(remainingBalance > 0, "no unsent ether to withdraw");
        #endif
        uint256 portion = remainingBalance / recipients.length;

        address[] validRecipients = new address[](recipients.length);
        uint32 numValidRecipients = 0;

        // First pass: try to send an even split to all recipients
        uint256 i;
        for (i = 0; i < recipients.length; i++) {
            (bool sentToCurrentRecipient,) = recipients[i].call{value: portion}("");
            if (sentToCurrentRecipient) {
                validRecipients[numValidRecipients] = recipients[i];
                numValidRecipients++;
                remainingBalance -= portion;
            }
        }

        // A really bad contract could throw an error in its receive() function in an unpredictable way,
        // such as depending on the exact amount received. To deal with this, we treat any receive error
        // as the recipient contract refusing the payment.

        // Second pass: if necessary then evenly split the remaining amount among valid recipients
        if (numValidRecipients > 0 && numValidRecipients < recipients.length) {
            portion = remainingBalance / numValidRecipients;
            for (i = 0; i < numValidRecipients; i++) {
                validRecipients[i].call{value: portion}("");
            }
        }
    }
    #endif

}