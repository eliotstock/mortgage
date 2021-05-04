// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./LoanPool.sol";

contract Mortgage {

    enum State {
        Applied,
        Approved,
        DepositReceived,
        InGoodStanding,
        InArrears,
        InForeclosure,
        BadDebt
    }

    address public loanPool;
    address public borrower;
    uint public depositAmount;
    uint public loanAmount;
    State public state;

    event MortgageReceivedFunds(address, uint);

    constructor(address _loanPool, address _borrower, uint _depositAmount,
            uint _loanAmount) {
        loanPool = _loanPool;
        borrower = _borrower;
        depositAmount = _depositAmount;
        loanAmount = _loanAmount;
        state = State.Applied;
    }

    function approve() public {
        state = State.Approved;
    }

    // Both borrowers and the loan pool can send ETH here by calling send()
    // or transfer(). Lenders should not call this contract.
    receive() external payable {
        emit MortgageReceivedFunds(msg.sender, msg.value);

        // We only accept payments from the loan pool and the borrower.
        require(msg.sender == loanPool || msg.sender == borrower);

        if (state == State.Approved && msg.sender == borrower) {
            // This must be the deposit.

            // Check the amount is greater than or equal to the required
            // deposit.
            
            // TODO(P3): We don't support paying the deposit in multiple
            // transactions yet, but we should so that a borrower can test
            // they have the right address with a small amount first.
            require(msg.value >= depositAmount, 'Insufficent deposit');
            state = State.DepositReceived;

            LoanPool l = LoanPool(payable(address(loanPool)));

            // TODO(P1): This will call back to receive(), which requires us to
            // be re-entrant, which smells bad.
            l.notifyDepositReceived();
        }
        else if (state == State.DepositReceived && msg.sender == loanPool) {
            // This must be the balance for the property vendor.

            // TODO(P1): Send the deposit plus the loan amount on to the
            // vendor, reducing our balance to zero.
        }
        else if (state == State.InGoodStanding && msg.sender == borrower) {
            // This must be a regular repayment.

            // TODO(P1): Pass this on to the loan pool in full.
        }
        else {
            revert('Funds from this sender not accepted while in this state');
        }
    }

}
