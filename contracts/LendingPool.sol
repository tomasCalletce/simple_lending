//SPDX-License-Identifier:MIT
pragma solidity 0.8.17;


contract LendingPool {


    error NoDeposit();

    error NoWithdraw();

    error MoreThanBalance();

    uint256 internal constant WAD = 1e18;

    mapping(address => uint) public userShareBalance;
    mapping(address => AccountLiquidity) public userPosition;

    uint totalShares;

    struct AccountLiquidity {
        uint256 borrowBalance;
        uint256 maximumBorrowable;
    }

    function deposit() external payable {
        if(msg.value == 0) revert NoDeposit();

        uint sharesToMint = (msg.value*internalBalanceExchangeRate())/WAD;

        totalShares += sharesToMint;

        unchecked {
            userShareBalance[msg.sender] += sharesToMint;
        }
    }

    function borrow(uint amount) external {

        // check that user can borrow
        

    }



    function withdraw(uint amount) external {
        if(amount == 0) revert NoWithdraw();

        //check if he can withdarw based on loans 

        uint sharesToBurn = (amount*internalBalanceExchangeRate())/WAD;

        if(sharesToBurn > amount) revert MoreThanBalance();

        totalShares -= sharesToBurn;

        unchecked {
            userShareBalance[msg.sender] -= sharesToBurn;
        }
    }

    function internalBalanceExchangeRate() internal view returns(uint) {
        uint shareBalance = totalShares;

        if(shareBalance == 0) return WAD;

        return (shareBalance*WAD)/address(this).balance;
    }  

}
