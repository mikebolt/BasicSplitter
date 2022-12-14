// SPDX-License-Identifier: MIT

// Author: https://github.com/mikebolt
// This software is provided with NO WARRANTY.

pragma solidity >=0.7.0 <0.9.0;

import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/1f18fea1de4c69355c773090c40fe083c08947b4/contracts/token/ERC20/IERC20.sol";

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

// ENABLE_SPLIT_ETHER_AND_RETRY:
// Keep this definition to include the splitEtherAndRetry function.
// This function will cost more gas than the default receive() because it needs to check
// errors after sending ether to each address then repeat the process.
// This will increase the deployment cost.
// If you ever need to call this function then you should probably deploy a new splitter contract!
#define ENABLE_SPLIT_ETHER_AND_RETRY

// ENABLE_WITHDRAW_SINGLE_TOKEN:
// If the users of this contract want to withdraw only one token instead of a list of tokens,
// then it is *slightly* more gas efficient to use a function which only accepts a single
// token address instead of a list of them. This increases deployment cost.
#define ENABLE_WITHDRAW_SINGLE_TOKEN

// RECIPIENT_INDEX_TYPE
// Change this if there are more than 256 recipients.
#define RECIPIENT_INDEX_TYPE uint8

// TOKEN_INDEX_TYPE
// I think 256 tokens is enough. Remember that each one adds gas fees and the client should check balances first.
#define TOKEN_INDEX_TYPE uint8

contract BasicSplitter {

    address[] public recipients = [
    	  // Add recipient addresses here.
    ];

    #ifdef SPLIT_ETHER
    receive() external payable {} // This function must be present to that this contract can receive ether.

    function splitEther() public payable {
        #ifdef ERROR_FOR_ZERO_VALUE
        require(address(this).balance > 0, "no ether to send");
        #endif

        uint256 portion = address(this).balance / recipients.length;

        // The call function can return an error here but we assume that it will not.
        // As the developer, I have to make a decision here about whether to protect you
        // against your mistakes by checking errors at runtime, or skipping those error
        // checks to save you gas costs.
        // Double-check your recipient addresses and be aware of possible problems with
        // contract recipients.
        for (RECIPIENT_INDEX_TYPE i = 0; i < recipients.length; i++) {
            recipients[i].call{value: portion}("");
        }
    }
    #ifdef ENABLE_SPLIT_ETHER_AND_RETRY

    // We want to try to send all ether evenly, even if one of the addresses is a contract
    // that throws an error when ether is sent to it this way.
    // If there is an error sending to one or more addresses, then reverting would prevent ether
    // from being sent to anyone and the contract would no longer be usable.
    // This function is here to split unsent ether among addresses that can still receive it without error.
    // If all addresses are wallets, then the ether splitter will always work without error and the
    // splitEtherAndRetry function is unnecessary - ASSUMING THAT THE ADDRESSES ARE VALID WALLETS.
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
    function splitEtherAndRetry() public payable {
        uint256 remainingBalance = address(this).balance;
        #ifdef ERROR_FOR_ZERO_VALUE
        require(remainingBalance > 0, "no ether to withdraw");
        #endif
        uint256 portion = remainingBalance / recipients.length;

        address[] memory validRecipients = new address[](recipients.length);
        RECIPIENT_INDEX_TYPE numValidRecipients = 0;

        // First pass: try to send an even split to all recipients
        RECIPIENT_INDEX_TYPE i;
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

        for (RECIPIENT_INDEX_TYPE i = 0; i < recipients.length; i++) {
            token.transfer(recipients[i], portion);
        }
    }
    #endif

    function splitAndWithdrawTokens(address[] calldata tokenAddresses) public {
        for (TOKEN_INDEX_TYPE tokenIndex = 0; tokenIndex < tokenAddresses.length; tokenIndex++) {
            IERC20 token = IERC20(tokenAddresses[tokenIndex]);

            uint256 balance = token.balanceOf(address(this));

            #ifdef ERROR_FOR_ZERO_VALUE
            if (balance == 0) {
                continue;
            }
            #endif

            uint256 portion = balance / recipients.length;

            for (RECIPIENT_INDEX_TYPE i = 0; i < recipients.length; i++) {
                token.transfer(recipients[i], portion);
            }
        }
    }
    #endif

}
