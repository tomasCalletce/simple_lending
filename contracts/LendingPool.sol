//SPDX-License-Identifier:MIT
pragma solidity 0.8.17;

import "./solmate/FixedPointMathLib.sol";
import "./interfaces/IinterestRateModel.sol";

contract LendingPool {

    using FixedPointMathLib for uint;

    error NoDeposit();

    error NoWithdraw();

    error MoreThanBalance();

    error CallFailed();

    error NoBorrowingCapacity();

    error HealthyPosition();

    error ShortOfValue();

    struct AccountVars {
        uint256 borrowBalance;
        uint256 maximumBorrowable;
    }

    uint256 internal constant WAD = 1e18;

    mapping(address => uint) public userShareBalance;
    mapping(address => AccountVars) public userPosition;

    uint totalShares;
    uint totalTokensBorrowed;
    uint totalTokensDeposited;
    uint lastAccrualBlock;

    uint liquidationThreshold;

    address interestRateModel;

    function deposit() external payable {
        if(msg.value == 0) revert NoDeposit();

        uint sharesToMint = (msg.value*internalBalanceExchangeRate())/WAD;

        totalShares += sharesToMint;
        totalTokensDeposited += msg.value;

        unchecked {
            userShareBalance[msg.sender] += sharesToMint;
        }
    }

    function withdraw(uint amount) external {
        if(amount == 0) revert NoWithdraw();

        accruedInterest();

        //TODO:must check if user can withdraw

        uint sharesToBurn = (amount*internalBalanceExchangeRate())/WAD;

        userShareBalance[msg.sender] -= sharesToBurn;
        totalShares -= sharesToBurn;

        (bool sent,) = address(msg.sender).call{value: amount}("");
        if(!sent) revert CallFailed();
    }

    function internalBalanceExchangeRate() internal view returns(uint) {
        uint shareBalance = totalShares;

        if(shareBalance == 0) return WAD;

        return (shareBalance*WAD)/getTotalAssetsUnderlying();
    }  

    function getTotalAssetsUnderlying() internal view returns (uint){
        return totalTokensDeposited + totalBorrows();
    }

    function accruedInterest() internal {
        totalTokensBorrowed = totalBorrows();
        lastAccrualBlock = block.number;
    }

    function totalBorrows() internal view returns (uint) {

        uint _lastAccrualBlock = lastAccrualBlock;

        if(_lastAccrualBlock == block.number) return totalTokensBorrowed;

        uint blockDelta = block.number - _lastAccrualBlock;

        InterestRateModel model = InterestRateModel(getInterestRateModel());

        uint underlying = totalTokensDeposited + totalTokensBorrowed;

        uint rate = model.getBorrowRate(underlying,totalTokensBorrowed,0);

        uint accruedInterestRate = rate.rpow(blockDelta,WAD);

        return (totalTokensBorrowed*accruedInterestRate)/WAD;
    }

    function getInterestRateModel() internal view returns(address){
        return interestRateModel;
    }

    function borrow(uint amount) external {

        accruedInterest();

        uint sharesToBorrow = (amount*internalBalanceExchangeRate())/WAD;
        uint userCollat = (userShareBalance[msg.sender]*internalBalanceExchangeRate())/WAD;

        AccountVars memory up = userPosition[msg.sender];

        up.maximumBorrowable = (userCollat*liquidationThreshold)/WAD;

        if(up.borrowBalance + sharesToBorrow >= up.maximumBorrowable) revert NoBorrowingCapacity();

        up.borrowBalance  += sharesToBorrow;

        userPosition[msg.sender] = up;

        totalTokensBorrowed += amount;
    }

    function repay(uint amount) external {

        //TODO should this be here?
        accruedInterest();

        uint sharesToPay = (amount*internalBalanceExchangeRate())/WAD;

        AccountVars storage up = userPosition[msg.sender];

        up.borrowBalance -= sharesToPay;
    }

    function liquidate(address target) external payable {

        accruedInterest();

        AccountVars memory up = userPosition[target];

        if(up.borrowBalance < up.maximumBorrowable) revert HealthyPosition();

        if(msg.value < up.borrowBalance) revert ShortOfValue();

        up.borrowBalance = 0;

        uint userCollat = (userShareBalance[target]*internalBalanceExchangeRate())/WAD;

        (bool sent,) = address(msg.sender).call{value: userCollat}("");
        if(!sent) revert CallFailed();

        totalTokensDeposited -= userCollat;
    }

}
