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

    State private state;
    address private loanPool;
    address private borrower;
    address private propertyVendor;
    uint private depositAmount;
    uint private loanAmount;

    event MortgageReceivedDeposit(address, uint);
    event MortgageReceivedFunding(address, uint);
    event MortgageReceivedRepayment(address, uint);

    constructor(address _loanPool, address _borrower, address _propertyVendor,
            uint _depositAmount, uint _loanAmount) {
        loanPool = _loanPool;
        borrower = _borrower;
        propertyVendor = _propertyVendor;
        depositAmount = _depositAmount;
        loanAmount = _loanAmount;
        state = State.Applied;
    }

    function getState() public view returns (State s) {
        return state;
    }

    function getLoanAmount() public view returns (uint a) {
        return loanAmount;
    }

    function approve() public {
        require(msg.sender == loanPool, 'Loan pool only');

        require(state == State.Applied, 'Wrong state');

        // Effects.
        state = State.Approved;
    }

    function sendDeposit() external payable {
        require(msg.sender == borrower, 'Borrower only');

        require(state == State.Approved, 'Mortgage not in Approved state');

        // Check the amount is greater than or equal to the required
        // deposit.
        
        // TODO(P3): We don't support paying the deposit in multiple
        // transactions yet, but we should so that a borrower can test
        // they have the right address with a small amount first.
        require(msg.value >= depositAmount, 'Insufficent deposit');

        LoanPool l = LoanPool(payable(address(loanPool)));

        // Effects.
        emit MortgageReceivedDeposit(msg.sender, msg.value);
        state = State.DepositReceived;

        // Interactions. This will call back to sendFunding().
        l.notifyDepositReceived();
    }

    function sendFunding() external payable {
        require(msg.sender == loanPool, 'Loan pool only');

        require(state == State.DepositReceived,
            'Mortgage not in DepositReceived state');

        require(msg.value == loanAmount, 'Funding not equal to loan amount');
        
        // Effects.
        uint amount = msg.value + depositAmount;
        emit MortgageReceivedFunding(msg.sender, msg.value);

        // Interactions.

        // Learning note: I'm surprised this works. We're able to send funds on
        // before the execution of the receiving function completes.

        // TODO(P2): Security note: consider using transfer() rather than send
        // as a guard against a reentrancy bug. transfer() will only use
        // limited gas. send() will take all it can.
        bool ok = payable(propertyVendor).send(amount);

        if (!ok) {
            revert('Unable to forward funds to vendor');
        }
    }

    function sendRepayment() external payable {
        require(msg.sender == borrower, 'Borrower only');

        require(state == State.InGoodStanding || state == State.InArrears
            || state == State.InForeclosure, 'Wrong state');

        // Effects.
        emit MortgageReceivedRepayment(msg.sender, msg.value);

        // Interactions.

        // TODO(P1): Send the repayment on to the loan pool in full.
    }

}
