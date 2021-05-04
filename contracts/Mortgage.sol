// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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
        }
        else if (state == State.DepositReceived && msg.sender == loanPool) {
            // This must be the balance for the property vendor.
        }
        else if (state == State.InGoodStanding && msg.sender == borrower) {
            // This must be a regular repayment.
        }
    }

}
